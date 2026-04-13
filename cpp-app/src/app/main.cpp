#include <QGuiApplication>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QMutex>
#include <QMutexLocker>
#include <QStandardPaths>
#include <QTextStream>
#include <QQmlApplicationEngine>
#include <QQmlContext>

#include <QtWebEngineQuick/qtwebenginequickglobal.h>

#include "app/AppController.h"
#include "core/DataPaths.h"
#include "data/DatabaseManager.h"
#include "data/UserRepository.h"

namespace {

QFile g_runtimeLog;
QMutex g_runtimeLogMutex;
QString g_runtimeLogPath;

void appendStartupTrace(const QString &line)
{
    const QString tracePath = QDir(QCoreApplication::applicationDirPath()).filePath("startup_trace.log");
    QFile traceFile(tracePath);
    if (!traceFile.open(QIODevice::WriteOnly | QIODevice::Append | QIODevice::Text)) {
        return;
    }

    QTextStream stream(&traceFile);
    stream << QDateTime::currentDateTimeUtc().toString(Qt::ISODate)
           << " | " << line << "\n";
    stream.flush();
}

void appendRuntimeLogLine(const QString &line)
{
    QMutexLocker locker(&g_runtimeLogMutex);
    if (!g_runtimeLog.isOpen()) {
        return;
    }

    QTextStream stream(&g_runtimeLog);
    stream << QDateTime::currentDateTimeUtc().toString(Qt::ISODate)
           << " | " << line << "\n";
    stream.flush();
}

void runtimeMessageHandler(QtMsgType type, const QMessageLogContext &, const QString &msg)
{
    QString level = "DEBUG";
    if (type == QtInfoMsg) level = "INFO";
    else if (type == QtWarningMsg) level = "WARN";
    else if (type == QtCriticalMsg) level = "ERROR";
    else if (type == QtFatalMsg) level = "FATAL";

    appendRuntimeLogLine(level + " | " + msg);
}

bool initializeRuntimeLogging()
{
    const QStringList logDirCandidates = {
        QDir(core::DataPaths::appDataRoot()).filePath("logs"),
        QDir(QCoreApplication::applicationDirPath()).filePath("logs"),
        QDir(QStandardPaths::writableLocation(QStandardPaths::TempLocation)).filePath("chandra-journey-cpp/logs")
    };

    for (const QString &logDir : logDirCandidates) {
        if (!QDir().mkpath(logDir)) {
            continue;
        }

        const QString candidatePath = QDir(logDir).filePath("runtime.log");
        g_runtimeLog.setFileName(candidatePath);
        if (g_runtimeLog.open(QIODevice::WriteOnly | QIODevice::Append | QIODevice::Text)) {
            g_runtimeLogPath = candidatePath;
            break;
        }
    }

    if (!g_runtimeLog.isOpen()) {
        return false;
    }

    qInstallMessageHandler(runtimeMessageHandler);
    appendRuntimeLogLine("INFO | ===== APP START =====");
    appendRuntimeLogLine("INFO | log_path=" + g_runtimeLogPath);
    return true;
}

} // namespace

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    appendStartupTrace("main | app created");

    QCoreApplication::setOrganizationName("Chandra");
    QCoreApplication::setOrganizationDomain("local.chandra");
    QCoreApplication::setApplicationName("ChandraJourneyCpp");
    QCoreApplication::setApplicationVersion("1.0.0");
    appendStartupTrace("main | application metadata configured");

    core::DataPaths::ensureInitialized();
    appendStartupTrace("main | data paths initialized");
    initializeRuntimeLogging();
    appendStartupTrace("main | runtime logging initialized");
    appendRuntimeLogLine("INFO | startup | pid=" + QString::number(QCoreApplication::applicationPid()));

    QObject::connect(&app, &QCoreApplication::aboutToQuit, []() {
        appendStartupTrace("main | aboutToQuit");
        appendRuntimeLogLine("INFO | ===== APP STOP =====");
    });

    QtWebEngineQuick::initialize();
    appendStartupTrace("main | webengine initialized");

    if (!data::DatabaseManager::initialize()) {
        appendStartupTrace("main | database init failed");
        appendRuntimeLogLine("ERROR | startup | database initialization failed");
        return 1;
    }
    appendStartupTrace("main | database initialized");

    if (!data::UserRepository::ensureDefaultSysop()) {
        appendStartupTrace("main | default sysop init failed");
        appendRuntimeLogLine("ERROR | startup | default sysop initialization failed");
        return 1;
    }
    appendStartupTrace("main | default sysop ready");

    AppController appController;

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("appController", &appController);

    const QUrl mainQml(QStringLiteral("qrc:/qml/ui/qml/Main.qml"));
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
                     &app, []() {
                         appendStartupTrace("main | root QML creation failed");
                         appendRuntimeLogLine("ERROR | startup | root QML object creation failed - check logs");
                         QCoreApplication::exit(-1);
                     }, Qt::QueuedConnection);
    appendStartupTrace("main | loading main QML");
    engine.load(mainQml);
    appendStartupTrace("main | QML load invoked");

    const int code = app.exec();
    appendStartupTrace("main | app.exec returned code=" + QString::number(code));
    return code;
}
