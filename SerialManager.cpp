#include "SerialManager.h"
#include <QDebug>
#include <QClipboard>
#include <QGuiApplication>

#ifdef Q_OS_WIN
#include <windows.h>
#include <dwmapi.h>
#endif

SerialManager::SerialManager(QObject *parent)
    : QObject(parent), m_serialPort(new QSerialPort(this)), m_isOpen(false), m_lineEndingMode(0)
{
    connect(m_serialPort, &QSerialPort::readyRead, this, &SerialManager::readData);
    connect(m_serialPort, &QSerialPort::errorOccurred, this, [this](QSerialPort::SerialPortError error) {
        if (error != QSerialPort::NoError) {
            emit errorOccurred(m_serialPort->errorString());
        }
    });
}

SerialManager::~SerialManager()
{
    if (m_serialPort->isOpen()) {
        m_serialPort->close();
    }
}

QVariantList SerialManager::availablePorts()
{
    QVariantList ports;
    const auto infos = QSerialPortInfo::availablePorts();
    for (const QSerialPortInfo &info : infos) {
        QVariantMap port;
        port["name"] = info.portName();
        port["description"] = info.description();
        port["manufacturer"] = info.manufacturer();
        port["serialNumber"] = info.serialNumber();
        port["systemLocation"] = info.systemLocation();
        ports.append(port);
    }
    return ports;
}

bool SerialManager::openPort(const QString &portName, int baudRate, int dataBits, int stopBits, int parity, int flowControl)
{
    if (m_serialPort->isOpen()) {
        m_serialPort->close();
    }

    m_serialPort->setPortName(portName);
    m_serialPort->setBaudRate(static_cast<QSerialPort::BaudRate>(baudRate));
    m_serialPort->setDataBits(static_cast<QSerialPort::DataBits>(dataBits));
    m_serialPort->setStopBits(static_cast<QSerialPort::StopBits>(stopBits));
    m_serialPort->setParity(static_cast<QSerialPort::Parity>(parity));
    m_serialPort->setFlowControl(static_cast<QSerialPort::FlowControl>(flowControl));

    if (m_serialPort->open(QIODevice::ReadWrite)) {
        m_isOpen = true;
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
        m_isOpen = false;
        emit isOpenChanged();
        emit currentPortChanged();
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

    // Append line ending based on mode (only for TXT, not HEX)
    if (!isHex) {
        if (m_lineEndingMode == 1) bytes.append("\r\n");      // CRLF
        else if (m_lineEndingMode == 2) bytes.append("\n");   // LF
        else if (m_lineEndingMode == 3) bytes.append("\r");   // CR
    }

    m_serialPort->write(bytes);
    m_serialPort->flush();

    // 同时发送两种格式（显示用原始数据，不含行尾符）
    emit dataReceived(data, bytes.toHex(' ').toUpper(), true);
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

    // Append checksum
    if (checksumType > 0) {
        QByteArray checksum = ChecksumHelper::calculate(bytes, (ChecksumHelper::ChecksumType)checksumType);
        bytes.append(checksum);
    }

    // Append line ending based on mode (only for TXT, not HEX)
    if (!isHex) {
        if (m_lineEndingMode == 1) bytes.append("\r\n");      // CRLF
        else if (m_lineEndingMode == 2) bytes.append("\n");   // LF
        else if (m_lineEndingMode == 3) bytes.append("\r");   // CR
    }

    m_serialPort->write(bytes);
    m_serialPort->flush();

    emit dataReceived(data, bytes.toHex(' ').toUpper(), true);
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
#endif
}

void SerialManager::enableDwmShadow(QQuickWindow *window)
{
    if (!window) return;

#ifdef Q_OS_WIN
    HWND hwnd = (HWND)window->winId();
    MARGINS margins = {1, 1, 1, 1};
    DwmExtendFrameIntoClientArea(hwnd, &margins);
#endif
}

void SerialManager::copyToClipboard(const QString &text)
{
    QClipboard *clipboard = QGuiApplication::clipboard();
    clipboard->setText(text);
}
