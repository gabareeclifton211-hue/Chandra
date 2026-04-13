#include "Security.h"

#include <QCryptographicHash>
#include <QPasswordDigestor>
#include <QRandomGenerator>
#include <QStringList>

namespace {

QString randomSaltHex(int byteCount)
{
    QByteArray salt;
    salt.resize(byteCount);
    for (int i = 0; i < byteCount; ++i) {
        salt[i] = static_cast<char>(QRandomGenerator::global()->bounded(256));
    }
    return QString::fromLatin1(salt.toHex());
}

QByteArray derivePbkdf2Sha512(const QString &password, const QByteArray &salt)
{
    constexpr int kIterations = 100000;
    constexpr int kKeyLength = 64;

    return QPasswordDigestor::deriveKeyPbkdf2(
        QCryptographicHash::Sha512,
        password.toUtf8(),
        salt,
        kIterations,
        kKeyLength);
}

} // namespace

namespace core {

QString Security::hashPassword(const QString &password)
{
    const QString saltHex = randomSaltHex(16);
    const QByteArray salt = QByteArray::fromHex(saltHex.toLatin1());
    const QByteArray hash = derivePbkdf2Sha512(password, salt).toHex();
    return saltHex + ":" + QString::fromLatin1(hash);
}

bool Security::verifyPassword(const QString &password, const QString &storedHash)
{
    const QStringList parts = storedHash.split(':');
    if (parts.size() != 2) {
        return false;
    }

    const QByteArray salt = QByteArray::fromHex(parts[0].toLatin1());
    const QByteArray expected = QByteArray::fromHex(parts[1].toLatin1());
    const QByteArray actual = derivePbkdf2Sha512(password, salt);

    if (expected.size() != actual.size()) {
        return false;
    }

    return expected == actual;
}

} // namespace core
