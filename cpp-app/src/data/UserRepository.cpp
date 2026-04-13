#include "UserRepository.h"

#include "core/Security.h"
#include "data/DatabaseManager.h"

#include <QDateTime>
#include <QSqlQuery>
#include <QUuid>
#include <QVariantMap>

namespace {

bool writeError(QString *errorMessage, const QString &message)
{
    if (errorMessage != nullptr) {
        *errorMessage = message;
    }
    return false;
}

} // namespace

namespace data {

bool UserRepository::ensureDefaultSysop()
{
    QSqlDatabase db = DatabaseManager::database();

    QSqlQuery countQuery(db);
    if (!countQuery.exec("SELECT COUNT(*) FROM users")) {
        return false;
    }

    if (!countQuery.next()) {
        return false;
    }

    if (countQuery.value(0).toInt() > 0) {
        return true;
    }

    QSqlQuery insertQuery(db);
    insertQuery.prepare(
        "INSERT INTO users(id, username, password_hash, role, email, phone, profile_picture, pronouns, created_at) "
        "VALUES(:id, :username, :password_hash, :role, :email, :phone, :profile_picture, :pronouns, :created_at)");
    insertQuery.bindValue(":id", QUuid::createUuid().toString(QUuid::WithoutBraces));
    insertQuery.bindValue(":username", "chandra");
    insertQuery.bindValue(":password_hash", core::Security::hashPassword("chandra123"));
    insertQuery.bindValue(":role", "sysop");
    insertQuery.bindValue(":email", QString());
    insertQuery.bindValue(":phone", QString());
    insertQuery.bindValue(":profile_picture", QString());
    insertQuery.bindValue(":pronouns", QString());
    insertQuery.bindValue(":created_at", QDateTime::currentDateTimeUtc().toString(Qt::ISODate));

    return insertQuery.exec();
}

std::optional<UserRecord> UserRepository::authenticate(const QString &username, const QString &password)
{
    QSqlDatabase db = DatabaseManager::database();

    QSqlQuery query(db);
    query.prepare("SELECT id, username, password_hash, role, email, phone, profile_picture, pronouns FROM users WHERE username = :username");
    query.bindValue(":username", username);
    if (!query.exec()) {
        return std::nullopt;
    }

    if (!query.next()) {
        return std::nullopt;
    }

    const QString passwordHash = query.value(2).toString();
    if (!core::Security::verifyPassword(password, passwordHash)) {
        return std::nullopt;
    }

    UserRecord record;
    record.id = query.value(0).toString();
    record.username = query.value(1).toString();
    record.role = query.value(3).toString();
    record.email = query.value(4).toString();
    record.phone = query.value(5).toString();
    record.profilePicture = query.value(6).toString();
    record.pronouns = query.value(7).toString();
    return record;
}

std::optional<UserRecord> UserRepository::findUserById(const QString &userId)
{
    const QString normalizedId = userId.trimmed();
    if (normalizedId.isEmpty()) {
        return std::nullopt;
    }

    QSqlQuery query(DatabaseManager::database());
    query.prepare("SELECT id, username, role, email, phone, profile_picture, pronouns FROM users WHERE id = :id");
    query.bindValue(":id", normalizedId);
    if (!query.exec() || !query.next()) {
        return std::nullopt;
    }

    UserRecord record;
    record.id = query.value(0).toString();
    record.username = query.value(1).toString();
    record.role = query.value(2).toString();
    record.email = query.value(3).toString();
    record.phone = query.value(4).toString();
    record.profilePicture = query.value(5).toString();
    record.pronouns = query.value(6).toString();
    return record;
}

QVariantList UserRepository::listUsers()
{
    QVariantList users;

    QSqlQuery query(DatabaseManager::database());
    if (!query.exec("SELECT id, username, role, email, phone, profile_picture, pronouns, created_at FROM users ORDER BY created_at ASC")) {
        return users;
    }

    while (query.next()) {
        QVariantMap item;
        item.insert("id", query.value(0).toString());
        item.insert("username", query.value(1).toString());
        item.insert("role", query.value(2).toString());
        item.insert("email", query.value(3).toString());
        item.insert("phone", query.value(4).toString());
        item.insert("profilePicture", query.value(5).toString());
        item.insert("pronouns", query.value(6).toString());
        item.insert("createdAt", query.value(7).toString());
        users.append(item);
    }

    return users;
}

bool UserRepository::createUser(const QString &username, const QString &password, const QString &role,
                                const QString &email, const QString &phone, const QString &profilePicture,
                                const QString &pronouns, QString *errorMessage)
{
    const QString normalizedUsername = username.trimmed();
    const QString normalizedRole = role.trimmed().isEmpty() ? QStringLiteral("user") : role.trimmed();
    const QString normalizedEmail = email.trimmed();
    const QString normalizedPhone = phone.trimmed();
    const QString normalizedProfilePicture = profilePicture.trimmed();
    const QString normalizedPronouns = pronouns.trimmed();

    if (normalizedUsername.isEmpty()) {
        return writeError(errorMessage, "Username is required.");
    }
    if (password.isEmpty()) {
        return writeError(errorMessage, "Password is required.");
    }

    QSqlQuery query(DatabaseManager::database());
    query.prepare(
        "INSERT INTO users(id, username, password_hash, role, email, phone, profile_picture, pronouns, created_at) "
        "VALUES(:id, :username, :password_hash, :role, :email, :phone, :profile_picture, :pronouns, :created_at)");
    query.bindValue(":id", QUuid::createUuid().toString(QUuid::WithoutBraces));
    query.bindValue(":username", normalizedUsername);
    query.bindValue(":password_hash", core::Security::hashPassword(password));
    query.bindValue(":role", normalizedRole);
    query.bindValue(":email", normalizedEmail);
    query.bindValue(":phone", normalizedPhone);
    query.bindValue(":profile_picture", normalizedProfilePicture);
    query.bindValue(":pronouns", normalizedPronouns);
    query.bindValue(":created_at", QDateTime::currentDateTimeUtc().toString(Qt::ISODate));

    if (!query.exec()) {
        return writeError(errorMessage, "Failed to create user. Username may already exist.");
    }

    if (errorMessage != nullptr) {
        errorMessage->clear();
    }
    return true;
}

bool UserRepository::updateUserProfile(const QString &userId, const QString &email, const QString &phone,
                                       const QString &profilePicture, const QString &pronouns,
                                       QString *errorMessage)
{
    const QString normalizedId = userId.trimmed();
    if (normalizedId.isEmpty()) {
        return writeError(errorMessage, "User id is required.");
    }

    QSqlQuery query(DatabaseManager::database());
    query.prepare(
        "UPDATE users SET email = :email, phone = :phone, profile_picture = :profile_picture, pronouns = :pronouns "
        "WHERE id = :id");
    query.bindValue(":email", email.trimmed());
    query.bindValue(":phone", phone.trimmed());
    query.bindValue(":profile_picture", profilePicture.trimmed());
    query.bindValue(":pronouns", pronouns.trimmed());
    query.bindValue(":id", normalizedId);

    if (!query.exec()) {
        return writeError(errorMessage, "Failed to update user profile.");
    }

    if (errorMessage != nullptr) {
        errorMessage->clear();
    }
    return true;
}

bool UserRepository::deleteUser(const QString &userId, QString *errorMessage)
{
    const QString normalizedId = userId.trimmed();
    if (normalizedId.isEmpty()) {
        return writeError(errorMessage, "User id is required.");
    }

    QSqlQuery query(DatabaseManager::database());
    query.prepare("DELETE FROM users WHERE id = :id");
    query.bindValue(":id", normalizedId);

    if (!query.exec()) {
        return writeError(errorMessage, "Failed to delete user.");
    }

    if (errorMessage != nullptr) {
        errorMessage->clear();
    }
    return true;
}

bool UserRepository::resetPassword(const QString &userId, const QString &newPassword, QString *errorMessage)
{
    const QString normalizedId = userId.trimmed();
    if (normalizedId.isEmpty()) {
        return writeError(errorMessage, "User id is required.");
    }
    if (newPassword.isEmpty()) {
        return writeError(errorMessage, "New password is required.");
    }

    QSqlQuery query(DatabaseManager::database());
    query.prepare("UPDATE users SET password_hash = :password_hash WHERE id = :id");
    query.bindValue(":password_hash", core::Security::hashPassword(newPassword));
    query.bindValue(":id", normalizedId);

    if (!query.exec()) {
        return writeError(errorMessage, "Failed to reset password.");
    }

    if (errorMessage != nullptr) {
        errorMessage->clear();
    }
    return true;
}

bool UserRepository::changePassword(const QString &userId, const QString &oldPassword, const QString &newPassword,
                                   QString *errorMessage)
{
    const QString normalizedId = userId.trimmed();
    if (normalizedId.isEmpty()) {
        return writeError(errorMessage, "User id is required.");
    }
    if (oldPassword.isEmpty()) {
        return writeError(errorMessage, "Current password is required.");
    }
    if (newPassword.isEmpty()) {
        return writeError(errorMessage, "New password is required.");
    }

    QSqlQuery query(DatabaseManager::database());
    query.prepare("SELECT password_hash FROM users WHERE id = :id");
    query.bindValue(":id", normalizedId);
    if (!query.exec() || !query.next()) {
        return writeError(errorMessage, "User not found.");
    }

    const QString passwordHash = query.value(0).toString();
    if (!core::Security::verifyPassword(oldPassword, passwordHash)) {
        return writeError(errorMessage, "Current password is incorrect.");
    }

    QSqlQuery updateQuery(DatabaseManager::database());
    updateQuery.prepare("UPDATE users SET password_hash = :password_hash WHERE id = :id");
    updateQuery.bindValue(":password_hash", core::Security::hashPassword(newPassword));
    updateQuery.bindValue(":id", normalizedId);

    if (!updateQuery.exec()) {
        return writeError(errorMessage, "Failed to change password.");
    }

    if (errorMessage != nullptr) {
        errorMessage->clear();
    }
    return true;
}

} // namespace data
