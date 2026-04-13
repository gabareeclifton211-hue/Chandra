#pragma once

#include <QVariantMap>

namespace services {

class SettingsService {
public:
    QVariantMap getSettings(const QString &userId) const;
    bool setSetting(const QString &userId, const QString &key, const QString &valueJson, QString *errorMessage) const;
};

} // namespace services
