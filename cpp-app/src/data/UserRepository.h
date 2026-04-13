#pragma once

#include <QString>
#include <QVariantList>
#include <optional>

namespace data {

struct UserRecord {
    QString id;
    QString username;
    QString role;
    QString email;
    QString phone;
    QString profilePicture;
    QString pronouns;
};

class UserRepository {
public:
    static bool ensureDefaultSysop();
    static std::optional<UserRecord> authenticate(const QString &username, const QString &password);
    static std::optional<UserRecord> findUserById(const QString &userId);
    static QVariantList listUsers();
    static bool createUser(const QString &username, const QString &password, const QString &role,
                           const QString &email, const QString &phone, const QString &profilePicture,
                           const QString &pronouns, QString *errorMessage);
    static bool updateUserProfile(const QString &userId, const QString &email, const QString &phone,
                                  const QString &profilePicture, const QString &pronouns,
                                  QString *errorMessage);
    static bool deleteUser(const QString &userId, QString *errorMessage);
    static bool resetPassword(const QString &userId, const QString &newPassword, QString *errorMessage);
    static bool changePassword(const QString &userId, const QString &oldPassword, const QString &newPassword,
                              QString *errorMessage);
};

} // namespace data
