#ifndef DATAENCODER_H
#define DATAENCODER_H

#include <QObject>
#include <QByteArray>
#include <QString>

#ifdef QT_HAS_CORE5COMPAT
#include <QTextCodec>
#endif

class DataEncoder : public QObject
{
    Q_OBJECT

public:
    explicit DataEncoder(QObject *parent = nullptr) : QObject(parent) {}

    // Convert hex string ("48 65 6C 6C 6F") to readable ASCII string
    Q_INVOKABLE QString hexToString(const QString &hex) {
        QString cleanHex = hex;
        cleanHex.remove("0x", Qt::CaseInsensitive);
        cleanHex.remove(' ');
        QByteArray bytes = QByteArray::fromHex(cleanHex.toUtf8());
        return QString::fromUtf8(bytes);
    }

    // Convert ASCII string to hex representation "48 65 6C 6C 6F"
    Q_INVOKABLE QString stringToHex(const QString &str) {
        QByteArray bytes = str.toUtf8();
        return bytes.toHex(' ').toUpper();
    }

    // Format hex with spaces: "48656C6C6F" -> "48 65 6C 6C 6F"
    Q_INVOKABLE QString formatHex(const QString &hex) {
        QString clean = hex;
        clean.remove("0x", Qt::CaseInsensitive);
        clean.remove(' ');
        QByteArray bytes = QByteArray::fromHex(clean.toUtf8());
        return bytes.toHex(' ').toUpper();
    }

    // Format hex to decimal: "FF 0A" -> "255 10"
    Q_INVOKABLE QString formatDec(const QString &hex) {
        QString clean = hex;
        clean.remove("0x", Qt::CaseInsensitive);
        clean.remove(' ');
        QByteArray bytes = QByteArray::fromHex(clean.toUtf8());
        QStringList decs;
        for (char b : bytes) {
            decs.append(QString::number((unsigned char)b));
        }
        return decs.join(' ');
    }

    // Validate hex string: returns empty string if valid, error message otherwise
    Q_INVOKABLE QString validateHex(const QString &hex) {
        QString clean = hex;
        clean.remove("0x", Qt::CaseInsensitive);
        clean.remove(' ');
        if (clean.isEmpty()) return "Hex data is empty";
        if (clean.size() % 2 != 0) return "Hex data length must be even";
        for (const QChar &c : clean) {
            if (!c.isDigit() && !(c >= 'a' && c <= 'f') && !(c >= 'A' && c <= 'F'))
                return QString("Invalid hex character: '%1'").arg(c);
        }
        return "";
    }

    // Reformat hex: normalize any hex input to "48 65 6C 6C 6F" format
    Q_INVOKABLE QString reformatHex(const QString &hex) {
        QString clean = hex;
        clean.remove("0x", Qt::CaseInsensitive);
        clean.remove(' ');
        clean.remove('\n');
        clean.remove('\r');
        QByteArray bytes = QByteArray::fromHex(clean.toUtf8());
        return bytes.toHex(' ').toUpper();
    }

    // Decode bytes to string using specified encoding (UTF-8, GBK, etc.)
    Q_INVOKABLE QString decodeBytes(const QByteArray &data, const QString &encoding) {
#ifdef QT_HAS_CORE5COMPAT
        if (encoding.compare("UTF-8", Qt::CaseInsensitive) != 0) {
            QTextCodec *codec = QTextCodec::codecForName(encoding.toUtf8());
            if (codec) {
                return codec->toUnicode(data);
            }
        }
#endif
        return QString::fromUtf8(data);
    }

    // Encode string to bytes using specified encoding
    Q_INVOKABLE QByteArray encodeString(const QString &str, const QString &encoding) {
#ifdef QT_HAS_CORE5COMPAT
        if (encoding.compare("UTF-8", Qt::CaseInsensitive) != 0) {
            QTextCodec *codec = QTextCodec::codecForName(encoding.toUtf8());
            if (codec) {
                return codec->fromUnicode(str);
            }
        }
#endif
        return str.toUtf8();
    }
};

#endif // DATAENCODER_H
