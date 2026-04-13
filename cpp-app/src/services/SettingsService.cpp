#include "SettingsService.h"

#include "data/DatabaseManager.h"

#include <QSqlQuery>

namespace {

bool writeError(QString *errorMessage, const QString &message)
{
    if (errorMessage != nullptr) {
        *errorMessage = message;
    }
    return false;
}

} // namespace

namespace services {

QVariantMap SettingsService::getSettings(const QString &userId) const
{
    QVariantMap settings;

    QSqlQuery query(data::DatabaseManager::database());
    query.prepare("SELECT key, value_json FROM settings WHERE user_id = :user_id");
    query.bindValue(":user_id", userId);
    if (!query.exec()) {
        return settings;
    }

    while (query.next()) {
        settings.insert(query.value(0).toString(), query.value(1).toString());
    }

    return settings;
}

bool SettingsService::setSetting(const QString &userId,
                                 const QString &key,
                                 const QString &valueJson,
                                 QString *errorMessage) const
{
    if (key.trimmed().isEmpty()) {
        return writeError(errorMessage, "Setting key is required.");
    }

    QSqlQuery query(data::DatabaseManager::database());
    query.prepare(
        "INSERT INTO settings(user_id, key, value_json) VALUES(:user_id, :key, :value_json) "
        "ON CONFLICT(user_id, key) DO UPDATE SET value_json = excluded.value_json");
    query.bindValue(":user_id", userId);
    query.bindValue(":key", key.trimmed());
    query.bindValue(":value_json", valueJson);

    if (!query.exec()) {
        return writeError(errorMessage, "Failed to save setting.");
    }

    if (errorMessage != nullptr) {
        errorMessage->clear();
    }
    return true;
}

} // namespace services
