#include "SerialManager.h"
#include "ChecksumHelper.h"

SerialManager::SerialManager(QObject *parent)
    : QObject(parent), m_serialPort(new QSerialPort(this))
{
    connect(m_serialPort, &QSerialPort::readyRead, this, &SerialManager::readData);
    connect(m_serialPort, &QSerialPort::bytesWritten, this, &SerialManager::handleBytesWritten);
    connect(m_serialPort, &QSerialPort::errorOccurred, this, [this](QSerialPort::SerialPortError error) {
        if (error == QSerialPort::NoError || error == QSerialPort::TimeoutError || !m_serialPort->isOpen()) return;
        emit errorOccurred(m_serialPort->errorString());
        if (error == QSerialPort::ResourceError || error == QSerialPort::WriteError || error == QSerialPort::ReadError)
            closePort();
    });
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
    m_rxDecoder.reset(m_dataEncoding);
    m_pendingWrites.clear();
    m_writeInFlight = 0;
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
    m_rxDecoder.reset(m_dataEncoding);
    m_pendingWrites.clear();
    m_writeInFlight = 0;
    if (m_serialPort->isOpen()) {
        m_serialPort->close();
        emit isOpenChanged();
    }
}

void SerialManager::sendData(const QString &data, bool isHex)
{
    sendDataWithChecksum(data, isHex, 0);
}

void SerialManager::sendDataWithChecksum(const QString &data, bool isHex, int checksumType)
{
    if (!m_serialPort->isOpen()) {
        emit errorOccurred("Serial port is not open!");
        return;
    }

    const QByteArray payload = PayloadCodec::decode(data, isHex, m_dataEncoding);
    const QByteArray checksum = ChecksumHelper::calculate(payload, static_cast<ChecksumHelper::ChecksumType>(checksumType));
    const QByteArray bytes = PayloadCodec::frame(payload, isHex, m_lineEndingMode, checksum);

    if (bytes.isEmpty()) return;
    m_pendingWrites.enqueue({bytes, 0, isHex, m_dataEncoding});
    writeNextChunk();
}

void SerialManager::writeNextChunk()
{
    if (!m_serialPort->isOpen() || m_writeInFlight || m_pendingWrites.isEmpty()) return;
    const auto &frame = m_pendingWrites.head();
    // 限制每次交给驱动的数据量，并由 bytesWritten 推进，避免大包超过驱动缓冲。
    const QByteArray chunk = frame.bytes.mid(frame.written, qMin<qint64>(4096, frame.bytes.size() - frame.written));
    const qint64 accepted = m_serialPort->write(chunk);
    if (accepted <= 0) {
        m_pendingWrites.clear();
        emit errorOccurred("串口发送失败：" + m_serialPort->errorString());
        return;
    }
    m_writeInFlight = accepted;
}

void SerialManager::handleBytesWritten(qint64 count)
{
    if (m_pendingWrites.isEmpty() || m_writeInFlight <= 0) return;
    const qint64 completed = qMin(count, m_writeInFlight);
    m_pendingWrites.head().written += completed;
    m_writeInFlight -= completed;
    if (m_pendingWrites.head().written == m_pendingWrites.head().bytes.size()) {
        const auto frame = m_pendingWrites.dequeue();
        emit dataReceived(PayloadCodec::decodeText(frame.bytes, frame.encoding),
                          frame.bytes.toHex(' ').toUpper(), true, frame.isHex);
    }
    writeNextChunk();
}

void SerialManager::readData()
{
    const QByteArray data = m_serialPort->readAll();
    if (data.isEmpty()) return;

    emit dataReceived(m_rxDecoder.decode(data), data.toHex(' ').toUpper(), false);
}

void SerialManager::copyToClipboard(const QString &text)
{
    QClipboard *clipboard = QGuiApplication::clipboard();
    if (clipboard) {
        clipboard->setText(text);
    }
}
