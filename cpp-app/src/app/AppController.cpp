#include "AppController.h"

#include "core/DataPaths.h"
#include "data/DatabaseManager.h"
#include "data/UserRepository.h"
#include "services/FileMediaService.h"
#include "services/JournalService.h"
#include "services/SettingsService.h"

#include <QDesktopServices>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QHash>
#include <QSqlError>
#include <QSqlQuery>
#include <QStandardPaths>
#include <QTextStream>
#include <QUrl>
#include <QUuid>

namespace {

struct LoginAttemptState {
    int failures = 0;
    QDateTime blockedUntil;
};

QHash<QString, LoginAttemptState> &loginAttempts()
{
    static QHash<QString, LoginAttemptState> attempts;
    return attempts;
}

void appendAuditLog(const QString &username, const QString &action, const QString &details)
{
    const QString auditPath = QDir(core::DataPaths::appDataRoot()).filePath("audit.log");
    QFile logFile(auditPath);
    if (!logFile.open(QIODevice::WriteOnly | QIODevice::Append | QIODevice::Text)) {
        return;
    }

    QTextStream stream(&logFile);
    stream << QDateTime::currentDateTimeUtc().toString(Qt::ISODate)
           << " | user=" << username
           << " | action=" << action
           << " | details=" << details << "\n";
}

void writeActivityLog(const QString &username, const QString &action, const QString &details, bool isWebSearch = false)
{
    QSqlDatabase db = data::DatabaseManager::database();
    if (!db.isOpen()) {
        return;
    }

    QSqlQuery q(db);
    q.prepare(
        "INSERT INTO activity_log (id, ts, username, action, details, is_web_search) "
        "VALUES (:id, :ts, :username, :action, :details, :isWebSearch)");
    q.bindValue(":id", QUuid::createUuid().toString(QUuid::WithoutBraces));
    q.bindValue(":ts", QDateTime::currentDateTimeUtc().toString(Qt::ISODate));
    q.bindValue(":username", username);
    q.bindValue(":action", action);
    q.bindValue(":details", details);
    q.bindValue(":isWebSearch", isWebSearch ? 1 : 0);
    q.exec();
}

} // namespace

class AppController::Impl {
public:
    services::FileMediaService fileMediaService;
    services::JournalService journalService;
    services::SettingsService settingsService;
};

AppController::AppController(QObject *parent)
    : QObject(parent)
    , m_impl(std::make_unique<Impl>())
{
}

AppController::~AppController() = default;

QString AppController::lastError() const
{
    return m_lastError;
}

bool AppController::authenticated() const
{
    return m_authenticated;
}

QString AppController::username() const
{
    return m_username;
}

QString AppController::role() const
{
    return m_role;
}

QString AppController::email() const
{
    return m_email;
}

QString AppController::phone() const
{
    return m_phone;
}

QString AppController::profilePicture() const
{
    return m_profilePicture;
}

QString AppController::pronouns() const
{
    return m_pronouns;
}

bool AppController::login(const QString &usernameValue, const QString &password)
{
    m_lastError.clear();
    emit lastErrorChanged();

    const QString normalizedUsername = usernameValue.trimmed();
    auto &state = loginAttempts()[normalizedUsername.toLower()];
    const QDateTime now = QDateTime::currentDateTimeUtc();
    if (state.blockedUntil.isValid() && now < state.blockedUntil) {
        m_lastError = "Too many failed attempts. Try again shortly.";
        emit lastErrorChanged();
        appendAuditLog(normalizedUsername, "login_blocked", "throttle window active");
        writeActivityLog(normalizedUsername, "login_blocked", "user: " + normalizedUsername);
        emit loginFailed(m_lastError);
        return false;
    }

    if (normalizedUsername.isEmpty() || password.isEmpty()) {
        m_lastError = "Username and password are required.";
        emit lastErrorChanged();
        appendAuditLog(normalizedUsername, "login_failed", "missing username or password");
        writeActivityLog(normalizedUsername, "login_failed", "missing credentials");
        emit loginFailed("Username and password are required.");
        return false;
    }

    const auto userRecord = data::UserRepository::authenticate(normalizedUsername, password);
    if (!userRecord.has_value()) {
        state.failures += 1;
        if (state.failures >= 5) {
            state.blockedUntil = now.addSecs(120);
            state.failures = 0;
        }
        m_lastError = "Invalid credentials.";
        emit lastErrorChanged();
        appendAuditLog(normalizedUsername, "login_failed", "invalid credentials");
        writeActivityLog(normalizedUsername, "login_failed", "invalid credentials for: " + normalizedUsername);
        emit loginFailed("Invalid credentials.");
        return false;
    }

    state.failures = 0;
    state.blockedUntil = QDateTime();

    m_userId = userRecord->id;
    m_username = userRecord->username;
    m_role = userRecord->role;
    m_email = userRecord->email;
    m_phone = userRecord->phone;
    m_profilePicture = userRecord->profilePicture;
    m_pronouns = userRecord->pronouns;

    if (!m_authenticated) {
        m_authenticated = true;
        emit authenticatedChanged();
    }
    appendAuditLog(m_username, "login_success", "authenticated");
    writeActivityLog(m_username, "login_success", "user: " + m_username);
    emit sessionChanged();
    return true;
}

void AppController::logout()
{
    const bool wasAuthenticated = m_authenticated;
    const QString loggedOutUser = m_username;

    m_authenticated = false;
    m_userId.clear();
    m_username.clear();
    m_role.clear();
    m_email.clear();
    m_phone.clear();
    m_profilePicture.clear();
    m_pronouns.clear();

    if (wasAuthenticated && !loggedOutUser.isEmpty()) {
        writeActivityLog(loggedOutUser, "logout", "user: " + loggedOutUser);
    }
    if (wasAuthenticated) {
        emit authenticatedChanged();
    }
    emit sessionChanged();
}

QVariantList AppController::listFiles(const QString &category) const
{
    if (!m_authenticated) {
        return {};
    }

    return m_impl->fileMediaService.listFiles(m_userId, category);
}

bool AppController::uploadFiles(const QString &category, const QStringList &sourcePaths)
{
    if (!m_authenticated) {
        m_lastError = "Not authenticated.";
        emit lastErrorChanged();
        return false;
    }

    QString error;
    const bool ok = m_impl->fileMediaService.uploadFiles(m_userId, m_username, category, sourcePaths, &error);
    m_lastError = ok ? QString() : error;
    emit lastErrorChanged();
    if (ok) {
        writeActivityLog(m_username, "file_upload",
            QString::number(sourcePaths.count()) + " file(s) to category: " + category);
    }
    return ok;
}

bool AppController::importDownloadedFile(const QString &category, const QString &filePath)
{
    if (!m_authenticated) {
        m_lastError = "Not authenticated.";
        emit lastErrorChanged();
        return false;
    }

    QString error;
    const bool ok = m_impl->fileMediaService.uploadFilesAndRemoveSource(
        m_userId, m_username, category, { filePath }, &error);
    m_lastError = ok ? QString() : error;
    emit lastErrorChanged();
    writeActivityLog(m_username, ok ? "import_download_saved" : "import_download_failed",
        "file: " + QFileInfo(filePath).fileName() + ", category: " + category);
    return ok;
}

bool AppController::importFromUrl(const QString &category, const QString &url)
{
    if (!m_authenticated) {
        m_lastError = "Not authenticated.";
        emit lastErrorChanged();
        return false;
    }

    QString error;
    const bool ok = m_impl->fileMediaService.importFromUrl(m_userId, m_username, category, url, &error);
    m_lastError = ok ? QString() : error;
    emit lastErrorChanged();
    writeActivityLog(m_username, ok ? "import_url_saved" : "import_url_failed",
        "url: " + url + ", category: " + category);
    return ok;
}

bool AppController::renameFile(const QString &category, const QString &oldName, const QString &newName)
{
    if (!m_authenticated) {
        m_lastError = "Not authenticated.";
        emit lastErrorChanged();
        return false;
    }

    QString error;
    const bool ok = m_impl->fileMediaService.renameFile(m_userId, m_username, category, oldName, newName, &error);
    m_lastError = ok ? QString() : error;
    emit lastErrorChanged();
    if (ok) {
        writeActivityLog(m_username, "file_rename",
            category + ": " + oldName + " to " + newName);
    }
    return ok;
}

bool AppController::moveFile(const QString &fromCategory, const QString &toCategory, const QString &filename)
{
    if (!m_authenticated) {
        m_lastError = "Not authenticated.";
        emit lastErrorChanged();
        return false;
    }

    QString error;
    const bool ok = m_impl->fileMediaService.moveFile(
        m_userId, m_username, fromCategory, toCategory, filename, &error);
    m_lastError = ok ? QString() : error;
    emit lastErrorChanged();
    if (ok) {
        writeActivityLog(m_username, "file_move",
            fromCategory + "/" + filename + " to " + toCategory);
    }
    return ok;
}

bool AppController::deleteFile(const QString &category, const QString &filename)
{
    if (!m_authenticated) {
        m_lastError = "Not authenticated.";
        emit lastErrorChanged();
        return false;
    }

    QString error;
    const bool ok = m_impl->fileMediaService.deleteFile(m_userId, m_username, category, filename, &error);
    m_lastError = ok ? QString() : error;
    emit lastErrorChanged();
    if (ok) {
        writeActivityLog(m_username, "file_delete", category + "/" + filename);
    }
    return ok;
}

bool AppController::setFileDescription(const QString &category, const QString &filename, const QString &description)
{
    if (!m_authenticated) {
        m_lastError = "Not authenticated.";
        emit lastErrorChanged();
        return false;
    }

    QString error;
    const bool ok = m_impl->fileMediaService.setDescription(m_userId, category, filename, description, &error);
    m_lastError = ok ? QString() : error;
    emit lastErrorChanged();
    return ok;
}

bool AppController::openFile(const QString &filePath)
{
    if (!m_authenticated) {
        m_lastError = "Not authenticated.";
        emit lastErrorChanged();
        return false;
    }

    const QFileInfo fileInfo(filePath);
    if (!fileInfo.exists() || !fileInfo.isFile()) {
        m_lastError = "File does not exist.";
        emit lastErrorChanged();
        return false;
    }

    const QString canonicalFile = fileInfo.canonicalFilePath();
    const QString resolvedFilePath = canonicalFile.isEmpty() ? fileInfo.absoluteFilePath() : canonicalFile;
    const QString userRootPath = QDir(core::DataPaths::usersRoot()).filePath(m_username);
    const QFileInfo userRootInfo(userRootPath);
    const QString canonicalRoot = userRootInfo.canonicalFilePath();

    const QString rootForCheck = canonicalRoot.isEmpty() ? QDir(userRootPath).absolutePath() : canonicalRoot;
    const QString normalizedRoot = QDir::cleanPath(rootForCheck);
    const QString normalizedFile = QDir::cleanPath(resolvedFilePath);

    const QDir rootDir(normalizedRoot);
    const QString relative = QDir::cleanPath(rootDir.relativeFilePath(normalizedFile));
    const bool inAllowedRoot =
        !relative.isEmpty() &&
        relative != ".." &&
        !relative.startsWith("../") &&
        !QDir::isAbsolutePath(relative);

    if (!inAllowedRoot) {
        m_lastError = "Access denied for selected file path.";
        emit lastErrorChanged();
        return false;
    }

    const bool opened = QDesktopServices::openUrl(QUrl::fromLocalFile(normalizedFile));
    m_lastError = opened ? QString() : "Failed to open file with system handler.";
    emit lastErrorChanged();
    return opened;
}

bool AppController::deleteFiles(const QString &category, const QStringList &filenames)
{
    if (!m_authenticated) {
        m_lastError = "Not authenticated.";
        emit lastErrorChanged();
        return false;
    }

    for (const QString &name : filenames) {
        QString error;
        const bool ok = m_impl->fileMediaService.deleteFile(m_userId, m_username, category, name, &error);
        if (!ok) {
            m_lastError = error;
            emit lastErrorChanged();
            return false;
        }
    }

    writeActivityLog(m_username, "file_delete_bulk",
        QString::number(filenames.count()) + " file(s) from category: " + category);
    m_lastError.clear();
    emit lastErrorChanged();
    return true;
}

bool AppController::moveFiles(const QString &fromCategory, const QString &toCategory, const QStringList &filenames)
{
    if (!m_authenticated) {
        m_lastError = "Not authenticated.";
        emit lastErrorChanged();
        return false;
    }

    for (const QString &name : filenames) {
        QString error;
        const bool ok = m_impl->fileMediaService.moveFile(
            m_userId, m_username, fromCategory, toCategory, name, &error);
        if (!ok) {
            m_lastError = error;
            emit lastErrorChanged();
            return false;
        }
    }

    writeActivityLog(m_username, "file_move_bulk",
        QString::number(filenames.count()) + " file(s): " + fromCategory + " to " + toCategory);
    m_lastError.clear();
    emit lastErrorChanged();
    return true;
}

QVariantList AppController::listJournal() const
{
    if (!m_authenticated) {
        return {};
    }

    return m_impl->journalService.listEntries(m_userId);
}

QString AppController::saveJournal(const QString &entryId, const QString &title, const QString &body)
{
    if (!m_authenticated) {
        m_lastError = "Not authenticated.";
        emit lastErrorChanged();
        return QString();
    }

    QString error;
    const QString resultId = m_impl->journalService.saveEntry(m_userId, entryId, title, body, &error);
    m_lastError = resultId.isEmpty() ? error : QString();
    emit lastErrorChanged();
    if (!resultId.isEmpty()) {
        writeActivityLog(m_username, "journal_save",
            "entry: " + resultId + (title.isEmpty() ? QString() : ", title: " + title.left(50)));
    }
    return resultId;
}

bool AppController::deleteJournal(const QString &entryId)
{
    if (!m_authenticated) {
        m_lastError = "Not authenticated.";
        emit lastErrorChanged();
        return false;
    }

    QString error;
    const bool ok = m_impl->journalService.deleteEntry(m_userId, entryId, &error);
    m_lastError = ok ? QString() : error;
    emit lastErrorChanged();
    if (ok) {
        writeActivityLog(m_username, "journal_delete", "entry: " + entryId);
    }
    return ok;
}

bool AppController::deleteJournalEntries(const QStringList &entryIds)
{
    if (!m_authenticated) {
        m_lastError = "Not authenticated.";
        emit lastErrorChanged();
        return false;
    }

    for (const QString &entryId : entryIds) {
        QString error;
        const bool ok = m_impl->journalService.deleteEntry(m_userId, entryId, &error);
        if (!ok) {
            m_lastError = error;
            emit lastErrorChanged();
            return false;
        }
    }

    writeActivityLog(m_username, "journal_delete_bulk",
        QString::number(entryIds.count()) + " journal entries");
    m_lastError.clear();
    emit lastErrorChanged();
    return true;
}

QVariantMap AppController::getSettings() const
{
    if (!m_authenticated) {
        return {};
    }

    return m_impl->settingsService.getSettings(m_userId);
}

bool AppController::setSetting(const QString &key, const QString &valueJson)
{
    if (!m_authenticated) {
        m_lastError = "Not authenticated.";
        emit lastErrorChanged();
        return false;
    }

    QString error;
    const bool ok = m_impl->settingsService.setSetting(m_userId, key, valueJson, &error);
    m_lastError = ok ? QString() : error;
    emit lastErrorChanged();
    return ok;
}

QVariantList AppController::listUsers() const
{
    if (!m_authenticated || m_role != "sysop") {
        return {};
    }

    return data::UserRepository::listUsers();
}

bool AppController::createUser(const QString &username, const QString &password, const QString &role,
                               const QString &email, const QString &phone,
                               const QString &profilePicture, const QString &pronouns)
{
    if (!m_authenticated || m_role != "sysop") {
        m_lastError = "Unauthorized.";
        emit lastErrorChanged();
        return false;
    }

    QString error;
    const bool ok = data::UserRepository::createUser(
        username, password, role, email, phone, profilePicture, pronouns, &error);
    m_lastError = ok ? QString() : error;
    emit lastErrorChanged();
    appendAuditLog(m_username, ok ? "admin_create_user" : "admin_create_user_failed", username);
    writeActivityLog(m_username, ok ? "admin_create_user" : "admin_create_user_failed",
        "username: " + username + ", role: " + role);
    return ok;
}

bool AppController::updateMyProfile(const QString &email, const QString &phone,
                                    const QString &profilePicture, const QString &pronouns)
{
    if (!m_authenticated) {
        m_lastError = "Not authenticated.";
        emit lastErrorChanged();
        return false;
    }

    QString error;
    const bool ok = data::UserRepository::updateUserProfile(
        m_userId, email, phone, profilePicture, pronouns, &error);
    m_lastError = ok ? QString() : error;
    emit lastErrorChanged();
    if (ok) {
        m_email = email.trimmed();
        m_phone = phone.trimmed();
        m_profilePicture = profilePicture.trimmed();
        m_pronouns = pronouns.trimmed();
        emit sessionChanged();
    }
    appendAuditLog(m_username, ok ? "user_update_profile" : "user_update_profile_failed", m_userId);
    writeActivityLog(m_username, ok ? "profile_update" : "profile_update_failed", "user: " + m_username);
    return ok;
}

bool AppController::changeMyPassword(const QString &oldPassword, const QString &newPassword)
{
    if (!m_authenticated) {
        m_lastError = "Not authenticated.";
        emit lastErrorChanged();
        return false;
    }

    QString error;
    const bool ok = data::UserRepository::changePassword(m_userId, oldPassword, newPassword, &error);
    m_lastError = ok ? QString() : error;
    emit lastErrorChanged();
    appendAuditLog(m_username, ok ? "user_change_password" : "user_change_password_failed", m_userId);
    writeActivityLog(m_username, ok ? "password_change" : "password_change_failed", "user: " + m_username);
    return ok;
}

bool AppController::updateUserProfile(const QString &userId, const QString &email, const QString &phone,
                                      const QString &profilePicture, const QString &pronouns)
{
    if (!m_authenticated || m_role != "sysop") {
        m_lastError = "Unauthorized.";
        emit lastErrorChanged();
        return false;
    }

    QString error;
    const bool ok = data::UserRepository::updateUserProfile(userId, email, phone, profilePicture, pronouns, &error);
    m_lastError = ok ? QString() : error;
    emit lastErrorChanged();
    if (ok && userId.trimmed() == m_userId) {
        m_email = email.trimmed();
        m_phone = phone.trimmed();
        m_profilePicture = profilePicture.trimmed();
        m_pronouns = pronouns.trimmed();
        emit sessionChanged();
    }
    appendAuditLog(m_username, ok ? "admin_update_user_profile" : "admin_update_user_profile_failed", userId);
    writeActivityLog(m_username, ok ? "admin_update_user_profile" : "admin_update_user_profile_failed",
        "userId: " + userId);
    return ok;
}

bool AppController::deleteUser(const QString &userId)
{
    if (!m_authenticated || m_role != "sysop") {
        m_lastError = "Unauthorized.";
        emit lastErrorChanged();
        return false;
    }
    if (userId == m_userId) {
        m_lastError = "Cannot delete current signed-in user.";
        emit lastErrorChanged();
        return false;
    }

    QString error;
    const bool ok = data::UserRepository::deleteUser(userId, &error);
    m_lastError = ok ? QString() : error;
    emit lastErrorChanged();
    appendAuditLog(m_username, ok ? "admin_delete_user" : "admin_delete_user_failed", userId);
    writeActivityLog(m_username, ok ? "admin_delete_user" : "admin_delete_user_failed",
        "userId: " + userId);
    return ok;
}

bool AppController::deleteUsers(const QStringList &userIds)
{
    if (!m_authenticated || m_role != "sysop") {
        m_lastError = "Unauthorized.";
        emit lastErrorChanged();
        return false;
    }

    for (const QString &userId : userIds) {
        if (userId == m_userId) {
            m_lastError = "Cannot delete current signed-in user.";
            emit lastErrorChanged();
            return false;
        }

        QString error;
        const bool ok = data::UserRepository::deleteUser(userId, &error);
        if (!ok) {
            m_lastError = error;
            emit lastErrorChanged();
            appendAuditLog(m_username, "admin_delete_user_failed", userId);
            writeActivityLog(m_username, "admin_delete_user_failed", "userId: " + userId);
            return false;
        }
        appendAuditLog(m_username, "admin_delete_user", userId);
        writeActivityLog(m_username, "admin_delete_user", "userId: " + userId);
    }

    m_lastError.clear();
    emit lastErrorChanged();
    return true;
}

bool AppController::resetUserPassword(const QString &userId, const QString &newPassword)
{
    if (!m_authenticated || m_role != "sysop") {
        m_lastError = "Unauthorized.";
        emit lastErrorChanged();
        return false;
    }

    QString error;
    const bool ok = data::UserRepository::resetPassword(userId, newPassword, &error);
    m_lastError = ok ? QString() : error;
    emit lastErrorChanged();
    appendAuditLog(m_username, ok ? "admin_reset_password" : "admin_reset_password_failed", userId);
    writeActivityLog(m_username, ok ? "admin_reset_password" : "admin_reset_password_failed",
        "userId: " + userId);
    return ok;
}

QVariantList AppController::listAllFiles() const
{
    if (!m_authenticated || m_role != "sysop") {
        return {};
    }

    return m_impl->fileMediaService.listAllFiles();
}

QVariantList AppController::listAdminFilesForUser(const QString &userId) const
{
    if (!m_authenticated || m_role != "sysop") {
        return {};
    }

    return m_impl->fileMediaService.listFilesForUser(userId);
}

bool AppController::deleteAdminFiles(const QVariantList &files)
{
    if (!m_authenticated || m_role != "sysop") {
        m_lastError = "Unauthorized.";
        emit lastErrorChanged();
        return false;
    }

    for (const QVariant &value : files) {
        const QVariantMap item = value.toMap();
        const QString userId = item.value("userId").toString();
        const QString category = item.value("category").toString();
        const QString filename = item.value("filename").toString();
        const QString filePath = item.value("filePath").toString();

        QString error;
        const bool ok = m_impl->fileMediaService.deleteFileAdmin(userId, category, filename, filePath, &error);
        if (!ok) {
            m_lastError = error;
            emit lastErrorChanged();
            appendAuditLog(m_username, "admin_delete_file_failed", userId + ":" + category + ":" + filename);
            writeActivityLog(m_username, "admin_delete_file_failed",
                "userId: " + userId + ", file: " + category + "/" + filename);
            return false;
        }

        appendAuditLog(m_username, "admin_delete_file", userId + ":" + category + ":" + filename);
        writeActivityLog(m_username, "admin_delete_file",
            "userId: " + userId + ", file: " + category + "/" + filename);
    }

    m_lastError.clear();
    emit lastErrorChanged();
    return true;
}

bool AppController::moveAdminFiles(const QVariantList &files,
                                   const QString &destinationUserId,
                                   const QString &destinationCategory)
{
    if (!m_authenticated || m_role != "sysop") {
        m_lastError = "Unauthorized.";
        emit lastErrorChanged();
        return false;
    }

    const QString normalizedDestinationUserId = destinationUserId.trimmed();
    const QString normalizedDestinationCategory = destinationCategory.trimmed();
    if (normalizedDestinationUserId.isEmpty() || normalizedDestinationCategory.isEmpty()) {
        m_lastError = "Destination user and category are required.";
        emit lastErrorChanged();
        return false;
    }

    const auto destinationUser = data::UserRepository::findUserById(normalizedDestinationUserId);
    if (!destinationUser.has_value()) {
        m_lastError = "Destination user was not found.";
        emit lastErrorChanged();
        return false;
    }

    QHash<QString, QString> sourceUsernames;

    for (const QVariant &value : files) {
        const QVariantMap item = value.toMap();
        const QString sourceUserId = item.value("userId").toString().trimmed();
        const QString fromCategory = item.value("category").toString().trimmed();
        const QString filename = item.value("filename").toString().trimmed();

        if (sourceUserId.isEmpty() || fromCategory.isEmpty() || filename.isEmpty()) {
            m_lastError = "Invalid selected file entry.";
            emit lastErrorChanged();
            return false;
        }

        QString sourceUsername = sourceUsernames.value(sourceUserId);
        if (sourceUsername.isEmpty()) {
            const auto sourceUser = data::UserRepository::findUserById(sourceUserId);
            if (!sourceUser.has_value()) {
                m_lastError = "Source user for selected file was not found.";
                emit lastErrorChanged();
                return false;
            }
            sourceUsername = sourceUser->username;
            sourceUsernames.insert(sourceUserId, sourceUsername);
        }

        QString error;
        const bool ok = m_impl->fileMediaService.moveFileAdmin(
            sourceUserId,
            sourceUsername,
            fromCategory,
            filename,
            destinationUser->id,
            destinationUser->username,
            normalizedDestinationCategory,
            &error);

        if (!ok) {
            m_lastError = error;
            emit lastErrorChanged();
            appendAuditLog(
                m_username,
                "admin_move_file_failed",
                sourceUserId + ":" + fromCategory + ":" + filename + " -> " + destinationUser->id + ":" + normalizedDestinationCategory);
            writeActivityLog(m_username, "admin_move_file_failed",
                "from userId:" + sourceUserId + " " + fromCategory + "/" + filename
                + " to userId:" + destinationUser->id + " " + normalizedDestinationCategory);
            return false;
        }

        appendAuditLog(
            m_username,
            "admin_move_file",
            sourceUserId + ":" + fromCategory + ":" + filename + " -> " + destinationUser->id + ":" + normalizedDestinationCategory);
        writeActivityLog(m_username, "admin_move_file",
            "from userId:" + sourceUserId + " " + fromCategory + "/" + filename
            + " to userId:" + destinationUser->id + " " + normalizedDestinationCategory);
    }

    m_lastError.clear();
    emit lastErrorChanged();
    return true;
}

QString AppController::ensureCaptureOutputDir(const QString &preferredDir)
{
    auto normalize = [](QString value) {
        value = value.trimmed();
        if (value.startsWith('"') && value.endsWith('"') && value.size() >= 2) {
            value = value.mid(1, value.size() - 2);
        }
        value = QDir::fromNativeSeparators(value);
        return QDir::cleanPath(value);
    };

    auto isWritableDirectory = [](const QString &path) {
        QFileInfo info(path);
        if (!info.exists() || !info.isDir()) {
            return false;
        }

        const QString probeName = QString(".capture-write-probe-%1.tmp")
                                      .arg(QDateTime::currentMSecsSinceEpoch());
        const QString probePath = QDir(path).filePath(probeName);
        QFile probe(probePath);
        if (!probe.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
            return false;
        }
        probe.close();
        probe.remove();
        return true;
    };

    QStringList candidates;

    const QString preferred = normalize(preferredDir);
    if (!preferred.isEmpty() && QDir::isAbsolutePath(preferred)) {
        candidates.push_back(preferred);
    }

    const QString picturesDir = normalize(QStandardPaths::writableLocation(QStandardPaths::PicturesLocation));
    if (!picturesDir.isEmpty() && !candidates.contains(picturesDir)) {
        candidates.push_back(picturesDir);
    }

    const QString appCaptures = normalize(QDir(core::DataPaths::appDataRoot()).filePath("captures"));
    if (!appCaptures.isEmpty() && !candidates.contains(appCaptures)) {
        candidates.push_back(appCaptures);
    }

    const QString publicPictures = normalize("C:/Users/Public/Pictures");
    if (!candidates.contains(publicPictures)) {
        candidates.push_back(publicPictures);
    }

    for (const QString &candidate : candidates) {
        QDir dir;
        if (!dir.mkpath(candidate)) {
            continue;
        }
        if (isWritableDirectory(candidate)) {
            m_lastError.clear();
            emit lastErrorChanged();
            return candidate;
        }
    }

    m_lastError = "Unable to find a writable capture output folder.";
    emit lastErrorChanged();
    return QString();
}

void AppController::logActivity(const QString &action, const QString &details)
{
    if (!m_authenticated) {
        return;
    }

    writeActivityLog(m_username, action, details, false);
}

void AppController::logWebSearch(const QString &url)
{
    if (!m_authenticated) {
        return;
    }

    writeActivityLog(m_username, "web_browse", url, true);
}

QVariantList AppController::getActivityLog() const
{
    if (!m_authenticated || m_role != "sysop") {
        return {};
    }

    QSqlDatabase db = data::DatabaseManager::database();
    if (!db.isOpen()) {
        return {};
    }

    QSqlQuery q(db);
    if (!q.exec("SELECT id, ts, username, action, details, is_web_search FROM activity_log ORDER BY ts DESC LIMIT 500")) {
        return {};
    }

    QVariantList result;
    while (q.next()) {
        QVariantMap entry;
        entry["id"]          = q.value(0).toString();
        entry["ts"]          = q.value(1).toString();
        entry["username"]    = q.value(2).toString();
        entry["action"]      = q.value(3).toString();
        entry["details"]     = q.value(4).toString();
        entry["isWebSearch"] = q.value(5).toInt() != 0;
        result.append(entry);
    }
    return result;
}

bool AppController::clearActivityLog()
{
    if (!m_authenticated || m_role != "sysop") {
        m_lastError = "Unauthorized.";
        emit lastErrorChanged();
        return false;
    }

    QSqlDatabase db = data::DatabaseManager::database();
    if (!db.isOpen()) {
        m_lastError = "Database not available.";
        emit lastErrorChanged();
        return false;
    }

    QSqlQuery q(db);
    const bool ok = q.exec("DELETE FROM activity_log");
    m_lastError = ok ? QString() : q.lastError().text();
    emit lastErrorChanged();
    return ok;
}
