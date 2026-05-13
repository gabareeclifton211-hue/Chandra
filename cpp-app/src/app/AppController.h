#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>

#include <memory>

class AppController : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool authenticated READ authenticated NOTIFY authenticatedChanged)
    Q_PROPERTY(QString username READ username NOTIFY sessionChanged)
    Q_PROPERTY(QString role READ role NOTIFY sessionChanged)
    Q_PROPERTY(QString email READ email NOTIFY sessionChanged)
    Q_PROPERTY(QString phone READ phone NOTIFY sessionChanged)
    Q_PROPERTY(QString profilePicture READ profilePicture NOTIFY sessionChanged)
    Q_PROPERTY(QString pronouns READ pronouns NOTIFY sessionChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)

public:
    explicit AppController(QObject *parent = nullptr);
    ~AppController();

    bool authenticated() const;
    QString username() const;
    QString role() const;
    QString email() const;
    QString phone() const;
    QString profilePicture() const;
    QString pronouns() const;
    QString lastError() const;

    Q_INVOKABLE bool login(const QString &username, const QString &password);
    Q_INVOKABLE void logout();
    Q_INVOKABLE QVariantList listFiles(const QString &category) const;
    Q_INVOKABLE bool uploadFiles(const QString &category, const QStringList &sourcePaths);
    Q_INVOKABLE bool importDownloadedFile(const QString &category, const QString &filePath);
    Q_INVOKABLE bool importFromUrl(const QString &category, const QString &url);
    Q_INVOKABLE bool renameFile(const QString &category, const QString &oldName, const QString &newName);
    Q_INVOKABLE bool moveFile(const QString &fromCategory, const QString &toCategory, const QString &filename);
    Q_INVOKABLE bool deleteFile(const QString &category, const QString &filename);
    Q_INVOKABLE bool setFileDescription(const QString &category, const QString &filename, const QString &description);
    Q_INVOKABLE bool setFileTags(const QString &category, const QString &filename, const QString &tags);
    Q_INVOKABLE bool openFile(const QString &filePath);
    Q_INVOKABLE bool deleteFiles(const QString &category, const QStringList &filenames);
    Q_INVOKABLE bool moveFiles(const QString &fromCategory, const QString &toCategory, const QStringList &filenames);
    Q_INVOKABLE QVariantList listJournal() const;
    Q_INVOKABLE QString saveJournal(const QString &entryId, const QString &title, const QString &body);
    Q_INVOKABLE bool deleteJournal(const QString &entryId);
    Q_INVOKABLE bool deleteJournalEntries(const QStringList &entryIds);
    Q_INVOKABLE QVariantMap getSettings() const;
    Q_INVOKABLE bool setSetting(const QString &key, const QString &valueJson);
    Q_INVOKABLE QVariantList listUsers() const;
    Q_INVOKABLE bool createUser(const QString &username, const QString &password, const QString &role,
                                const QString &email, const QString &phone,
                                const QString &profilePicture, const QString &pronouns);
    Q_INVOKABLE bool updateMyProfile(const QString &email, const QString &phone,
                                     const QString &profilePicture, const QString &pronouns);
    Q_INVOKABLE bool changeMyPassword(const QString &oldPassword, const QString &newPassword);
    Q_INVOKABLE bool updateUserProfile(const QString &userId, const QString &email, const QString &phone,
                                       const QString &profilePicture, const QString &pronouns);
    Q_INVOKABLE bool deleteUser(const QString &userId);
    Q_INVOKABLE bool deleteUsers(const QStringList &userIds);
    Q_INVOKABLE bool resetUserPassword(const QString &userId, const QString &newPassword);
    Q_INVOKABLE QVariantList listAllFiles() const;
    Q_INVOKABLE QVariantList listAdminFilesForUser(const QString &userId) const;
    Q_INVOKABLE bool deleteAdminFiles(const QVariantList &files);
    Q_INVOKABLE bool moveAdminFiles(const QVariantList &files, const QString &destinationUserId,
                                    const QString &destinationCategory);
    Q_INVOKABLE QString ensureCaptureOutputDir(const QString &preferredDir);

    Q_INVOKABLE void logActivity(const QString &action, const QString &details);
    Q_INVOKABLE void logWebSearch(const QString &url);
    Q_INVOKABLE QVariantList getActivityLog() const;
    Q_INVOKABLE bool clearActivityLog();

signals:
    void authenticatedChanged();
    void sessionChanged();
    void loginFailed(const QString &reason);
    void lastErrorChanged();

private:
    bool m_authenticated = false;
    QString m_userId;
    QString m_username;
    QString m_role;
    QString m_email;
    QString m_phone;
    QString m_profilePicture;
    QString m_pronouns;
    QString m_lastError;

    class Impl;
    std::unique_ptr<Impl> m_impl;
};
