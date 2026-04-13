#pragma once

#include <QString>

namespace core {

class Security {
public:
    static QString hashPassword(const QString &password);
    static bool verifyPassword(const QString &password, const QString &storedHash);
};

} // namespace core
