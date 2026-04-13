#pragma once

#include <QString>

namespace core {

class DataPaths {
public:
    static QString appDataRoot();
    static QString databasePath();
    static QString usersRoot();
    static bool ensureInitialized();
};

} // namespace core
