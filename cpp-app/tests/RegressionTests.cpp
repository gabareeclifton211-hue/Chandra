#include <QtTest>

#include "app/AppController.h"
#include "core/DataPaths.h"
#include "data/DatabaseManager.h"
#include "data/UserRepository.h"
#include "services/FileMediaService.h"
#include "services/SettingsService.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QQmlApplicationEngine>
#include <QQmlComponent>
#include <QQmlContext>
#include <QSqlQuery>
#include <QStandardPaths>
#include <QTemporaryDir>
#include <QUuid>

#include <QtWebEngineQuick/qtwebenginequickglobal.h>

namespace {

QString verifyQmlViewLoads(AppController *controller,
                           const QUrl &viewUrl,
                           const QVariantMap &initialProperties = {})
{
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("appController", controller);

    QQmlComponent component(&engine, viewUrl);
    if (component.status() == QQmlComponent::Error) {
        return component.errorString();
    }

    QObject *instance = component.createWithInitialProperties(initialProperties, engine.rootContext());
    if (instance == nullptr) {
        return component.errorString();
    }
    delete instance;
    return QString();
}

QString userIdByUsername(const QVariantList &users, const QString &username)
{
    for (const QVariant &value : users) {
        const QVariantMap user = value.toMap();
        if (user.value("username").toString() == username) {
            return user.value("id").toString();
        }
    }
    return {};
}

QString createTempFile(const QString &directory, const QString &name, const QByteArray &content)
{
    const QString path = QDir(directory).filePath(name);
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        return {};
    }
    file.write(content);
    file.close();
    return path;
}

} // namespace

class RegressionTests : public QObject {
    Q_OBJECT

private slots:
    void initTestCase();
    void schemaIncludesOptionalUserColumns();
    void schemaIncludesActivityLogColumns();
    void userProfileFieldsRoundTrip();
    void settingsRoundTrip();
    void fileUploadAndMoveRoundTrip();
    void adminMoveFileBetweenUsersRoundTrip();
    void adminDeleteRejectsOutsideManagedStorage();
    void cameraOutputDirResolutionProducesWritableDirectory();
    void userPasswordChangeSucceeds();
    void userPasswordChangeFailsWithIncorrectOldPassword();
    void userPasswordVerificationAfterChange();
    void controllerLoginLogoutSessionSmoke();
    void controllerMyProfilePersistenceSmoke();
    void controllerChangePasswordSmoke();
    void controllerFileCrudSmoke();
    void controllerJournalAndSettingsSmoke();
    void controllerAdminUserManagementSmoke();
    void controllerAdminFileOperationsSmoke();
    void activityLogWriteSmoke();
    void activityLogSysopReadAndClearSmoke();
    void startupQmlSmokeTest();
    void loginViewQmlSmokeTest();
    void shellViewQmlSmokeTest();
    void wardrobeViewQmlSmokeTest();
    void journalViewQmlSmokeTest();
    void cameraViewQmlSmokeTest();
    void myProfileViewQmlSmokeTest();
    void importViewQmlSmokeTest();
    void adminViewQmlSmokeTest();
    void settingsViewQmlSmokeTest();
};

void RegressionTests::initTestCase()
{
    QStandardPaths::setTestModeEnabled(true);

    const QString appDataRoot = core::DataPaths::appDataRoot();
    QDir(appDataRoot).removeRecursively();

    QVERIFY2(data::DatabaseManager::initialize(), "Database initialization should succeed");
}

void RegressionTests::schemaIncludesOptionalUserColumns()
{
    QSqlQuery query(data::DatabaseManager::database());
    QVERIFY(query.exec("PRAGMA table_info(users)"));

    QSet<QString> columns;
    while (query.next()) {
        columns.insert(query.value(1).toString());
    }

    QVERIFY(columns.contains("email"));
    QVERIFY(columns.contains("phone"));
    QVERIFY(columns.contains("profile_picture"));
    QVERIFY(columns.contains("pronouns"));
}

void RegressionTests::schemaIncludesActivityLogColumns()
{
    QSqlQuery query(data::DatabaseManager::database());
    QVERIFY(query.exec("PRAGMA table_info(activity_log)"));

    QSet<QString> columns;
    while (query.next()) {
        columns.insert(query.value(1).toString());
    }

    QVERIFY(columns.contains("id"));
    QVERIFY(columns.contains("ts"));
    QVERIFY(columns.contains("username"));
    QVERIFY(columns.contains("action"));
    QVERIFY(columns.contains("details"));
    QVERIFY(columns.contains("is_web_search"));
}

void RegressionTests::userProfileFieldsRoundTrip()
{
    const QString username = "user_" + QUuid::createUuid().toString(QUuid::WithoutBraces).left(8);
    const QString password = "secret123";
    QString error;

    QVERIFY2(data::UserRepository::createUser(
                 username,
                 password,
                 "user",
                 "person@example.com",
                 "555-0100",
                 "C:/profiles/pic.jpg",
                 "she/her",
                 &error),
             qPrintable(error));

    const auto authenticated = data::UserRepository::authenticate(username, password);
    QVERIFY(authenticated.has_value());
    QCOMPARE(authenticated->email, QString("person@example.com"));
    QCOMPARE(authenticated->phone, QString("555-0100"));
    QCOMPARE(authenticated->profilePicture, QString("C:/profiles/pic.jpg"));
    QCOMPARE(authenticated->pronouns, QString("she/her"));

    QVERIFY2(data::UserRepository::updateUserProfile(
                 authenticated->id,
                 "updated@example.com",
                 "555-0101",
                 "C:/profiles/pic2.jpg",
                 "they/them",
                 &error),
             qPrintable(error));

    const auto updated = data::UserRepository::findUserById(authenticated->id);
    QVERIFY(updated.has_value());
    QCOMPARE(updated->email, QString("updated@example.com"));
    QCOMPARE(updated->phone, QString("555-0101"));
    QCOMPARE(updated->profilePicture, QString("C:/profiles/pic2.jpg"));
    QCOMPARE(updated->pronouns, QString("they/them"));

    const QVariantList users = data::UserRepository::listUsers();
    bool found = false;
    for (const QVariant &value : users) {
        const QVariantMap user = value.toMap();
        if (user.value("id").toString() == authenticated->id) {
            found = true;
            QCOMPARE(user.value("email").toString(), QString("updated@example.com"));
            QCOMPARE(user.value("phone").toString(), QString("555-0101"));
            QCOMPARE(user.value("profilePicture").toString(), QString("C:/profiles/pic2.jpg"));
            QCOMPARE(user.value("pronouns").toString(), QString("they/them"));
            break;
        }
    }
    QVERIFY(found);
}

void RegressionTests::settingsRoundTrip()
{
    services::SettingsService settingsService;
    QString error;
    const QString userId = QUuid::createUuid().toString(QUuid::WithoutBraces);

    QVERIFY2(settingsService.setSetting(userId, "cameraSplitRatio", "0.71", &error), qPrintable(error));
    QVERIFY2(settingsService.setSetting(userId, "cameraSelectedCategory", "makeup", &error), qPrintable(error));

    const QVariantMap settings = settingsService.getSettings(userId);
    QCOMPARE(settings.value("cameraSplitRatio").toString(), QString("0.71"));
    QCOMPARE(settings.value("cameraSelectedCategory").toString(), QString("makeup"));
}

void RegressionTests::fileUploadAndMoveRoundTrip()
{
    services::FileMediaService fileMediaService;
    QString error;
    const QString userId = QUuid::createUuid().toString(QUuid::WithoutBraces);
    const QString username = "media_" + QUuid::createUuid().toString(QUuid::WithoutBraces).left(8);

    QTemporaryDir tempDir;
    QVERIFY(tempDir.isValid());

    const QString sourcePath = QDir(tempDir.path()).filePath("sample.txt");
    QFile sourceFile(sourcePath);
    QVERIFY(sourceFile.open(QIODevice::WriteOnly | QIODevice::Truncate));
    sourceFile.write("sample-data");
    sourceFile.close();

    QVERIFY2(fileMediaService.uploadFiles(userId, username, "camera", { sourcePath }, &error), qPrintable(error));

    const QVariantList cameraFiles = fileMediaService.listFiles(userId, "camera");
    QCOMPARE(cameraFiles.size(), 1);
    const QVariantMap uploaded = cameraFiles.first().toMap();
    QCOMPARE(uploaded.value("filename").toString(), QString("sample.txt"));
    QVERIFY(QFileInfo::exists(uploaded.value("filePath").toString()));

    QVERIFY2(fileMediaService.moveFile(userId, username, "camera", "makeup", "sample.txt", &error), qPrintable(error));

    const QVariantList cameraAfterMove = fileMediaService.listFiles(userId, "camera");
    QCOMPARE(cameraAfterMove.size(), 0);

    const QVariantList makeupFiles = fileMediaService.listFiles(userId, "makeup");
    QCOMPARE(makeupFiles.size(), 1);
    const QVariantMap moved = makeupFiles.first().toMap();
    QCOMPARE(moved.value("filename").toString(), QString("sample.txt"));
    QVERIFY(moved.value("filePath").toString().contains("makeup"));
    QVERIFY(QFileInfo::exists(moved.value("filePath").toString()));
}

void RegressionTests::adminMoveFileBetweenUsersRoundTrip()
{
    services::FileMediaService fileMediaService;
    QString error;
    const QString sourceUserId = QUuid::createUuid().toString(QUuid::WithoutBraces);
    const QString sourceUsername = "src_" + QUuid::createUuid().toString(QUuid::WithoutBraces).left(8);
    const QString destinationUserId = QUuid::createUuid().toString(QUuid::WithoutBraces);
    const QString destinationUsername = "dst_" + QUuid::createUuid().toString(QUuid::WithoutBraces).left(8);

    QTemporaryDir tempDir;
    QVERIFY(tempDir.isValid());

    const QString sourcePath = QDir(tempDir.path()).filePath("admin-move.txt");
    QFile sourceFile(sourcePath);
    QVERIFY(sourceFile.open(QIODevice::WriteOnly | QIODevice::Truncate));
    sourceFile.write("admin-move-data");
    sourceFile.close();

    QVERIFY2(fileMediaService.uploadFiles(sourceUserId, sourceUsername, "camera", { sourcePath }, &error), qPrintable(error));

    QVERIFY2(fileMediaService.moveFileAdmin(
                 sourceUserId,
                 sourceUsername,
                 "camera",
                 "admin-move.txt",
                 destinationUserId,
                 destinationUsername,
                 "makeup",
                 &error),
             qPrintable(error));

    QCOMPARE(fileMediaService.listFiles(sourceUserId, "camera").size(), 0);

    const QVariantList destinationFiles = fileMediaService.listFiles(destinationUserId, "makeup");
    QCOMPARE(destinationFiles.size(), 1);
    const QVariantMap moved = destinationFiles.first().toMap();
    QCOMPARE(moved.value("filename").toString(), QString("admin-move.txt"));
    QVERIFY(moved.value("filePath").toString().contains(destinationUsername));
    QVERIFY(moved.value("filePath").toString().contains("makeup"));
    QVERIFY(QFileInfo::exists(moved.value("filePath").toString()));

    const QVariantList allFiles = fileMediaService.listAllFiles();
    bool foundMovedRecord = false;
    for (const QVariant &value : allFiles) {
        const QVariantMap item = value.toMap();
        if (item.value("userId").toString() == destinationUserId &&
            item.value("category").toString() == "makeup" &&
            item.value("filename").toString() == "admin-move.txt") {
            foundMovedRecord = true;
            break;
        }
    }
    QVERIFY(foundMovedRecord);
}

void RegressionTests::adminDeleteRejectsOutsideManagedStorage()
{
    services::FileMediaService fileMediaService;
    QString error;
    const QString userId = QUuid::createUuid().toString(QUuid::WithoutBraces);
    const QString username = "del_" + QUuid::createUuid().toString(QUuid::WithoutBraces).left(8);

    QTemporaryDir tempDir;
    QVERIFY(tempDir.isValid());

    const QString managedSourcePath = QDir(tempDir.path()).filePath("admin-delete.txt");
    QFile managedSource(managedSourcePath);
    QVERIFY(managedSource.open(QIODevice::WriteOnly | QIODevice::Truncate));
    managedSource.write("admin-delete-data");
    managedSource.close();

    QVERIFY2(fileMediaService.uploadFiles(userId, username, "camera", { managedSourcePath }, &error), qPrintable(error));

    const QVariantMap uploaded = fileMediaService.listFiles(userId, "camera").first().toMap();
    const QString managedPath = uploaded.value("filePath").toString();
    QVERIFY(QFileInfo::exists(managedPath));

    const QString outsidePath = QDir(tempDir.path()).filePath("outside.txt");
    QFile outsideFile(outsidePath);
    QVERIFY(outsideFile.open(QIODevice::WriteOnly | QIODevice::Truncate));
    outsideFile.write("outside-data");
    outsideFile.close();

    QVERIFY(!fileMediaService.deleteFileAdmin(userId, "camera", "admin-delete.txt", outsidePath, &error));
    QCOMPARE(error, QString("Refusing to delete file outside managed storage."));
    QVERIFY(QFileInfo::exists(outsidePath));

    const QVariantList filesAfterRejectedDelete = fileMediaService.listFiles(userId, "camera");
    QCOMPARE(filesAfterRejectedDelete.size(), 1);
    QVERIFY(QFileInfo::exists(managedPath));

    QVERIFY2(fileMediaService.deleteFileAdmin(userId, "camera", "admin-delete.txt", managedPath, &error), qPrintable(error));
    QCOMPARE(fileMediaService.listFiles(userId, "camera").size(), 0);
    QVERIFY(!QFileInfo::exists(managedPath));
}

void RegressionTests::cameraOutputDirResolutionProducesWritableDirectory()
{
    AppController controller;

    QTemporaryDir tempDir;
    QVERIFY(tempDir.isValid());

    const QString preferredDir = QDir(tempDir.path()).filePath("captures/subdir");
    const QString resolvedPreferred = controller.ensureCaptureOutputDir(preferredDir);
    QCOMPARE(QDir::cleanPath(resolvedPreferred), QDir::cleanPath(preferredDir));
    QVERIFY(QFileInfo(resolvedPreferred).exists());
    QVERIFY(QFileInfo(resolvedPreferred).isDir());

    const QString invalidRelative = controller.ensureCaptureOutputDir("relative/path");
    QVERIFY(!invalidRelative.isEmpty());
    QVERIFY(QDir::isAbsolutePath(invalidRelative));
    QVERIFY(QFileInfo(invalidRelative).exists());
    QVERIFY(QFileInfo(invalidRelative).isDir());

    const QString probePath = QDir(invalidRelative).filePath("probe.tmp");
    QFile probe(probePath);
    QVERIFY(probe.open(QIODevice::WriteOnly | QIODevice::Truncate));
    probe.write("ok");
    probe.close();
    QVERIFY(QFile::remove(probePath));
}

void RegressionTests::userPasswordChangeSucceeds()
{
    const QString username = "pwchange_" + QUuid::createUuid().toString(QUuid::WithoutBraces).left(8);
    const QString originalPassword = "initialPassword123";
    const QString newPassword = "newPassword456";
    QString error;

    QVERIFY2(data::UserRepository::createUser(
                 username,
                 originalPassword,
                 "user",
                 "",
                 "",
                 "",
                 "",
                 &error),
             qPrintable(error));

    const auto authenticated = data::UserRepository::authenticate(username, originalPassword);
    QVERIFY(authenticated.has_value());
    const QString userId = authenticated->id;

    QVERIFY2(data::UserRepository::changePassword(
                 userId,
                 originalPassword,
                 newPassword,
                 &error),
             qPrintable(error));

    const auto authWithNewPassword = data::UserRepository::authenticate(username, newPassword);
    QVERIFY(authWithNewPassword.has_value());
    QCOMPARE(authWithNewPassword->id, userId);

    const auto authWithOldPassword = data::UserRepository::authenticate(username, originalPassword);
    QVERIFY(!authWithOldPassword.has_value());
}

void RegressionTests::userPasswordChangeFailsWithIncorrectOldPassword()
{
    const QString username = "pwfail_" + QUuid::createUuid().toString(QUuid::WithoutBraces).left(8);
    const QString correctPassword = "correctPassword123";
    const QString wrongPassword = "wrongPassword123";
    const QString newPassword = "newPassword456";
    QString error;

    QVERIFY2(data::UserRepository::createUser(
                 username,
                 correctPassword,
                 "user",
                 "",
                 "",
                 "",
                 "",
                 &error),
             qPrintable(error));

    const auto authenticated = data::UserRepository::authenticate(username, correctPassword);
    QVERIFY(authenticated.has_value());
    const QString userId = authenticated->id;

    QVERIFY(!data::UserRepository::changePassword(
        userId,
        wrongPassword,
        newPassword,
        &error));
    QCOMPARE(error, QString("Current password is incorrect."));

    const auto authWithOriginal = data::UserRepository::authenticate(username, correctPassword);
    QVERIFY(authWithOriginal.has_value());
    QCOMPARE(authWithOriginal->id, userId);

    const auto authWithNew = data::UserRepository::authenticate(username, newPassword);
    QVERIFY(!authWithNew.has_value());
}

void RegressionTests::userPasswordVerificationAfterChange()
{
    const QString username = "pwverify_" + QUuid::createUuid().toString(QUuid::WithoutBraces).left(8);
    const QString password1 = "password1";
    const QString password2 = "password2";
    const QString password3 = "password3";
    QString error;

    QVERIFY2(data::UserRepository::createUser(
                 username,
                 password1,
                 "user",
                 "",
                 "",
                 "",
                 "",
                 &error),
             qPrintable(error));

    auto authenticated = data::UserRepository::authenticate(username, password1);
    QVERIFY(authenticated.has_value());
    const QString userId = authenticated->id;

    QVERIFY2(data::UserRepository::changePassword(userId, password1, password2, &error), qPrintable(error));

    authenticated = data::UserRepository::authenticate(username, password2);
    QVERIFY(authenticated.has_value());

    QVERIFY2(data::UserRepository::changePassword(userId, password2, password3, &error), qPrintable(error));

    authenticated = data::UserRepository::authenticate(username, password3);
    QVERIFY(authenticated.has_value());

    const auto oldCredentials = data::UserRepository::authenticate(username, password1);
    QVERIFY(!oldCredentials.has_value());

    const auto oldCredentials2 = data::UserRepository::authenticate(username, password2);
    QVERIFY(!oldCredentials2.has_value());
}

void RegressionTests::controllerLoginLogoutSessionSmoke()
{
    const QString username = "ctrl_login_" + QUuid::createUuid().toString(QUuid::WithoutBraces).left(8);
    const QString password = "ctrlPass123";
    QString error;

    QVERIFY2(data::UserRepository::createUser(
                 username,
                 password,
                 "user",
                 "",
                 "",
                 "",
                 "",
                 &error),
             qPrintable(error));

    AppController controller;
    QVERIFY(!controller.authenticated());

    QVERIFY(!controller.login(username, "wrong-password"));
    QVERIFY(!controller.authenticated());
    QCOMPARE(controller.lastError(), QString("Invalid credentials."));

    QVERIFY(controller.login(username, password));
    QVERIFY(controller.authenticated());
    QCOMPARE(controller.username(), username);
    QCOMPARE(controller.role(), QString("user"));

    controller.logout();
    QVERIFY(!controller.authenticated());
    QCOMPARE(controller.username(), QString());
    QCOMPARE(controller.role(), QString());
}

void RegressionTests::controllerMyProfilePersistenceSmoke()
{
    const QString username = "ctrl_profile_" + QUuid::createUuid().toString(QUuid::WithoutBraces).left(8);
    const QString password = "profilePass123";
    QString error;

    QVERIFY2(data::UserRepository::createUser(
                 username,
                 password,
                 "user",
                 "before@example.com",
                 "555-1000",
                 "C:/before.png",
                 "she/her",
                 &error),
             qPrintable(error));

    AppController controller;
    QVERIFY(controller.login(username, password));

    QVERIFY(controller.updateMyProfile(
        "after@example.com",
        "555-2000",
        "C:/after.png",
        "they/them"));

    QCOMPARE(controller.email(), QString("after@example.com"));
    QCOMPARE(controller.phone(), QString("555-2000"));
    QCOMPARE(controller.profilePicture(), QString("C:/after.png"));
    QCOMPARE(controller.pronouns(), QString("they/them"));

    controller.logout();
    QVERIFY(controller.login(username, password));
    QCOMPARE(controller.email(), QString("after@example.com"));
    QCOMPARE(controller.phone(), QString("555-2000"));
    QCOMPARE(controller.profilePicture(), QString("C:/after.png"));
    QCOMPARE(controller.pronouns(), QString("they/them"));
}

void RegressionTests::controllerChangePasswordSmoke()
{
    const QString username = "ctrl_pw_" + QUuid::createUuid().toString(QUuid::WithoutBraces).left(8);
    const QString originalPassword = "origPass123";
    const QString newPassword = "newPass456";
    QString error;

    QVERIFY2(data::UserRepository::createUser(
                 username,
                 originalPassword,
                 "user",
                 "",
                 "",
                 "",
                 "",
                 &error),
             qPrintable(error));

    AppController controller;
    QVERIFY(controller.login(username, originalPassword));

    QVERIFY(!controller.changeMyPassword("bad-current", newPassword));
    QCOMPARE(controller.lastError(), QString("Current password is incorrect."));

    QVERIFY(controller.changeMyPassword(originalPassword, newPassword));
    QCOMPARE(controller.lastError(), QString());

    controller.logout();
    QVERIFY(!controller.login(username, originalPassword));
    QVERIFY(controller.login(username, newPassword));
}

void RegressionTests::controllerFileCrudSmoke()
{
    const QString username = "ctrl_files_" + QUuid::createUuid().toString(QUuid::WithoutBraces).left(8);
    const QString password = "filesPass123";
    QString error;

    QVERIFY2(data::UserRepository::createUser(
                 username,
                 password,
                 "user",
                 "",
                 "",
                 "",
                 "",
                 &error),
             qPrintable(error));

    AppController controller;
    QVERIFY(controller.login(username, password));

    QTemporaryDir tempDir;
    QVERIFY(tempDir.isValid());

    const QString file1 = createTempFile(tempDir.path(), "alpha.txt", "alpha-data");
    const QString file2 = createTempFile(tempDir.path(), "beta.txt", "beta-data");
    QVERIFY(!file1.isEmpty());
    QVERIFY(!file2.isEmpty());

    QVERIFY(controller.uploadFiles("camera", { file1, file2 }));

    const QVariantList cameraFiles = controller.listFiles("camera");
    QCOMPARE(cameraFiles.size(), 2);

    QVERIFY(controller.renameFile("camera", "alpha.txt", "alpha-renamed.txt"));
    QVERIFY(controller.setFileDescription("camera", "beta.txt", "desc-beta"));
    QVERIFY(controller.moveFile("camera", "makeup", "alpha-renamed.txt"));
    QVERIFY(controller.moveFiles("camera", "accessories", { "beta.txt" }));

    QCOMPARE(controller.listFiles("camera").size(), 0);
    QCOMPARE(controller.listFiles("makeup").size(), 1);
    QCOMPARE(controller.listFiles("accessories").size(), 1);

    const QString outsidePath = createTempFile(tempDir.path(), "outside.txt", "outside");
    QVERIFY(!outsidePath.isEmpty());
    QVERIFY(!controller.openFile(outsidePath));
    QCOMPARE(controller.lastError(), QString("Access denied for selected file path."));

    QVERIFY(controller.deleteFile("makeup", "alpha-renamed.txt"));
    QVERIFY(controller.deleteFiles("accessories", { "beta.txt" }));
    QCOMPARE(controller.listFiles("makeup").size(), 0);
    QCOMPARE(controller.listFiles("accessories").size(), 0);
}

void RegressionTests::controllerJournalAndSettingsSmoke()
{
    const QString username = "ctrl_js_" + QUuid::createUuid().toString(QUuid::WithoutBraces).left(8);
    const QString password = "journalSettings123";
    QString error;

    QVERIFY2(data::UserRepository::createUser(
                 username,
                 password,
                 "user",
                 "",
                 "",
                 "",
                 "",
                 &error),
             qPrintable(error));

    AppController controller;
    QVERIFY(controller.login(username, password));

    const QString createdId = controller.saveJournal({}, "Entry One", "Body One");
    QVERIFY(!createdId.isEmpty());

    const QString updatedId = controller.saveJournal(createdId, "Entry One Updated", "Body Two");
    QCOMPARE(updatedId, createdId);

    const QVariantList entries = controller.listJournal();
    bool found = false;
    for (const QVariant &value : entries) {
        if (value.toMap().value("id").toString() == createdId) {
            found = true;
            break;
        }
    }
    QVERIFY(found);

    QVERIFY(controller.deleteJournalEntries({ createdId }));

    QVERIFY(controller.setSetting("cameraSplitRatio", "0.55"));
    QVERIFY(controller.setSetting("customTab1Enabled", "true"));
    const QVariantMap settings = controller.getSettings();
    QCOMPARE(settings.value("cameraSplitRatio").toString(), QString("0.55"));
    QCOMPARE(settings.value("customTab1Enabled").toString(), QString("true"));
}

void RegressionTests::controllerAdminUserManagementSmoke()
{
    const QString sysopUsername = "ctrl_admin_" + QUuid::createUuid().toString(QUuid::WithoutBraces).left(8);
    const QString sysopPassword = "sysopPass123";
    const QString targetUsername = "target_" + QUuid::createUuid().toString(QUuid::WithoutBraces).left(8);
    const QString targetPassword = "targetPass123";
    const QString bulkUsername = "bulk_" + QUuid::createUuid().toString(QUuid::WithoutBraces).left(8);
    QString error;

    QVERIFY2(data::UserRepository::createUser(
                 sysopUsername,
                 sysopPassword,
                 "sysop",
                 "",
                 "",
                 "",
                 "",
                 &error),
             qPrintable(error));

    AppController controller;
    QVERIFY(controller.login(sysopUsername, sysopPassword));

    QVERIFY(controller.createUser(targetUsername, targetPassword, "user", "x@a.com", "555-1111", "C:/x.png", "they/them"));
    QVERIFY(controller.createUser(bulkUsername, "bulkPass123", "user", "", "", "", ""));

    QVariantList users = controller.listUsers();
    const QString targetUserId = userIdByUsername(users, targetUsername);
    const QString bulkUserId = userIdByUsername(users, bulkUsername);
    QVERIFY(!targetUserId.isEmpty());
    QVERIFY(!bulkUserId.isEmpty());

    QVERIFY(controller.updateUserProfile(targetUserId, "y@a.com", "555-2222", "C:/y.png", "she/her"));
    QVERIFY(controller.resetUserPassword(targetUserId, "targetPass456"));
    QVERIFY(controller.deleteUsers({ bulkUserId }));
    QVERIFY(controller.deleteUser(targetUserId));
    QVERIFY(!controller.deleteUser(userIdByUsername(controller.listUsers(), sysopUsername)));
    QCOMPARE(controller.lastError(), QString("Cannot delete current signed-in user."));
}

void RegressionTests::controllerAdminFileOperationsSmoke()
{
    const QString sysopUsername = "ctrl_files_admin_" + QUuid::createUuid().toString(QUuid::WithoutBraces).left(8);
    const QString sysopPassword = "sysopFiles123";
    const QString srcUsername = "src_user_" + QUuid::createUuid().toString(QUuid::WithoutBraces).left(8);
    const QString dstUsername = "dst_user_" + QUuid::createUuid().toString(QUuid::WithoutBraces).left(8);
    const QString srcPassword = "srcPass123";
    const QString dstPassword = "dstPass123";
    QString error;

    QVERIFY2(data::UserRepository::createUser(sysopUsername, sysopPassword, "sysop", "", "", "", "", &error), qPrintable(error));
    QVERIFY2(data::UserRepository::createUser(srcUsername, srcPassword, "user", "", "", "", "", &error), qPrintable(error));
    QVERIFY2(data::UserRepository::createUser(dstUsername, dstPassword, "user", "", "", "", "", &error), qPrintable(error));

    AppController srcController;
    QVERIFY(srcController.login(srcUsername, srcPassword));

    QTemporaryDir tempDir;
    QVERIFY(tempDir.isValid());
    const QString sourceFile = createTempFile(tempDir.path(), "admin-op.txt", "admin-op-data");
    QVERIFY(!sourceFile.isEmpty());
    QVERIFY(srcController.uploadFiles("camera", { sourceFile }));

    AppController adminController;
    QVERIFY(adminController.login(sysopUsername, sysopPassword));

    const QVariantList users = adminController.listUsers();
    const QString srcUserId = userIdByUsername(users, srcUsername);
    const QString dstUserId = userIdByUsername(users, dstUsername);
    QVERIFY(!srcUserId.isEmpty());
    QVERIFY(!dstUserId.isEmpty());

    const QVariantList srcFilesBefore = adminController.listAdminFilesForUser(srcUserId);
    QCOMPARE(srcFilesBefore.size(), 1);

    QVERIFY(adminController.moveAdminFiles(srcFilesBefore, dstUserId, "makeup"));
    QCOMPARE(adminController.listAdminFilesForUser(srcUserId).size(), 0);

    const QVariantList dstFiles = adminController.listAdminFilesForUser(dstUserId);
    QCOMPARE(dstFiles.size(), 1);
    QVERIFY(adminController.deleteAdminFiles(dstFiles));
    QCOMPARE(adminController.listAdminFilesForUser(dstUserId).size(), 0);

    AppController nonAdmin;
    QVERIFY(nonAdmin.login(srcUsername, srcPassword));
    QVERIFY(nonAdmin.listAllFiles().isEmpty());
    QVERIFY(!nonAdmin.moveAdminFiles(dstFiles, srcUserId, "camera"));
    QCOMPARE(nonAdmin.lastError(), QString("Unauthorized."));
}

void RegressionTests::activityLogWriteSmoke()
{
    const QString username = "ctrl_log_" + QUuid::createUuid().toString(QUuid::WithoutBraces).left(8);
    const QString password = "logPass123";
    QString error;

    QVERIFY2(data::UserRepository::createUser(
                 username,
                 password,
                 "user",
                 "",
                 "",
                 "",
                 "",
                 &error),
             qPrintable(error));

    AppController controller;
    QVERIFY(controller.login(username, password));

    const QString marker = "marker_" + QUuid::createUuid().toString(QUuid::WithoutBraces);
    const QString searchUrl = "https://duckduckgo.com/?q=" + marker;

    QCOMPARE(controller.getActivityLog().size(), 0);
    QVERIFY(!controller.clearActivityLog());
    QCOMPARE(controller.lastError(), QString("Unauthorized."));

    controller.logActivity("test_action", marker);
    controller.logWebSearch(searchUrl);

    QSqlQuery q(data::DatabaseManager::database());
    q.prepare("SELECT action, details, is_web_search FROM activity_log WHERE username = :username "
              "AND (details = :marker OR details = :searchUrl)");
    q.bindValue(":username", username);
    q.bindValue(":marker", marker);
    q.bindValue(":searchUrl", searchUrl);
    QVERIFY(q.exec());

    bool foundGeneric = false;
    bool foundWeb = false;
    while (q.next()) {
        const QString action = q.value(0).toString();
        const QString details = q.value(1).toString();
        const bool isWebSearch = q.value(2).toInt() != 0;

        if (action == "test_action" && details == marker && !isWebSearch) {
            foundGeneric = true;
        }
        if (action == "web_browse" && details == searchUrl && isWebSearch) {
            foundWeb = true;
        }
    }

    QVERIFY2(foundGeneric, "Expected regular activity log entry was not found");
    QVERIFY2(foundWeb, "Expected web search log entry was not found");
}

void RegressionTests::activityLogSysopReadAndClearSmoke()
{
    const QString username = "ctrl_syslog_" + QUuid::createUuid().toString(QUuid::WithoutBraces).left(8);
    const QString password = "sysLogPass123";
    QString error;

    QVERIFY2(data::UserRepository::createUser(
                 username,
                 password,
                 "sysop",
                 "",
                 "",
                 "",
                 "",
                 &error),
             qPrintable(error));

    AppController controller;
    QVERIFY(controller.login(username, password));

    const QString marker = "sysop_marker_" + QUuid::createUuid().toString(QUuid::WithoutBraces);
    controller.logActivity("sysop_test_action", marker);

    const QVariantList before = controller.getActivityLog();
    QVERIFY(!before.isEmpty());

    bool foundMarker = false;
    for (const QVariant &value : before) {
        const QVariantMap entry = value.toMap();
        if (entry.value("action").toString() == "sysop_test_action"
            && entry.value("details").toString() == marker
            && !entry.value("isWebSearch").toBool()) {
            foundMarker = true;
            break;
        }
    }
    QVERIFY2(foundMarker, "Sysop should be able to read activity log entries");

    QVERIFY(controller.clearActivityLog());
    const QVariantList after = controller.getActivityLog();
    QVERIFY(after.isEmpty());
}

void RegressionTests::startupQmlSmokeTest()
{
    QtWebEngineQuick::initialize();

    AppController controller;
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("appController", &controller);

    const QUrl mainQml(QStringLiteral("qrc:/qml/ui/qml/Main.qml"));
    QList<QObject *> createdRoots;
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     this,
                     [&createdRoots, mainQml](QObject *object, const QUrl &url) {
                         if (url == mainQml && object) {
                             createdRoots.push_back(object);
                         }
                     });

    engine.load(mainQml);

    QVERIFY2(!engine.rootObjects().isEmpty(), "Main QML should load successfully from resources");
    QVERIFY2(!createdRoots.isEmpty(), "Root QML object should be created successfully");
}

void RegressionTests::loginViewQmlSmokeTest()
{
    AppController controller;
    const QString error = verifyQmlViewLoads(&controller, QUrl(QStringLiteral("qrc:/qml/ui/qml/views/LoginView.qml")));
    QVERIFY2(error.isEmpty(), qPrintable(error));
}

void RegressionTests::shellViewQmlSmokeTest()
{
    QtWebEngineQuick::initialize();

    AppController controller;
    const QString error = verifyQmlViewLoads(&controller, QUrl(QStringLiteral("qrc:/qml/ui/qml/views/ShellView.qml")));
    QVERIFY2(error.isEmpty(), qPrintable(error));
}

void RegressionTests::wardrobeViewQmlSmokeTest()
{
    AppController controller;
    const QString error = verifyQmlViewLoads(
        &controller,
        QUrl(QStringLiteral("qrc:/qml/ui/qml/views/WardrobeView.qml")),
        QVariantMap {
            { "category", "camera" }
        });
    QVERIFY2(error.isEmpty(), qPrintable(error));
}

void RegressionTests::journalViewQmlSmokeTest()
{
    AppController controller;
    const QString error = verifyQmlViewLoads(&controller, QUrl(QStringLiteral("qrc:/qml/ui/qml/views/JournalView.qml")));
    QVERIFY2(error.isEmpty(), qPrintable(error));
}

void RegressionTests::cameraViewQmlSmokeTest()
{
    AppController controller;
    const QString error = verifyQmlViewLoads(&controller, QUrl(QStringLiteral("qrc:/qml/ui/qml/views/CameraView.qml")));
    QVERIFY2(error.isEmpty(), qPrintable(error));
}

void RegressionTests::myProfileViewQmlSmokeTest()
{
    AppController controller;
    const QString error = verifyQmlViewLoads(&controller, QUrl(QStringLiteral("qrc:/qml/ui/qml/views/MyProfileView.qml")));
    QVERIFY2(error.isEmpty(), qPrintable(error));
}

void RegressionTests::importViewQmlSmokeTest()
{
    QtWebEngineQuick::initialize();

    AppController controller;
    const QString error = verifyQmlViewLoads(&controller, QUrl(QStringLiteral("qrc:/qml/ui/qml/views/ImportView.qml")));
    QVERIFY2(error.isEmpty(), qPrintable(error));
}

void RegressionTests::adminViewQmlSmokeTest()
{
    AppController controller;
    const QString error = verifyQmlViewLoads(&controller, QUrl(QStringLiteral("qrc:/qml/ui/qml/views/AdminView.qml")));
    QVERIFY2(error.isEmpty(), qPrintable(error));
}

void RegressionTests::settingsViewQmlSmokeTest()
{
    AppController controller;
    const QString error = verifyQmlViewLoads(&controller, QUrl(QStringLiteral("qrc:/qml/ui/qml/views/SettingsView.qml")));
    QVERIFY2(error.isEmpty(), qPrintable(error));
}

QTEST_MAIN(RegressionTests)
#include "RegressionTests.moc"