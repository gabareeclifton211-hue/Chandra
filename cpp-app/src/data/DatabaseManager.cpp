#include "DatabaseManager.h"

#include "core/DataPaths.h"

#include <QSqlError>
#include <QSqlQuery>

namespace {

constexpr const char *kConnectionName = "main";

bool execSql(QSqlQuery &query, const QString &sql)
{
    return query.exec(sql);
}

bool tableHasColumn(const QSqlDatabase &db, const QString &tableName, const QString &columnName)
{
    QSqlQuery query(db);
    if (!query.exec(QString("PRAGMA table_info(%1)").arg(tableName))) {
        return false;
    }

    while (query.next()) {
        if (query.value(1).toString() == columnName) {
            return true;
        }
    }

    return false;
}

bool ensureColumn(const QSqlDatabase &db, const QString &tableName, const QString &columnName, const QString &definition)
{
    if (tableHasColumn(db, tableName, columnName)) {
        return true;
    }

    QSqlQuery query(db);
    return query.exec(QString("ALTER TABLE %1 ADD COLUMN %2 %3").arg(tableName, columnName, definition));
}

} // namespace

namespace data {

bool DatabaseManager::initialize()
{
    if (!core::DataPaths::ensureInitialized()) {
        return false;
    }

    if (QSqlDatabase::contains(kConnectionName)) {
        return true;
    }

    QSqlDatabase db = QSqlDatabase::addDatabase("QSQLITE", kConnectionName);
    db.setDatabaseName(core::DataPaths::databasePath());
    if (!db.open()) {
        return false;
    }

    return ensureSchema(db);
}

QSqlDatabase DatabaseManager::database()
{
    return QSqlDatabase::database(kConnectionName);
}

bool DatabaseManager::ensureSchema(const QSqlDatabase &db)
{
    QSqlQuery query(db);

    if (!execSql(query,
        "CREATE TABLE IF NOT EXISTS users ("
        "id TEXT PRIMARY KEY,"
        "username TEXT NOT NULL UNIQUE,"
        "password_hash TEXT NOT NULL,"
        "role TEXT NOT NULL,"
        "email TEXT NOT NULL DEFAULT '',"
        "phone TEXT NOT NULL DEFAULT '',"
        "profile_picture TEXT NOT NULL DEFAULT '',"
        "pronouns TEXT NOT NULL DEFAULT '',"
        "created_at TEXT NOT NULL"
        ")")) {
        return false;
    }

    if (!ensureColumn(db, "users", "email", "TEXT NOT NULL DEFAULT ''")) {
        return false;
    }
    if (!ensureColumn(db, "users", "phone", "TEXT NOT NULL DEFAULT ''")) {
        return false;
    }
    if (!ensureColumn(db, "users", "profile_picture", "TEXT NOT NULL DEFAULT ''")) {
        return false;
    }
    if (!ensureColumn(db, "users", "pronouns", "TEXT NOT NULL DEFAULT ''")) {
        return false;
    }

    if (!execSql(query,
        "CREATE TABLE IF NOT EXISTS settings ("
        "user_id TEXT NOT NULL,"
        "key TEXT NOT NULL,"
        "value_json TEXT NOT NULL,"
        "PRIMARY KEY (user_id, key),"
        "FOREIGN KEY(user_id) REFERENCES users(id)"
        ")")) {
        return false;
    }

    if (!execSql(query,
        "CREATE TABLE IF NOT EXISTS file_items ("
        "id TEXT PRIMARY KEY,"
        "user_id TEXT NOT NULL,"
        "category TEXT NOT NULL,"
        "filename TEXT NOT NULL,"
        "file_path TEXT NOT NULL,"
        "description TEXT DEFAULT '',"
        "created_at TEXT NOT NULL,"
        "updated_at TEXT NOT NULL,"
        "UNIQUE(user_id, category, filename),"
        "FOREIGN KEY(user_id) REFERENCES users(id)"
        ")")) {
        return false;
    }

    if (!execSql(query,
        "CREATE TABLE IF NOT EXISTS journal_entries ("
        "id TEXT PRIMARY KEY,"
        "user_id TEXT NOT NULL,"
        "title TEXT NOT NULL,"
        "body TEXT NOT NULL,"
        "created_at TEXT NOT NULL,"
        "updated_at TEXT NOT NULL,"
        "FOREIGN KEY(user_id) REFERENCES users(id)"
        ")")) {
        return false;
    }

    if (!execSql(query,
        "CREATE TABLE IF NOT EXISTS activity_log ("
        "id TEXT PRIMARY KEY,"
        "ts TEXT NOT NULL,"
        "username TEXT NOT NULL DEFAULT '',"
        "action TEXT NOT NULL,"
        "details TEXT NOT NULL,"
        "is_web_search INTEGER NOT NULL DEFAULT 0"
        ")")) {
        return false;
    }

    return true;
}

} // namespace data
