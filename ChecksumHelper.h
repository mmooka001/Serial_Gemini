#ifndef CHECKSUMHELPER_H
#define CHECKSUMHELPER_H

#include <QObject>
#include <QByteArray>
#include "PayloadCodec.h"

class ChecksumHelper : public QObject
{
    Q_OBJECT
public:
    explicit ChecksumHelper(QObject *parent = nullptr) : QObject(parent) {}

    enum ChecksumType {
        None = 0,
        BCC,    // XOR
        Sum8,   // Add 8-bit
        CRC16_Modbus
    };
    Q_ENUM(ChecksumType)

    Q_INVOKABLE static QByteArray calculate(const QByteArray &data, ChecksumType type) {
        switch (type) {
            case BCC: return calculateBCC(data);
            case Sum8: return calculateSum8(data);
            case CRC16_Modbus: return calculateCRC16(data);
            default: return QByteArray();
        }
    }

    Q_INVOKABLE static QString hexChecksumPreview(const QString &data, bool isHex, int type,
                                                 const QString &encoding = QStringLiteral("UTF-8")) {
        const auto parsed = isHex ? PayloadCodec::parseHex(data, encoding) : PayloadCodec::HexInput();
        if (isHex && !parsed.valid()) return "";
        const QByteArray bytes = isHex ? parsed.bytes : PayloadCodec::encodeText(data, encoding);
        if (bytes.isEmpty()) return "";
        QByteArray result = calculate(bytes, (ChecksumType)type);
        return result.toHex(' ').toUpper();
    }

private:
    static QByteArray calculateBCC(const QByteArray &data) {
        char bcc = 0;
        for (char b : data) bcc ^= b;
        return QByteArray(1, bcc);
    }

    static QByteArray calculateSum8(const QByteArray &data) {
        unsigned char sum = 0;
        for (unsigned char b : data) sum += b;
        return QByteArray(1, (char)sum);
    }

    static QByteArray calculateCRC16(const QByteArray &data) {
        unsigned short crc = 0xFFFF;
        for (int i = 0; i < data.size(); ++i) {
            crc ^= (unsigned char)data.at(i);
            for (int j = 0; j < 8; ++j) {
                if (crc & 0x0001) crc = (crc >> 1) ^ 0xA001;
                else crc >>= 1;
            }
        }
        QByteArray result;
        result.append(crc & 0xFF);
        result.append((crc >> 8) & 0xFF);
        return result;
    }
};

#endif // CHECKSUMHELPER_H
