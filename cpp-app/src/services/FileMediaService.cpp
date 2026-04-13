#include "FileMediaService.h"

#include "core/DataPaths.h"
#include "data/DatabaseManager.h"

#include <QDateTime>
#include <QDebug>
#include <QCryptographicHash>
#include <QDir>
#include <QEventLoop>
#include <QFile>
#include <QFileInfo>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QRegularExpression>
#include <QSqlQuery>
#include <QTemporaryDir>
#include <QUrl>
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

QString normalizedComparablePath(const QString &path)
{
    return QDir::cleanPath(QDir::fromNativeSeparators(path));
}

bool isPathWithinRoot(const QString &candidatePath, const QString &rootPath)
{
    const QString normalizedCandidate = normalizedComparablePath(candidatePath);
    const QString normalizedRoot = normalizedComparablePath(rootPath);
    if (normalizedCandidate.isEmpty() || normalizedRoot.isEmpty()) {
        return false;
    }

#ifdef Q_OS_WIN
    return normalizedCandidate.compare(normalizedRoot, Qt::CaseInsensitive) == 0 ||
           normalizedCandidate.startsWith(normalizedRoot + '/', Qt::CaseInsensitive);
#else
    return normalizedCandidate == normalizedRoot ||
           normalizedCandidate.startsWith(normalizedRoot + '/');
#endif
}

QByteArray fileSha256(const QString &path)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        return {};
    }

    QCryptographicHash hasher(QCryptographicHash::Sha256);
    while (!file.atEnd()) {
        const QByteArray chunk = file.read(256 * 1024);
        if (chunk.isEmpty() && file.error() != QFileDevice::NoError) {
            return {};
        }
        hasher.addData(chunk);
    }
    return hasher.result();
}

bool sameContent(const QString &leftPath, const QString &rightPath)
{
    const QFileInfo leftInfo(leftPath);
    const QFileInfo rightInfo(rightPath);
    if (!leftInfo.exists() || !rightInfo.exists() || !leftInfo.isFile() || !rightInfo.isFile()) {
        return false;
    }
    if (leftInfo.size() != rightInfo.size()) {
        return false;
    }

    const QByteArray leftHash = fileSha256(leftPath);
    const QByteArray rightHash = fileSha256(rightPath);
    if (leftHash.isEmpty() || rightHash.isEmpty()) {
        return false;
    }
    return leftHash == rightHash;
}

QString toLocalFilePath(const QString &sourcePath)
{
    QString path = sourcePath.trimmed();

    if ((path.startsWith('"') && path.endsWith('"')) ||
        (path.startsWith('\'') && path.endsWith('\''))) {
        path = path.mid(1, path.size() - 2).trimmed();
    }

    if (path.startsWith("file:", Qt::CaseInsensitive)) {
        const QUrl sourceUrl(path);
        if (sourceUrl.isLocalFile()) {
            path = sourceUrl.toLocalFile();
        }
    }

    return QDir::cleanPath(path);
}

QString extensionFromContentType(const QString &contentType)
{
    static const QHash<QString, QString> extMap = {
        {"image/jpeg", ".jpg"},
        {"image/png", ".png"},
        {"image/gif", ".gif"},
        {"image/webp", ".webp"},
        {"video/mp4", ".mp4"},
        {"video/webm", ".webm"},
        {"video/quicktime", ".mov"},
        {"audio/mpeg", ".mp3"},
        {"audio/wav", ".wav"},
        {"application/pdf", ".pdf"}
    };

    return extMap.value(contentType.toLower().trimmed());
}

QString inferFilenameFromReply(const QUrl &url, const QNetworkReply *reply)
{
    const QString disposition = reply->header(QNetworkRequest::ContentDispositionHeader).toString();
    const QRegularExpression dispositionRe("filename\\*?=(?:UTF-8''|\"?)([^\";]+)", QRegularExpression::CaseInsensitiveOption);
    const QRegularExpressionMatch match = dispositionRe.match(disposition);
    if (match.hasMatch()) {
        return QUrl::fromPercentEncoding(match.captured(1).toUtf8()).trimmed();
    }

    const QString urlName = QFileInfo(url.path()).fileName();
    if (!urlName.isEmpty()) {
        return urlName;
    }

    const QString contentType = reply->header(QNetworkRequest::ContentTypeHeader).toString().split(';').first().trimmed();
    const QString extension = extensionFromContentType(contentType);
    return QStringLiteral("import-%1%2").arg(QDateTime::currentMSecsSinceEpoch()).arg(extension.isEmpty() ? ".bin" : extension);
}

bool updateFileRecordPath(const QString &userId,
                          const QString &fromCategory,
                          const QString &fromFilename,
                          const QString &toCategory,
                          const QString &toFilename,
                          const QString &toPath)
{
    QSqlQuery query(data::DatabaseManager::database());
    query.prepare(
        "UPDATE file_items "
        "SET category = :to_category, filename = :to_filename, file_path = :to_path, updated_at = :updated_at "
        "WHERE user_id = :user_id AND category = :from_category AND filename = :from_filename");
    query.bindValue(":to_category", toCategory);
    query.bindValue(":to_filename", toFilename);
    query.bindValue(":to_path", toPath);
    query.bindValue(":updated_at", nowIso());
    query.bindValue(":user_id", userId);
    query.bindValue(":from_category", fromCategory);
    query.bindValue(":from_filename", fromFilename);
    return query.exec();
}

} // namespace

namespace services {

QVariantList FileMediaService::listFiles(const QString &userId, const QString &category) const
{
    QVariantList files;
    if (!isValidCategory(category)) {
        return files;
    }

    QSqlQuery query(data::DatabaseManager::database());
    query.prepare(
        "SELECT filename, file_path, description, created_at, updated_at "
        "FROM file_items "
        "WHERE user_id = :user_id AND category = :category "
        "ORDER BY updated_at DESC, created_at DESC");
    query.bindValue(":user_id", userId);
    query.bindValue(":category", category);
    if (!query.exec()) {
        return files;
    }

    while (query.next()) {
        QVariantMap item;
        item.insert("filename", query.value(0).toString());
        item.insert("filePath", query.value(1).toString());
        item.insert("description", query.value(2).toString());
        item.insert("createdAt", query.value(3).toString());
        item.insert("updatedAt", query.value(4).toString());
        files.append(item);
    }

    return files;
}

QVariantList FileMediaService::listAllFiles() const
{
    QVariantList files;

    QSqlQuery query(data::DatabaseManager::database());
    if (!query.exec(
            "SELECT user_id, category, filename, file_path, description, updated_at "
            "FROM file_items "
            "ORDER BY updated_at DESC")) {
        return files;
    }

    while (query.next()) {
        QVariantMap item;
        item.insert("userId", query.value(0).toString());
        item.insert("category", query.value(1).toString());
        item.insert("filename", query.value(2).toString());
        item.insert("filePath", query.value(3).toString());
        item.insert("description", query.value(4).toString());
        item.insert("updatedAt", query.value(5).toString());
        files.append(item);
    }

    return files;
}

QVariantList FileMediaService::listFilesForUser(const QString &userId) const
{
    QVariantList files;
    const QString normalizedUserId = userId.trimmed();
    if (normalizedUserId.isEmpty()) {
        return files;
    }

    QSqlQuery query(data::DatabaseManager::database());
    query.prepare(
        "SELECT user_id, category, filename, file_path, description, updated_at "
        "FROM file_items "
        "WHERE user_id = :user_id "
        "ORDER BY updated_at DESC");
    query.bindValue(":user_id", normalizedUserId);
    if (!query.exec()) {
        return files;
    }

    while (query.next()) {
        QVariantMap item;
        item.insert("userId", query.value(0).toString());
        item.insert("category", query.value(1).toString());
        item.insert("filename", query.value(2).toString());
        item.insert("filePath", query.value(3).toString());
        item.insert("description", query.value(4).toString());
        item.insert("updatedAt", query.value(5).toString());
        files.append(item);
    }

    return files;
}

bool FileMediaService::importFromUrl(const QString &userId,
                                     const QString &username,
                                     const QString &category,
                                     const QString &url,
                                     QString *errorMessage) const
{
    if (!isValidCategory(category)) {
        return writeError(errorMessage, "Invalid category.");
    }

    const QUrl parsedUrl = QUrl::fromUserInput(url.trimmed());
    if (!parsedUrl.isValid() || !(parsedUrl.scheme() == "http" || parsedUrl.scheme() == "https")) {
        return writeError(errorMessage, "URL must be a valid http or https address.");
    }

    QNetworkAccessManager manager;
    QNetworkRequest request(parsedUrl);
    QNetworkReply *reply = manager.get(request);

    QEventLoop loop;
    QObject::connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    loop.exec();

    const QScopedPointer<QNetworkReply, QScopedPointerDeleteLater> replyGuard(reply);
    if (reply->error() != QNetworkReply::NoError) {
        return writeError(errorMessage, "Failed to download URL content.");
    }

    const QString filename = inferFilenameFromReply(parsedUrl, reply).trimmed();
    if (!isValidFilename(filename)) {
        return writeError(errorMessage, "Downloaded filename was invalid.");
    }

    QTemporaryDir tempDir;
    if (!tempDir.isValid()) {
        return writeError(errorMessage, "Failed to prepare temporary directory.");
    }

    const QString tempPath = QDir(tempDir.path()).filePath(filename);
    QFile file(tempPath);
    if (!file.open(QIODevice::WriteOnly)) {
        return writeError(errorMessage, "Failed to create temporary file.");
    }

    file.write(reply->readAll());
    file.close();

    return uploadFiles(userId, username, category, { tempPath }, errorMessage);
}

bool FileMediaService::uploadFiles(const QString &userId,
                                   const QString &username,
                                   const QString &category,
                                   const QStringList &sourcePaths,
                                   QString *errorMessage) const
{
    if (!isValidCategory(category)) {
        return writeError(errorMessage, "Invalid category.");
    }

    const QString destinationDir = categoryDir(username, category);
    if (!QDir().mkpath(destinationDir)) {
        return writeError(errorMessage, "Failed to initialize category directory.");
    }

    QSqlDatabase db = data::DatabaseManager::database();
    if (!db.transaction()) {
        return writeError(errorMessage, "Failed to start database transaction.");
    }

    QSet<QString> existingNames;
    QStringList existingPaths;
    {
        QSqlQuery existingQuery(db);
        existingQuery.prepare(
            "SELECT filename, file_path FROM file_items "
            "WHERE user_id = :user_id AND category = :category");
        existingQuery.bindValue(":user_id", userId);
        existingQuery.bindValue(":category", category);
        if (!existingQuery.exec()) {
            db.rollback();
            return writeError(errorMessage, "Failed to inspect existing files.");
        }

        while (existingQuery.next()) {
            existingNames.insert(existingQuery.value(0).toString().toCaseFolded());
            existingPaths.append(existingQuery.value(1).toString());
        }
    }

    QStringList copiedPaths;
    QStringList skippedDuplicates;

    for (const QString &inputPath : sourcePaths) {
        const QString sourcePath = toLocalFilePath(inputPath).trimmed();
        QFileInfo sourceInfo(sourcePath);
        if (!sourceInfo.exists() || !sourceInfo.isFile()) {
            db.rollback();
            for (const QString &copiedPath : copiedPaths) {
                QFile::remove(copiedPath);
            }
            return writeError(
                errorMessage,
                QString("Invalid file path: %1").arg(sourcePath.isEmpty() ? QStringLiteral("<empty>") : sourcePath));
        }

        const QString originalFilename = sourceInfo.fileName();
        if (!isValidFilename(originalFilename)) {
            db.rollback();
            for (const QString &copiedPath : copiedPaths) {
                QFile::remove(copiedPath);
            }
            return writeError(errorMessage, "Invalid filename detected.");
        }

        if (existingNames.contains(originalFilename.toCaseFolded())) {
            skippedDuplicates.append(originalFilename);
            continue;
        }

        bool duplicateDetected = false;
        for (const QString &existingPath : existingPaths) {
            if (sameContent(sourcePath, existingPath)) {
                skippedDuplicates.append(originalFilename);
                duplicateDetected = true;
                break;
            }
        }
        if (duplicateDetected) {
            continue;
        }

        for (const QString &copiedPath : copiedPaths) {
            if (sameContent(sourcePath, copiedPath)) {
                skippedDuplicates.append(originalFilename);
                duplicateDetected = true;
                break;
            }
        }
        if (duplicateDetected) {
            continue;
        }

        const QString destinationPath = QDir(destinationDir).filePath(originalFilename);
        const QString finalFilename = originalFilename;

        if (!QFile::copy(sourcePath, destinationPath)) {
            db.rollback();
            for (const QString &copiedPath : copiedPaths) {
                QFile::remove(copiedPath);
            }
            return writeError(errorMessage, QString("Failed to copy file: %1").arg(sourceInfo.fileName()));
        }
        copiedPaths.append(destinationPath);
        existingNames.insert(finalFilename.toCaseFolded());
        existingPaths.append(destinationPath);

        QSqlQuery query(db);
        query.prepare(
            "INSERT INTO file_items(id, user_id, category, filename, file_path, description, created_at, updated_at) "
            "VALUES(:id, :user_id, :category, :filename, :file_path, '', :created_at, :updated_at) "
            "ON CONFLICT(user_id, category, filename) DO UPDATE SET "
            "file_path = excluded.file_path, updated_at = excluded.updated_at");
        query.bindValue(":id", QUuid::createUuid().toString(QUuid::WithoutBraces));
        query.bindValue(":user_id", userId);
        query.bindValue(":category", category);
        query.bindValue(":filename", finalFilename);
        query.bindValue(":file_path", destinationPath);
        query.bindValue(":created_at", nowIso());
        query.bindValue(":updated_at", nowIso());
        if (!query.exec()) {
            db.rollback();
            for (const QString &copiedPath : copiedPaths) {
                QFile::remove(copiedPath);
            }
            return writeError(errorMessage, "Failed to save file metadata.");
        }
    }

    if (copiedPaths.isEmpty()) {
        db.rollback();
        if (!skippedDuplicates.isEmpty()) {
            return writeError(errorMessage, "All selected files were duplicates.");
        }
        return writeError(errorMessage, "No files were uploaded.");
    }

    if (!db.commit()) {
        db.rollback();
        for (const QString &copiedPath : copiedPaths) {
            QFile::remove(copiedPath);
        }
        return writeError(errorMessage, "Failed to commit file metadata.");
    }

    return true;
}

bool FileMediaService::uploadFilesAndRemoveSource(const QString &userId,
                                                  const QString &username,
                                                  const QString &category,
                                                  const QStringList &sourcePaths,
                                                  QString *errorMessage) const
{
    const bool ok = uploadFiles(userId, username, category, sourcePaths, errorMessage);
    if (!ok) {
        return false;
    }

    for (const QString &inputPath : sourcePaths) {
        const QString localPath = toLocalFilePath(inputPath).trimmed();
        if (!localPath.isEmpty() && QFileInfo::exists(localPath)) {
            if (!QFile::remove(localPath)) {
                qWarning() << "Failed to remove consumed import source file, retrying:" << localPath;
                if (!QFile::remove(localPath)) {
                    qWarning() << "Failed to remove consumed import source file after retry:" << localPath;
                }
            }
        }
    }

    if (errorMessage != nullptr) {
        errorMessage->clear();
    }
    return true;
}

bool FileMediaService::renameFile(const QString &userId,
                                  const QString &username,
                                  const QString &category,
                                  const QString &oldName,
                                  const QString &newName,
                                  QString *errorMessage) const
{
    if (!isValidCategory(category) || !isValidFilename(oldName) || !isValidFilename(newName)) {
        return writeError(errorMessage, "Invalid category or filename.");
    }

    const QString directory = categoryDir(username, category);
    const QString oldPath = QDir(directory).filePath(oldName);
    const QString newPath = QDir(directory).filePath(newName);

    if (!QFileInfo::exists(oldPath)) {
        return writeError(errorMessage, "Source file does not exist.");
    }
    if (QFileInfo::exists(newPath)) {
        return writeError(errorMessage, "Destination filename already exists.");
    }

    if (!QFile::rename(oldPath, newPath)) {
        return writeError(errorMessage, "Failed to rename file.");
    }

    if (!updateFileRecordPath(userId, category, oldName, category, newName, newPath)) {
        QFile::rename(newPath, oldPath);
        return writeError(errorMessage, "Failed to update metadata after rename.");
    }

    return true;
}

bool FileMediaService::moveFile(const QString &userId,
                                const QString &username,
                                const QString &fromCategory,
                                const QString &toCategory,
                                const QString &filename,
                                QString *errorMessage) const
{
    if (!isValidCategory(fromCategory) || !isValidCategory(toCategory) || !isValidFilename(filename)) {
        return writeError(errorMessage, "Invalid category or filename.");
    }

    const QString sourceDir = categoryDir(username, fromCategory);
    const QString destinationDir = categoryDir(username, toCategory);
    if (!QDir().mkpath(destinationDir)) {
        return writeError(errorMessage, "Failed to initialize destination directory.");
    }

    const QString sourcePath = QDir(sourceDir).filePath(filename);
    if (!QFileInfo::exists(sourcePath)) {
        return writeError(errorMessage, "Source file does not exist.");
    }

    const QString destinationPath = uniqueFilePath(destinationDir, filename);
    const QString destinationFilename = QFileInfo(destinationPath).fileName();

    if (!QFile::rename(sourcePath, destinationPath)) {
        return writeError(errorMessage, "Failed to move file.");
    }

    if (!updateFileRecordPath(userId, fromCategory, filename, toCategory, destinationFilename, destinationPath)) {
        QFile::rename(destinationPath, sourcePath);
        return writeError(errorMessage, "Failed to update metadata after move.");
    }

    return true;
}

bool FileMediaService::deleteFile(const QString &userId,
                                  const QString &username,
                                  const QString &category,
                                  const QString &filename,
                                  QString *errorMessage) const
{
    if (!isValidCategory(category) || !isValidFilename(filename)) {
        return writeError(errorMessage, "Invalid category or filename.");
    }

    const QString path = QDir(categoryDir(username, category)).filePath(filename);
    if (QFileInfo::exists(path) && !QFile::remove(path)) {
        return writeError(errorMessage, "Failed to remove file from disk.");
    }

    QSqlQuery query(data::DatabaseManager::database());
    query.prepare("DELETE FROM file_items WHERE user_id = :user_id AND category = :category AND filename = :filename");
    query.bindValue(":user_id", userId);
    query.bindValue(":category", category);
    query.bindValue(":filename", filename);
    if (!query.exec()) {
        return writeError(errorMessage, "Failed to remove metadata.");
    }

    return true;
}

bool FileMediaService::deleteFileAdmin(const QString &userId,
                                       const QString &category,
                                       const QString &filename,
                                       const QString &filePath,
                                       QString *errorMessage) const
{
    if (userId.trimmed().isEmpty() || !isValidCategory(category) || !isValidFilename(filename)) {
        return writeError(errorMessage, "Invalid file selection.");
    }

    if (!filePath.trimmed().isEmpty()) {
        QFileInfo fileInfo(filePath);
        if (fileInfo.exists() && fileInfo.isFile()) {
            const QString canonicalFile = fileInfo.canonicalFilePath();
            const QString resolvedFile = canonicalFile.isEmpty() ? fileInfo.absoluteFilePath() : canonicalFile;

            const QFileInfo rootInfo(core::DataPaths::usersRoot());
            const QString canonicalRoot = rootInfo.canonicalFilePath();
            const QString resolvedRoot = canonicalRoot.isEmpty() ? rootInfo.absoluteFilePath() : canonicalRoot;
            const bool underUsersRoot = isPathWithinRoot(resolvedFile, resolvedRoot);

            if (!underUsersRoot) {
                return writeError(errorMessage, "Refusing to delete file outside managed storage.");
            }

            if (!QFile::remove(resolvedFile)) {
                return writeError(errorMessage, "Failed to remove file from disk.");
            }
        }
    }

    QSqlQuery query(data::DatabaseManager::database());
    query.prepare("DELETE FROM file_items WHERE user_id = :user_id AND category = :category AND filename = :filename");
    query.bindValue(":user_id", userId);
    query.bindValue(":category", category);
    query.bindValue(":filename", filename);
    if (!query.exec()) {
        return writeError(errorMessage, "Failed to remove metadata.");
    }

    return true;
}

bool FileMediaService::moveFileAdmin(const QString &sourceUserId,
                                     const QString &sourceUsername,
                                     const QString &fromCategory,
                                     const QString &filename,
                                     const QString &destinationUserId,
                                     const QString &destinationUsername,
                                     const QString &toCategory,
                                     QString *errorMessage) const
{
    const QString normalizedSourceUserId = sourceUserId.trimmed();
    const QString normalizedDestinationUserId = destinationUserId.trimmed();
    const QString normalizedSourceUsername = sourceUsername.trimmed();
    const QString normalizedDestinationUsername = destinationUsername.trimmed();

    if (normalizedSourceUserId.isEmpty() ||
        normalizedDestinationUserId.isEmpty() ||
        normalizedSourceUsername.isEmpty() ||
        normalizedDestinationUsername.isEmpty() ||
        !isValidCategory(fromCategory) ||
        !isValidCategory(toCategory) ||
        !isValidFilename(filename)) {
        return writeError(errorMessage, "Invalid move request.");
    }

    if (normalizedSourceUserId == normalizedDestinationUserId && fromCategory == toCategory) {
        return writeError(errorMessage, "Source and destination are the same.");
    }

    QSqlDatabase db = data::DatabaseManager::database();
    QSqlQuery sourceQuery(db);
    sourceQuery.prepare(
        "SELECT file_path FROM file_items "
        "WHERE user_id = :user_id AND category = :category AND filename = :filename");
    sourceQuery.bindValue(":user_id", normalizedSourceUserId);
    sourceQuery.bindValue(":category", fromCategory);
    sourceQuery.bindValue(":filename", filename);
    if (!sourceQuery.exec()) {
        return writeError(errorMessage, "Failed to read source file metadata.");
    }
    if (!sourceQuery.next()) {
        return writeError(errorMessage, "Selected file metadata was not found.");
    }

    QString sourcePath = sourceQuery.value(0).toString().trimmed();
    if (sourcePath.isEmpty()) {
        sourcePath = QDir(categoryDir(normalizedSourceUsername, fromCategory)).filePath(filename);
    }

    QFileInfo sourceInfo(sourcePath);
    if (!sourceInfo.exists() || !sourceInfo.isFile()) {
        return writeError(errorMessage, "Source file does not exist.");
    }

    const QString canonicalSource = sourceInfo.canonicalFilePath();
    const QString resolvedSource = canonicalSource.isEmpty() ? sourceInfo.absoluteFilePath() : canonicalSource;
    const QFileInfo rootInfo(core::DataPaths::usersRoot());
    const QString canonicalRoot = rootInfo.canonicalFilePath();
    const QString resolvedRoot = canonicalRoot.isEmpty() ? rootInfo.absoluteFilePath() : canonicalRoot;
    const bool underUsersRoot = isPathWithinRoot(resolvedSource, resolvedRoot);

    if (!underUsersRoot) {
        return writeError(errorMessage, "Refusing to move file outside managed storage.");
    }

    const QString destinationDir = categoryDir(normalizedDestinationUsername, toCategory);
    if (!QDir().mkpath(destinationDir)) {
        return writeError(errorMessage, "Failed to initialize destination directory.");
    }

    const QString destinationPath = uniqueFilePath(destinationDir, filename);
    const QString destinationFilename = QFileInfo(destinationPath).fileName();

    if (!QFile::rename(resolvedSource, destinationPath)) {
        return writeError(errorMessage, "Failed to move file on disk.");
    }

    QSqlQuery updateQuery(db);
    updateQuery.prepare(
        "UPDATE file_items "
        "SET user_id = :to_user_id, category = :to_category, filename = :to_filename, "
        "    file_path = :to_path, updated_at = :updated_at "
        "WHERE user_id = :from_user_id AND category = :from_category AND filename = :from_filename");
    updateQuery.bindValue(":to_user_id", normalizedDestinationUserId);
    updateQuery.bindValue(":to_category", toCategory);
    updateQuery.bindValue(":to_filename", destinationFilename);
    updateQuery.bindValue(":to_path", destinationPath);
    updateQuery.bindValue(":updated_at", nowIso());
    updateQuery.bindValue(":from_user_id", normalizedSourceUserId);
    updateQuery.bindValue(":from_category", fromCategory);
    updateQuery.bindValue(":from_filename", filename);

    if (!updateQuery.exec() || updateQuery.numRowsAffected() <= 0) {
        QFile::rename(destinationPath, resolvedSource);
        return writeError(errorMessage, "Failed to update metadata after admin move.");
    }

    return true;
}

bool FileMediaService::setDescription(const QString &userId,
                                      const QString &category,
                                      const QString &filename,
                                      const QString &description,
                                      QString *errorMessage) const
{
    if (!isValidCategory(category) || !isValidFilename(filename)) {
        return writeError(errorMessage, "Invalid category or filename.");
    }

    QSqlQuery query(data::DatabaseManager::database());
    query.prepare(
        "UPDATE file_items "
        "SET description = :description, updated_at = :updated_at "
        "WHERE user_id = :user_id AND category = :category AND filename = :filename");
    query.bindValue(":description", description.trimmed());
    query.bindValue(":updated_at", nowIso());
    query.bindValue(":user_id", userId);
    query.bindValue(":category", category);
    query.bindValue(":filename", filename);

    if (!query.exec()) {
        return writeError(errorMessage, "Failed to update description.");
    }

    return true;
}

bool FileMediaService::isValidCategory(const QString &category)
{
    static const QRegularExpression pattern("^[a-z0-9][a-z0-9\\-]{0,63}$");
    return pattern.match(category).hasMatch();
}

bool FileMediaService::isValidFilename(const QString &filename)
{
    if (filename.trimmed().isEmpty()) {
        return false;
    }
    if (filename.contains('/') || filename.contains('\\') || filename.contains("..")) {
        return false;
    }
    return QFileInfo(filename).fileName() == filename;
}

QString FileMediaService::categoryDir(const QString &username, const QString &category)
{
    const QString userRoot = QDir(core::DataPaths::usersRoot()).filePath(username);
    return QDir(userRoot).filePath(category);
}

QString FileMediaService::uniqueFilePath(const QString &directory, const QString &filename)
{
    const QFileInfo parsed(filename);
    const QString baseName = parsed.completeBaseName();
    const QString suffix = parsed.suffix().isEmpty() ? QString() : "." + parsed.suffix();

    QString candidate = filename;
    QString candidatePath = QDir(directory).filePath(candidate);
    int counter = 1;

    while (QFileInfo::exists(candidatePath)) {
        candidate = QStringLiteral("%1(%2)%3").arg(baseName).arg(counter).arg(suffix);
        candidatePath = QDir(directory).filePath(candidate);
        ++counter;
    }

    return candidatePath;
}

} // namespace services
