#pragma once

#include <QString>
#include <QVariantList>

namespace services {

class JournalService {
public:
    QVariantList listEntries(const QString &userId) const;
    QString saveEntry(const QString &userId,
                      const QString &entryId,
                      const QString &title,
                      const QString &body,
                      QString *errorMessage) const;
    bool deleteEntry(const QString &userId, const QString &entryId, QString *errorMessage) const;
};

} // namespace services
