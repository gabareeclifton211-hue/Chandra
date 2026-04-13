#include "JournalService.h"

#include "data/DatabaseManager.h"

#include <QDateTime>
#include <QSqlQuery>
#include <QUuid>
#include <QVariantMap>

namespace {

QString nowIso()
{
    return QDateTime::currentDateTimeUtc().toString(Qt::ISODate);
}

bool writeError(QString *errorMessage, const QString &message)
{
    if (errorMessage != nullptr) {
        *errorMessage = message;
    }
    return false;
}

} // namespace

namespace services {

QVariantList JournalService::listEntries(const QString &userId) const
{
    QVariantList entries;

    QSqlQuery query(data::DatabaseManager::database());
    query.prepare(
        "SELECT id, title, body, created_at, updated_at "
        "FROM journal_entries "
        "WHERE user_id = :user_id "
        "ORDER BY updated_at DESC, created_at DESC");
    query.bindValue(":user_id", userId);

    if (!query.exec()) {
        return entries;
    }

    while (query.next()) {
        QVariantMap item;
        item.insert("id", query.value(0).toString());
        item.insert("title", query.value(1).toString());
        item.insert("body", query.value(2).toString());
        item.insert("createdAt", query.value(3).toString());
        item.insert("updatedAt", query.value(4).toString());
        entries.append(item);
    }

    return entries;
}

QString JournalService::saveEntry(const QString &userId,
                                  const QString &entryId,
                                  const QString &title,
                                  const QString &body,
                                  QString *errorMessage) const
{
    const QString trimmedTitle = title.trimmed();
    if (trimmedTitle.isEmpty()) {
        writeError(errorMessage, "Title is required.");
        return QString();
    }

    const QString normalizedId = entryId.trimmed().isEmpty()
        ? QUuid::createUuid().toString(QUuid::WithoutBraces)
        : entryId.trimmed();

    QSqlDatabase db = data::DatabaseManager::database();
    if (!db.transaction()) {
        writeError(errorMessage, "Failed to start journal transaction.");
        return QString();
    }

    QSqlQuery existsQuery(db);
    existsQuery.prepare("SELECT COUNT(*) FROM journal_entries WHERE user_id = :user_id AND id = :id");
    existsQuery.bindValue(":user_id", userId);
    existsQuery.bindValue(":id", normalizedId);

    if (!existsQuery.exec() || !existsQuery.next()) {
        db.rollback();
        writeError(errorMessage, "Failed to check existing journal entry.");
        return QString();
    }

    const bool exists = existsQuery.value(0).toInt() > 0;

    QSqlQuery query(db);
    if (exists) {
        query.prepare(
            "UPDATE journal_entries "
            "SET title = :title, body = :body, updated_at = :updated_at "
            "WHERE user_id = :user_id AND id = :id");
        query.bindValue(":title", trimmedTitle);
        query.bindValue(":body", body);
        query.bindValue(":updated_at", nowIso());
        query.bindValue(":user_id", userId);
        query.bindValue(":id", normalizedId);
    } else {
        query.prepare(
            "INSERT INTO journal_entries(id, user_id, title, body, created_at, updated_at) "
            "VALUES(:id, :user_id, :title, :body, :created_at, :updated_at)");
        query.bindValue(":id", normalizedId);
        query.bindValue(":user_id", userId);
        query.bindValue(":title", trimmedTitle);
        query.bindValue(":body", body);
        query.bindValue(":created_at", nowIso());
        query.bindValue(":updated_at", nowIso());
    }

    if (!query.exec()) {
        db.rollback();
        writeError(errorMessage, "Failed to save journal entry.");
        return QString();
    }

    if (!db.commit()) {
        db.rollback();
        writeError(errorMessage, "Failed to commit journal entry.");
        return QString();
    }

    if (errorMessage != nullptr) {
        errorMessage->clear();
    }
    return normalizedId;
}

bool JournalService::deleteEntry(const QString &userId, const QString &entryId, QString *errorMessage) const
{
    const QString normalizedId = entryId.trimmed();
    if (normalizedId.isEmpty()) {
        return writeError(errorMessage, "Entry id is required.");
    }

    QSqlQuery query(data::DatabaseManager::database());
    query.prepare("DELETE FROM journal_entries WHERE user_id = :user_id AND id = :id");
    query.bindValue(":user_id", userId);
    query.bindValue(":id", normalizedId);

    if (!query.exec()) {
        return writeError(errorMessage, "Failed to delete journal entry.");
    }

    if (errorMessage != nullptr) {
        errorMessage->clear();
    }
    return true;
 }
 
 } // namespace services
