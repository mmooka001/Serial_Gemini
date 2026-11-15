#include "SerialManager.h"
#include "ChecksumHelper.h"
#include <QDateTime>
#include <utility>

SerialManager::SerialManager(QObject *parent)
    : QObject(parent), m_serialPort(new QSerialPort(this))
{
    m_serialPort->setReadBufferSize(256 * 1024);
    m_writeWatchdog.setSingleShot(true);
    connect(&m_writeWatchdog, &QTimer::timeout, this, [this] {
        const QString message = QStringLiteral("串口写入超时，已断开连接并丢弃尚未发送的数据。请检查流控和设备。");
        closePort();
        emit sendingStalled(message);
        emit errorOccurred(message);
    });
    m_receiveDeadline.setSingleShot(true);
    m_receiveDeadline.setTimerType(Qt::PreciseTimer);
    connect(&m_receiveDeadline, &QTimer::timeout, this, &SerialManager::flushReceivePacket);
    m_receiveDrain.setSingleShot(true);
    connect(&m_receiveDrain, &QTimer::timeout, this, &SerialManager::readData);
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
    closePort();
    m_rxDecoder.reset(m_dataEncoding);

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
    flushReceivePacket();
    m_receiveDrain.stop();
    m_rxDecoder.reset(m_dataEncoding);
    resetWrites();
    if (m_serialPort->isOpen()) {
        m_serialPort->close();
        emit isOpenChanged();
    }
}

void SerialManager::resetWrites()
{
    m_writeWatchdog.stop();
    m_pendingWrites.clear();
    m_writeInFlight = 0;
    m_queuedWriteBytes = 0;
}

bool SerialManager::sendData(const QString &data, bool isHex)
{
    return sendDataWithChecksum(data, isHex, 0);
}

bool SerialManager::sendDataWithChecksum(const QString &data, bool isHex, int checksumType)
{
    if (!m_serialPort->isOpen()) {
        emit errorOccurred("Serial port is not open!");
        return false;
    }

    const auto parsed = isHex ? PayloadCodec::parseHex(data, m_dataEncoding) : PayloadCodec::HexInput();
    if (isHex && !parsed.valid()) { emit errorOccurred(parsed.error); return false; }
    const QByteArray payload = isHex ? parsed.bytes : PayloadCodec::encodeText(data, m_dataEncoding);
    const QByteArray checksum = ChecksumHelper::calculate(payload, static_cast<ChecksumHelper::ChecksumType>(checksumType));
    const QByteArray bytes = PayloadCodec::frame(payload, isHex, m_lineEndingMode, checksum);

    if (bytes.isEmpty()) return false;
    constexpr qsizetype maxQueuedBytes = 1024 * 1024;
    if (bytes.size() > maxQueuedBytes - m_queuedWriteBytes || m_pendingWrites.size() >= 256) {
        const QString message = QStringLiteral("发送队列已满，当前数据未入队。请降低发送频率或检查设备流控。");
        emit sendingStalled(message);
        emit errorOccurred(message);
        return false;
    }
    m_pendingWrites.enqueue({bytes, 0, isHex, m_dataEncoding});
    m_queuedWriteBytes += bytes.size();
    return writeNextChunk();
}

bool SerialManager::writeNextChunk()
{
    if (!m_serialPort->isOpen()) return false;
    if (m_writeInFlight || m_pendingWrites.isEmpty()) return true;
    const auto &frame = m_pendingWrites.head();
    // 限制每次交给驱动的数据量，并由 bytesWritten 推进，避免大包超过驱动缓冲。
    const QByteArray chunk = frame.bytes.mid(frame.written, qMin<qint64>(4096, frame.bytes.size() - frame.written));
    const qint64 accepted = m_serialPort->write(chunk);
    if (accepted <= 0) {
        resetWrites();
        const QString message = QStringLiteral("串口发送失败：") + m_serialPort->errorString();
        emit sendingStalled(message);
        emit errorOccurred(message);
        return false;
    }
    m_writeInFlight = accepted;
    m_writeWatchdog.start(3000 + int(12000 * accepted / qMax(1, baudRate())));
    return true;
}

void SerialManager::handleBytesWritten(qint64 count)
{
    if (m_pendingWrites.isEmpty() || m_writeInFlight <= 0) return;
    const qint64 completed = qMin(count, m_writeInFlight);
    m_pendingWrites.head().written += completed;
    m_writeInFlight -= completed;
    if (m_writeInFlight > 0)
        m_writeWatchdog.start(3000 + int(12000 * m_writeInFlight / qMax(1, baudRate())));
    else
        m_writeWatchdog.stop();
    if (m_pendingWrites.head().written == m_pendingWrites.head().bytes.size()) {
        const qint64 timestampMs = QDateTime::currentMSecsSinceEpoch();
        const auto frame = m_pendingWrites.dequeue();
        m_queuedWriteBytes -= frame.bytes.size();
        emit dataReceived(PayloadCodec::decodeText(frame.bytes, frame.encoding),
                          frame.bytes.toHex(' ').toUpper(), true, frame.isHex, timestampMs, frame.encoding);
    }
    writeNextChunk();
}

void SerialManager::readData()
{
    if (m_receiveDrain.isActive()) return;
    const qint64 timestampMs = QDateTime::currentMSecsSinceEpoch();
    constexpr qint64 maxReadBytes = 64 * 1024;
    // Small fixed packets also need a per-turn limit so the UI can process input.
    const qint64 budget = m_packetMode == 1 ? qMin(maxReadBytes, qint64(m_packetBytes) * 64) : maxReadBytes;
    const auto data = m_serialPort->read(budget);
    if (!data.isEmpty()) bufferReceivedBytes(data, timestampMs);
    if (m_serialPort->bytesAvailable() > 0) m_receiveDrain.start(0);
}

void SerialManager::bufferReceivedBytes(const QByteArray &bytes, qint64 timestamp)
{
    if (m_packetMilliseconds == 0) {
        emitReceivePacket(bytes, timestamp);
        return;
    }

    const qsizetype packetSize = m_packetMode == 1 ? m_packetBytes : 64 * 1024;
    qsizetype offset = 0;
    while (offset < bytes.size()) {
        if (m_receivePacket.isEmpty()) m_receiveTimestamp = timestamp;
        const qsizetype take = qMin(packetSize - m_receivePacket.size(), bytes.size() - offset);
        m_receivePacket.append(bytes.constData() + offset, take);
        offset += take;
        if (m_receivePacket.size() == packetSize) flushReceivePacket();
    }

    if (!m_receivePacket.isEmpty() && (m_packetMode == 1 || !m_receiveDeadline.isActive()))
        m_receiveDeadline.start(m_packetMilliseconds);
}

void SerialManager::configureReceivePackets(int mode, int milliseconds, int bytes)
{
    flushReceivePacket();
    m_packetMode = mode == 1 ? 1 : 0;
    m_packetMilliseconds = qBound(1, milliseconds, 10000);
    m_packetBytes = qBound(1, bytes, 65536);
}

void SerialManager::discardReceivePacket()
{
    m_receiveDeadline.stop();
    m_receiveDrain.stop();
    m_receivePacket.clear();
    if (m_serialPort->isOpen() && m_serialPort->bytesAvailable() > 0)
        m_serialPort->readAll();
    m_rxDecoder.reset(m_dataEncoding);
}

void SerialManager::flushReceivePacket()
{
    m_receiveDeadline.stop();
    if (m_receivePacket.isEmpty()) return;
    const auto packet = std::exchange(m_receivePacket, QByteArray());
    emitReceivePacket(packet, m_receiveTimestamp);
}

void SerialManager::emitReceivePacket(const QByteArray &bytes, qint64 timestamp)
{
    emit dataReceived(m_rxDecoder.decode(bytes), bytes.toHex(' ').toUpper(), false, false, timestamp, m_dataEncoding);
}

void SerialManager::copyToClipboard(const QString &text)
{
    QClipboard *clipboard = QGuiApplication::clipboard();
    if (clipboard) {
        clipboard->setText(text);
    }
}
