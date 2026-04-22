#ifndef SERIALMANAGER_H
#define SERIALMANAGER_H

#include <QObject>
#include <QSerialPort>
#include <QSerialPortInfo>
#include <QVariantList>

class SerialManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool isOpen READ isOpen NOTIFY isOpenChanged)
    Q_PROPERTY(QString currentPort READ currentPort NOTIFY currentPortChanged)
    Q_PROPERTY(int baudRate READ baudRate WRITE setBaudRate NOTIFY baudRateChanged)

public:
    explicit SerialManager(QObject *parent = nullptr);
    ~SerialManager();

    bool isOpen() const { return m_serialPort->isOpen(); }
    QString currentPort() const { return m_serialPort->portName(); }
    int baudRate() const { return m_serialPort->baudRate(); }
    void setBaudRate(int baud) {
        if (m_serialPort->setBaudRate(baud)) emit baudRateChanged();
    }

    Q_INVOKABLE QVariantList availablePorts();
    Q_INVOKABLE bool openPort(const QString &portName, int baudRate);
    Q_INVOKABLE void closePort();
    Q_INVOKABLE void sendData(const QString &data, bool isHex);
    Q_INVOKABLE void sendDataWithChecksum(const QString &data, bool isHex, int checksumType);

signals:
    void isOpenChanged();
    void currentPortChanged();
    void baudRateChanged();
    void dataReceived(const QString &ascii, const QString &hex, bool isSent = false);
    void errorOccurred(const QString &error);

private slots:
    void readData();

private:
    QSerialPort *m_serialPort;
};

#endif // SERIALMANAGER_H
