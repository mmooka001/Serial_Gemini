#include "SerialManager.h"
#include "ChecksumHelper.h"
#include <QDebug>

#ifdef Q_OS_WIN
#include <windows.h>
#endif

SerialManager::SerialManager(QObject *parent)
    : QObject(parent), m_serialPort(new QSerialPort(this))
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
        QVariantMap port;
        port["name"] = info.portName();
        port["description"] = info.description().isEmpty() ? "无描述信息" : info.description();
        port["manufacturer"] = info.manufacturer();
        ports.append(port);
    }
    return ports;
}

bool SerialManager::openPort(const QString &portName, int baudRate, int dataBits, int stopBits, int parity, int flowControl)
{
    if (m_serialPort->isOpen())
        m_serialPort->close();

    m_serialPort->setPortName(portName);
    m_serialPort->setBaudRate(baudRate);

    // Data bits
    switch (dataBits) {
        case 5: m_serialPort->setDataBits(QSerialPort::Data5); break;
        case 6: m_serialPort->setDataBits(QSerialPort::Data6); break;
        case 7: m_serialPort->setDataBits(QSerialPort::Data7); break;
        default: m_serialPort->setDataBits(QSerialPort::Data8); break;
    }

    // Parity: 0=None, 1=Odd, 2=Even, 3=Mark, 4=Space
    switch (parity) {
        case 1: m_serialPort->setParity(QSerialPort::OddParity); break;
        case 2: m_serialPort->setParity(QSerialPort::EvenParity); break;
        case 3: m_serialPort->setParity(QSerialPort::MarkParity); break;
        case 4: m_serialPort->setParity(QSerialPort::SpaceParity); break;
        default: m_serialPort->setParity(QSerialPort::NoParity); break;
    }

    // Stop bits: 1=OneStop, 2=TwoStop, 3=OneAndHalfStop
    switch (stopBits) {
        case 2: m_serialPort->setStopBits(QSerialPort::TwoStop); break;
        case 3: m_serialPort->setStopBits(QSerialPort::OneAndHalfStop); break;
        default: m_serialPort->setStopBits(QSerialPort::OneStop); break;
    }

    // Flow control: 0=None, 1=Hardware, 2=Software
    switch (flowControl) {
        case 1: m_serialPort->setFlowControl(QSerialPort::HardwareControl); break;
        case 2: m_serialPort->setFlowControl(QSerialPort::SoftwareControl); break;
        default: m_serialPort->setFlowControl(QSerialPort::NoFlowControl); break;
    }

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

    // Append line ending based on mode
    if (m_lineEndingMode == 1) bytes.append("\r\n");      // CRLF
    else if (m_lineEndingMode == 2) bytes.append("\n");   // LF
    else if (m_lineEndingMode == 3) bytes.append("\r");   // CR

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

    // Append line ending based on mode
    if (m_lineEndingMode == 1) bytes.append("\r\n");      // CRLF
    else if (m_lineEndingMode == 2) bytes.append("\n");   // LF
    else if (m_lineEndingMode == 3) bytes.append("\r");   // CR

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

void SerialManager::setStayOnTop(QQuickWindow *window, bool onTop)
{
    if (!window) return;

#ifdef Q_OS_WIN
    HWND hwnd = (HWND)window->winId();
    if (onTop) {
        SetWindowPos(hwnd, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE);
    } else {
        SetWindowPos(hwnd, HWND_NOTOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE);
    }
#else
    if (onTop) {
        window->setFlags(window->flags() | Qt::WindowStaysOnTopHint);
    } else {
        window->setFlags(window->flags() & ~Qt::WindowStaysOnTopHint);
    }
#endif
}

void SerialManager::copyToClipboard(const QString &text)
{
    QClipboard *clipboard = QGuiApplication::clipboard();
    if (clipboard) {
        clipboard->setText(text);
    }
}
