#include "SerialManager.h"
#include "ChecksumHelper.h"
#include <QDebug>

SerialManager::SerialManager(QObject *parent)
    : QObject(parent)
    , m_serialPort(new QSerialPort(this))
{
    connect(m_serialPort, &QSerialPort::readyRead, this, &SerialManager::readData);
}

SerialManager::~SerialManager()
{
    if (m_serialPort->isOpen())
        m_serialPort->close();
}

QVariantList SerialManager::availablePorts()
{
    QVariantList ports;
    const auto infos = QSerialPortInfo::availablePorts();
    for (const QSerialPortInfo &info : infos) {
        ports.append(info.portName());
    }
    return ports;
}

bool SerialManager::openPort(const QString &portName, int baudRate)
{
    if (m_serialPort->isOpen())
        m_serialPort->close();

    m_serialPort->setPortName(portName);
    m_serialPort->setBaudRate(baudRate);
    m_serialPort->setDataBits(QSerialPort::Data8);
    m_serialPort->setParity(QSerialPort::NoParity);
    m_serialPort->setStopBits(QSerialPort::OneStop);
    m_serialPort->setFlowControl(QSerialPort::NoFlowControl);

    if (m_serialPort->open(QIODevice::ReadWrite)) {
        emit isOpenChanged();
        emit currentPortChanged();
        return true;
    } else {
        emit errorOccurred(m_serialPort->errorString());
        return false;
    }
}

void SerialManager::closePort()
{
    if (m_serialPort->isOpen()) {
        m_serialPort->close();
        emit isOpenChanged();
    }
}

void SerialManager::sendData(const QString &data, bool isHex)
{
    if (!m_serialPort->isOpen()) {
        emit errorOccurred("Serial port is not open!");
        return;
    }

    QByteArray bytes;
    if (isHex) {
        QString cleanData = data;
        cleanData.remove("0x", Qt::CaseInsensitive);
        cleanData.remove(" ");
        bytes = QByteArray::fromHex(cleanData.toUtf8());
    } else {
        bytes = data.toUtf8();
    }

    m_serialPort->write(bytes);
    m_serialPort->flush();

    // 同时发送两种格式
    emit dataReceived(QString::fromUtf8(bytes), bytes.toHex(' ').toUpper(), true);
}

void SerialManager::sendDataWithChecksum(const QString &data, bool isHex, int checksumType)
{
    if (!m_serialPort->isOpen()) {
        emit errorOccurred("Serial port is not open!");
        return;
    }

    QByteArray bytes;
    if (isHex) {
        QString cleanData = data;
        cleanData.remove("0x", Qt::CaseInsensitive);
        cleanData.remove(" ");
        bytes = QByteArray::fromHex(cleanData.toUtf8());
    } else {
        bytes = data.toUtf8();
    }

    if (checksumType > 0) {
        QByteArray checksum = ChecksumHelper::calculate(bytes, (ChecksumHelper::ChecksumType)checksumType);
        bytes.append(checksum);
    }

    m_serialPort->write(bytes);
    m_serialPort->flush();

    emit dataReceived(QString::fromUtf8(bytes), bytes.toHex(' ').toUpper(), true);
}

void SerialManager::readData()
{
    const QByteArray data = m_serialPort->readAll();
    if (data.isEmpty()) return;

    emit dataReceived(QString::fromUtf8(data), data.toHex(' ').toUpper(), false);
}
