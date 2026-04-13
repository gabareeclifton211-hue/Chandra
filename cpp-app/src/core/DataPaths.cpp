#include "DataPaths.h"

#include <QDir>
#include <QStandardPaths>

namespace core {

QString DataPaths::appDataRoot()
{
    const QString base = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    return QDir(base).filePath("chandra-journey-cpp");
}

QString DataPaths::databasePath()
{
    return QDir(appDataRoot()).filePath("chandra.sqlite");
}

QString DataPaths::usersRoot()
{
    return QDir(appDataRoot()).filePath("users");
}

bool DataPaths::ensureInitialized()
{
    QDir dir;
    return dir.mkpath(appDataRoot()) && dir.mkpath(usersRoot());
}

} // namespace core
