#pragma once

#include <QSqlDatabase>

namespace data {

class DatabaseManager {
public:
    static bool initialize();
    static QSqlDatabase database();

private:
    static bool ensureSchema(const QSqlDatabase &db);
};

} // namespace data
