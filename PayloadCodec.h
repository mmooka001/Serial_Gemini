#ifndef PAYLOADCODEC_H
#define PAYLOADCODEC_H

#include <QByteArray>
#include <QRegularExpression>
#include <QString>
#include <QStringConverter>
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

inline QByteArray decode(const QString &text, bool hex, const QString &encoding = QStringLiteral("UTF-8")) {
    return hex && isHex(text) ? QByteArray::fromHex(compactHex(text).toLatin1()) : encodeText(text, encoding);
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
