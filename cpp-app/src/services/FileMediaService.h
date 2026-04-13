#pragma once

#include <QString>
#include <QStringList>
#include <QVariantList>

namespace services {

class FileMediaService {
public:
    QVariantList listFiles(const QString &userId, const QString &category) const;
    QVariantList listAllFiles() const;
    QVariantList listFilesForUser(const QString &userId) const;
    bool importFromUrl(const QString &userId, const QString &username, const QString &category,
                       const QString &url, QString *errorMessage) const;
    bool uploadFiles(const QString &userId, const QString &username, const QString &category,
                     const QStringList &sourcePaths, QString *errorMessage) const;
    bool uploadFilesAndRemoveSource(const QString &userId, const QString &username, const QString &category,
                                    const QStringList &sourcePaths, QString *errorMessage) const;
    bool renameFile(const QString &userId, const QString &username, const QString &category,
                    const QString &oldName, const QString &newName, QString *errorMessage) const;
    bool moveFile(const QString &userId, const QString &username, const QString &fromCategory,
                  const QString &toCategory, const QString &filename, QString *errorMessage) const;
    bool deleteFile(const QString &userId, const QString &username, const QString &category,
                    const QString &filename, QString *errorMessage) const;
    bool deleteFileAdmin(const QString &userId, const QString &category, const QString &filename,
                         const QString &filePath, QString *errorMessage) const;
    bool moveFileAdmin(const QString &sourceUserId, const QString &sourceUsername,
                       const QString &fromCategory, const QString &filename,
                       const QString &destinationUserId, const QString &destinationUsername,
                       const QString &toCategory, QString *errorMessage) const;
    bool setDescription(const QString &userId, const QString &category, const QString &filename,
                        const QString &description, QString *errorMessage) const;

private:
    static bool isValidCategory(const QString &category);
    static bool isValidFilename(const QString &filename);
    static QString categoryDir(const QString &username, const QString &category);
    static QString uniqueFilePath(const QString &directory, const QString &filename);
};

} // namespace services
