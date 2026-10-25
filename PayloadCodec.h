#ifndef PAYLOADCODEC_H
#define PAYLOADCODEC_H

#include <QByteArray>
#include <QRegularExpression>
#include <QString>

namespace PayloadCodec {
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

inline QByteArray decode(const QString &text, bool hex) {
    return hex && isHex(text) ? QByteArray::fromHex(compactHex(text).toLatin1()) : text.toUtf8();
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
