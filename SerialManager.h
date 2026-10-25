#ifndef SERIALMANAGER_H
#define SERIALMANAGER_H

#include <QObject>
#include <QSerialPort>
#include <QSerialPortInfo>
#include <QVariantList>
#include <QClipboard>
#include <QGuiApplication>

#include "PayloadCodec.h"

class SerialManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool isOpen READ isOpen NOTIFY isOpenChanged)
    Q_PROPERTY(QString currentPort READ currentPort NOTIFY currentPortChanged)
    Q_PROPERTY(int baudRate READ baudRate WRITE setBaudRate NOTIFY baudRateChanged)
    Q_PROPERTY(int lineEndingMode READ lineEndingMode WRITE setLineEndingMode NOTIFY lineEndingModeChanged)

public:
    explicit SerialManager(QObject *parent = nullptr);
    ~SerialManager();

    bool isOpen() const { return m_serialPort->isOpen(); }
    QString currentPort() const { return m_serialPort->portName(); }
    int baudRate() const { return m_serialPort->baudRate(); }
    void setBaudRate(int baud) {
        if (m_serialPort->setBaudRate(baud)) emit baudRateChanged();
    }
    int lineEndingMode() const { return m_lineEndingMode; }
    void setLineEndingMode(int mode) {
        if (m_lineEndingMode != mode) {
            m_lineEndingMode = mode;
            emit lineEndingModeChanged();
        }
    }

    Q_INVOKABLE QVariantList availablePorts();
    Q_INVOKABLE bool openPort(const QString &portName, int baudRate, int dataBits = 8, int stopBits = 1, int parity = 0, int flowControl = 0);
    Q_INVOKABLE void closePort();
    Q_INVOKABLE void sendData(const QString &data, bool isHex);
    Q_INVOKABLE void sendDataWithChecksum(const QString &data, bool isHex, int checksumType);
    Q_INVOKABLE bool isHexInput(const QString &text) const { return PayloadCodec::isHex(text); }
    Q_INVOKABLE QString textToHex(const QString &text) const { return text.toUtf8().toHex(' ').toUpper(); }
    Q_INVOKABLE void copyToClipboard(const QString &text);

signals:
    void isOpenChanged();
    void currentPortChanged();
    void baudRateChanged();
    void lineEndingModeChanged();
    void dataReceived(const QString &ascii, const QString &hex, bool isSent = false, bool isHex = false);
    void errorOccurred(const QString &error);

private slots:
    void readData();

private:
    QSerialPort *m_serialPort;
    int m_lineEndingMode = 0;
};

#endif // SERIALMANAGER_H
