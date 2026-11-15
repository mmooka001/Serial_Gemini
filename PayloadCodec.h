#ifndef PAYLOADCODEC_H
#define PAYLOADCODEC_H

#include <QByteArray>
#include <QRegularExpression>
#include <QStringView>
#include <QString>
#include <QStringConverter>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonParseError>
#ifdef Q_OS_WIN
#include <QtCore/qt_windows.h>
#endif

namespace PayloadCodec {
inline QByteArray encodeText(const QString &text, const QString &encoding) {
    if (encoding == "UTF-8") return text.toUtf8();
    if (encoding == "ISO-8859-1") return text.toLatin1();
    if (encoding == "ASCII") {
        QByteArray bytes;
        bytes.reserve(text.size());
        for (QChar ch : text) bytes.append(ch.unicode() < 128 ? char(ch.unicode()) : '?');
        return bytes;
    }
#ifdef Q_OS_WIN
    const UINT codePage = encoding == "GBK" ? 936 : encoding == "GB2312" ? 20936 : 0;
    if (!codePage || text.isEmpty()) return {};
    const auto *wide = reinterpret_cast<const wchar_t *>(text.utf16());
    const int length = WideCharToMultiByte(codePage, 0, wide, int(text.size()), nullptr, 0, nullptr, nullptr);
    QByteArray bytes(length, Qt::Uninitialized);
    if (length) WideCharToMultiByte(codePage, 0, wide, int(text.size()), bytes.data(), length, nullptr, nullptr);
    return bytes;
#else
    QStringEncoder encoder(encoding);
    return encoder.isValid() ? QByteArray(encoder(text)) : QByteArray();
#endif
}

inline QString decodeText(const QByteArray &bytes, const QString &encoding) {
    if (encoding == "UTF-8") return QString::fromUtf8(bytes);
    if (encoding == "ISO-8859-1") return QString::fromLatin1(bytes);
    if (encoding == "ASCII") {
        QString text;
        text.reserve(bytes.size());
        for (unsigned char ch : bytes) text.append(ch < 128 ? QChar(ch) : QChar::ReplacementCharacter);
        return text;
    }
#ifdef Q_OS_WIN
    const UINT codePage = encoding == "GBK" ? 936 : encoding == "GB2312" ? 20936 : 0;
    if (!codePage || bytes.isEmpty()) return {};
    const int length = MultiByteToWideChar(codePage, 0, bytes.constData(), int(bytes.size()), nullptr, 0);
    QString text(length, Qt::Uninitialized);
    if (length) MultiByteToWideChar(codePage, 0, bytes.constData(), int(bytes.size()),
                                   reinterpret_cast<wchar_t *>(text.data()), length);
    return text;
#else
    QStringDecoder decoder(encoding);
    return decoder.isValid() ? QString(decoder(bytes)) : QString();
#endif
}

class StreamDecoder {
public:
    void reset(const QString &encoding) {
        m_encoding = encoding;
        m_utf8.resetState();
        m_pending.clear();
    }

    QString decode(const QByteArray &bytes) {
        if (m_encoding == "UTF-8") return m_utf8(bytes);
        if (m_encoding != "GBK" && m_encoding != "GB2312")
            return decodeText(bytes, m_encoding);

        const QByteArray input = m_pending + bytes;
        m_pending.clear();
        int complete = input.size();
        for (int i = 0; i < input.size(); ++i) {
            const auto lead = static_cast<unsigned char>(input[i]);
            const bool isLead = m_encoding == "GBK" ? lead >= 0x81 && lead <= 0xFE
                                                     : lead >= 0xA1 && lead <= 0xF7;
            if (!isLead) continue;
            if (i + 1 == input.size()) {
                complete = i;
                m_pending = input.mid(i);
                break;
            }
            const auto trail = static_cast<unsigned char>(input[i + 1]);
            const bool isTrail = m_encoding == "GBK" ? trail >= 0x40 && trail <= 0xFE && trail != 0x7F
                                                      : trail >= 0xA1 && trail <= 0xFE;
            if (isTrail) ++i;
        }
        return decodeText(input.left(complete), m_encoding);
    }

private:
    QString m_encoding = QStringLiteral("UTF-8");
    QStringDecoder m_utf8{QStringConverter::Utf8};
    QByteArray m_pending;
};

inline QString compactHex(QString text) {
    text.remove("0x", Qt::CaseInsensitive);
    text.remove(QRegularExpression("\\s+"));
    return text;
}

inline bool isHex(const QString &text) {
    const QString compact = compactHex(text);
    static const QRegularExpression digits("^[0-9a-fA-F]+$");
    return !compact.isEmpty() && compact.size() % 2 == 0 && digits.match(compact).hasMatch();
}

struct HexInput {
    QByteArray bytes;
    QString error;
    bool containsText = false;
    bool valid() const { return error.isEmpty() && !bytes.isEmpty(); }
};

inline int hexDigit(QChar ch) {
    const auto value = ch.unicode();
    if (value >= '0' && value <= '9') return value - '0';
    const auto lower = value | 0x20;
    if (lower >= 'a' && lower <= 'f') return lower - 'a' + 10;
    return -1;
}

inline bool appendHexToken(QStringView token, QByteArray &bytes) {
    int high = -1;
    const qsizetype initialSize = bytes.size();
    for (qsizetype i = 0; i < token.size(); ++i) {
        if (token[i] == '0' && i + 1 < token.size()
                && (token[i + 1] == 'x' || token[i + 1] == 'X')) {
            ++i;
            continue;
        }
        const int digit = hexDigit(token[i]);
        if (digit < 0) return false;
        if (high < 0) {
            high = digit;
        } else {
            bytes.append(char(high * 16 + digit));
            high = -1;
        }
    }
    return high < 0 && bytes.size() > initialSize;
}

inline HexInput parseHex(const QString &text, const QString &encoding) {
    HexInput result;
    qsizetype position = 0;
    while (position < text.size()) {
        if (text[position].isSpace()) { ++position; continue; }
        const qsizetype start = position;
        if (text[position] == '"') {
            ++position;
            bool escaped = false;
            bool closed = false;
            while (position < text.size()) {
                const QChar ch = text[position++];
                if (!escaped && ch == '"') { closed = true; break; }
                if (!escaped && ch == '\\') escaped = true;
                else escaped = false;
            }
            if (!closed) {
                result.error = QStringLiteral("文字请用英文双引号成对包住，例如 01 \"AT\" 0D。");
                return result;
            }
            QJsonParseError error;
            const auto literal = QJsonDocument::fromJson(("[" + text.mid(start, position - start) + "]").toUtf8(), &error);
            if (error.error != QJsonParseError::NoError || !literal.isArray() || !literal.array().first().isString()) {
                result.error = QStringLiteral("引号内的换行或引号请使用 \\n、\\r、\\\" 等转义写法。");
                return result;
            }
            result.bytes += encodeText(literal.array().first().toString(), encoding);
            result.containsText = true;
        } else {
            while (position < text.size() && !text[position].isSpace() && text[position] != '"') ++position;
            if (!appendHexToken(QStringView(text).mid(start, position - start), result.bytes)) {
                result.error = QStringLiteral("HEX 模式只接受成对字节；文字请加英文双引号，例如 01 \"AT\" 0D。");
                return result;
            }
        }
    }
    if (result.bytes.isEmpty()) result.error = QStringLiteral("请输入至少一个字节。");
    return result;
}

inline QByteArray decode(const QString &text, bool hex, const QString &encoding = QStringLiteral("UTF-8")) {
    if (!hex) return encodeText(text, encoding);
    const auto parsed = parseHex(text, encoding);
    return parsed.valid() ? parsed.bytes : QByteArray();
}

inline QByteArray frame(QByteArray bytes, bool hex, int lineEnding, const QByteArray &checksum = {}) {
    bytes.append(checksum);
    if (!hex) {
        if (lineEnding == 1) bytes.append('\n');
        else if (lineEnding == 2) bytes.append('\r');
        else if (lineEnding == 3) bytes.append("\r\n");
    }
    return bytes;
}
}
#endif
