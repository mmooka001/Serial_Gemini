#include <QCoreApplication>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSerialPort>
#include <QSerialPortInfo>
#include <QThread>
#include <QElapsedTimer>
#include <functional>
#include <iostream>
#include <vector>

#include "SerialManager.h"
#include "ChecksumHelper.h"
#include "RecordStore.h"

struct CaseResult { QString name; bool passed; QString detail; QString category; };

class LoopbackQA {
public:
    LoopbackQA() : manager(), peer(), recordStore() {}

    void check(const QString &name, bool ok, const QString &detail = {}, bool diagnostic = false) {
        cases.push_back({name, ok, detail, diagnostic ? QStringLiteral("diagnostic") : QStringLiteral("production")});
        std::cout << (diagnostic ? (ok ? "DIAG-PASS " : "DIAG-OBS ") : (ok ? "PASS " : "FAIL ")) << name.toStdString();
        if (!detail.isEmpty()) std::cout << " - " << detail.toStdString();
        std::cout << std::endl;
    }

    bool init() {
        peer.setPortName(QStringLiteral("COM2"));
        peer.setBaudRate(115200);
        peer.setDataBits(QSerialPort::Data8);
        peer.setParity(QSerialPort::NoParity);
        peer.setStopBits(QSerialPort::OneStop);
        peer.setFlowControl(QSerialPort::NoFlowControl);
        const bool peerOpen = peer.open(QIODevice::ReadWrite);
        check(QStringLiteral("peer opens COM2"), peerOpen, peerOpen ? QString() : peer.errorString());
        if (!peerOpen) return false;
        QObject::connect(&peer, &QSerialPort::readyRead, &peer,
                         [this]() { peerCaptured += peer.readAll(); });
        const bool managerOpen = manager.openPort(QStringLiteral("COM1"), 115200);
        check(QStringLiteral("production SerialManager opens COM1"), managerOpen,
              managerOpen ? QString() : QStringLiteral("openPort returned false"));
        connected = managerOpen;
        QObject::connect(&manager, &SerialManager::dataReceived, &manager,
            [this](const QString &ascii, const QString &hex, bool sent, bool isHex) {
                if (sent) txSignals.push_back({ascii, hex, isHex});
                else rxSignals.push_back({ascii, hex, isHex});
                recordStore.onDataReceived(ascii, hex, sent);
            });
        QObject::connect(&manager, &SerialManager::errorOccurred, &manager,
            [this](const QString &error) { errors.push_back(error); });
        productionPort = manager.findChild<QSerialPort *>();
        if (productionPort) {
            QObject::connect(productionPort, &QSerialPort::bytesWritten, &manager,
                [this](qint64 count) { productionBytesWritten += count; });
        }
        return managerOpen;
    }

    QByteArray readPeer(int expectedAtLeast, int timeoutMs = 1500) {
        QElapsedTimer timer; timer.start();
        while (timer.elapsed() < timeoutMs && peerCaptured.size() < expectedAtLeast) {
            QCoreApplication::processEvents();
            if (peer.bytesAvailable()) peerCaptured += peer.readAll();
            QThread::msleep(2);
        }
        if (peer.bytesAvailable()) peerCaptured += peer.readAll();
        QByteArray got = peerCaptured;
        peerCaptured.clear();
        return got;
    }

    void drainPeer() {
        peer.readAll(); peerCaptured.clear(); QCoreApplication::processEvents();
        if (peer.bytesAvailable()) peer.readAll();
        peerCaptured.clear();
    }
    bool sendCapture(const QString &text, bool hex, int lineEnding, const QByteArray &expected,
                     int checksum = 0, const QString &name = QStringLiteral("send"), int timeoutMs = 1500) {
        drainPeer(); manager.setLineEndingMode(lineEnding);
        const quint64 txBefore = recordStore.txCount();
        if (checksum) manager.sendDataWithChecksum(text, hex, checksum);
        else manager.sendData(text, hex);
        QByteArray got = readPeer(expected.size(), timeoutMs);
        QString detail;
        if (got != expected) {
            if (expected.size() > 128 || got.size() > 128)
                detail = QStringLiteral("expected %1 bytes, got %2; prefix %3")
                    .arg(expected.size()).arg(got.size()).arg(QString::fromLatin1(got.left(16).toHex(' ')));
            else
                detail = QStringLiteral("expected %1, got %2")
                    .arg(QString::fromLatin1(expected.toHex(' ')), QString::fromLatin1(got.toHex(' ')));
        }
        check(name, got == expected, detail);
        check(name + QStringLiteral(" RecordStore TX byte count"),
              recordStore.txCount() - txBefore == quint64(expected.size()),
              QStringLiteral("counter delta %1, expected %2")
                  .arg(recordStore.txCount() - txBefore).arg(expected.size()));
        return got == expected;
    }

    void testTransmitReceive() {
        sendCapture(QStringLiteral("hello"), false, 0, QByteArray("hello"), 0, QStringLiteral("TXT no ending"));
        sendCapture(QStringLiteral("hello"), false, 1, QByteArray("hello\n"), 0, QStringLiteral("TXT LF"));
        sendCapture(QStringLiteral("hello"), false, 2, QByteArray("hello\r"), 0, QStringLiteral("TXT CR"));
        sendCapture(QStringLiteral("hello"), false, 3, QByteArray("hello\r\n"), 0, QStringLiteral("TXT CRLF"));
        sendCapture(QStringLiteral("0x0a 0XbC de f0"), true, 3,
                    QByteArray::fromHex("0ab cdef0"), 0, QStringLiteral("HEX prefix/space/mixed case; no line ending"));
        QByteArray all; for (int i=0;i<256;++i) all.append(char(i));
        sendCapture(QString::fromLatin1(all.toHex(' ').toUpper()), true, 3, all, 0,
                    QStringLiteral("HEX all 256 byte values"));

        QByteArray longPayload(32768, '\xA5');
        drainPeer(); manager.setLineEndingMode(0);
        const quint64 txBeforeLong = recordStore.txCount();
        const qint64 writtenBeforeLong = productionBytesWritten;
        manager.sendData(QString::fromLatin1(longPayload.toHex()), true);
        const qint64 queuedOnReturn = productionPort ? productionPort->bytesToWrite() : -1;
        const QByteArray productionGot = readPeer(longPayload.size(), 10000);
        const qint64 productionWritten = productionBytesWritten - writtenBeforeLong;
        check(QStringLiteral("production 32768-byte packet actual wire bytes"), productionGot == longPayload,
              QStringLiteral("got %1/%2 bytes; bytesToWrite immediately after send=%3; bytesWritten signal=%4; RecordStore TX delta=%5")
                  .arg(productionGot.size()).arg(longPayload.size()).arg(queuedOnReturn)
                  .arg(productionWritten).arg(recordStore.txCount() - txBeforeLong));
        check(QStringLiteral("production 32768-byte packet bytesWritten total"),
              productionWritten == longPayload.size(), QString::number(productionWritten));
        check(QStringLiteral("production 32768-byte packet TX RecordStore count"),
              recordStore.txCount() - txBeforeLong == quint64(longPayload.size()),
              QString::number(recordStore.txCount() - txBeforeLong));
        bool shortOk = true;
        for (int i=0; i<40; ++i) {
            const QByteArray packet = QByteArray(1, char(i)) + QByteArray(1, char(255-i));
            manager.sendData(QString::fromLatin1(packet.toHex()), true);
            const QByteArray got = readPeer(2);
            if (got != packet) { shortOk = false; break; }
        }
        check(QStringLiteral("40 consecutive short packets"), shortOk);
        testRapidEnqueue();

        QByteArray input(256, Qt::Uninitialized); for (int i=0;i<256;++i) input[i] = char(i);
        int before = int(rxSignals.size());
        const quint64 rxCountBefore = recordStore.rxCount();
        peer.write(input); peer.flush();
        QElapsedTimer timer; timer.start();
        QByteArray rxHex;
        while (timer.elapsed() < 1500 && rxHex.size() < input.size()) {
            QCoreApplication::processEvents();
            while (int(rxSignals.size()) > before) {
                const auto sig = rxSignals[before]; rxHex += QByteArray::fromHex(sig.hex.toLatin1().replace(" ", ""));
                ++before;
            }
            QThread::msleep(2);
        }
        check(QStringLiteral("RX all 256 byte values exact"), rxHex == input,
              QStringLiteral("captured %1 of %2 bytes").arg(rxHex.size()).arg(input.size()));
        check(QStringLiteral("RecordStore RX byte counter on 256-byte capture"),
              recordStore.rxCount() - rxCountBefore == 256,
              QStringLiteral("counter delta %1").arg(recordStore.rxCount() - rxCountBefore));

        testSplitDecode(QStringLiteral("UTF-8 3-byte"), QStringLiteral("UTF-8"),
                        QByteArray::fromHex("e4b8ad"), QStringLiteral("中"));
        const QString emoji = QString::fromUtf8("\xF0\x9F\x98\x80");
        testSplitDecode(QStringLiteral("UTF-8 4-byte emoji"), QStringLiteral("UTF-8"),
                        QByteArray::fromHex("f09f9880"), emoji);
        testSplitDecode(QStringLiteral("GBK 2-byte"), QStringLiteral("GBK"),
                        QByteArray::fromHex("d6d0"), QStringLiteral("中"));
        testSplitDecode(QStringLiteral("GB2312 2-byte"), QStringLiteral("GB2312"),
                        QByteArray::fromHex("d6d0"), QStringLiteral("中"));
    }

    void testEncodingsAndChecksums() {
        struct Enc { const char *name; const char *text; const char *hex; } encodings[] = {
            {"UTF-8", "中文", "e4b8ade69687"}, {"GBK", "中文", "d6d0cec4"},
            {"GB2312", "中文", "d6d0cec4"}, {"ASCII", "A中", "413f"},
            {"ISO-8859-1", "Café", "436166e9"}
        };
        for (const auto &e : encodings) {
            manager.setDataEncoding(QString::fromLatin1(e.name));
            const QByteArray encoded = QByteArray::fromHex(e.hex);
            sendCapture(QString::fromUtf8(e.text), false, 0, encoded, 0,
                        QStringLiteral("encoding TX %1").arg(QString::fromLatin1(e.name)));
            const int rxBeforeEncoding = int(rxSignals.size());
            peer.write(encoded); peer.flush();
            QElapsedTimer rxTimer; rxTimer.start();
            while (rxTimer.elapsed() < 1000 && int(rxSignals.size()) == rxBeforeEncoding) {
                QCoreApplication::processEvents(); QThread::msleep(2);
            }
            QString expectedDecoded = QString::fromUtf8(e.text);
            if (QString::fromLatin1(e.name) == QStringLiteral("ASCII")) expectedDecoded = QStringLiteral("A?");
            const bool gotSignal = int(rxSignals.size()) > rxBeforeEncoding;
            check(QStringLiteral("encoding RX %1").arg(QString::fromLatin1(e.name)),
                  gotSignal && rxSignals[rxBeforeEncoding].ascii == expectedDecoded,
                  gotSignal ? rxSignals[rxBeforeEncoding].ascii : QStringLiteral("no RX signal"));
        }
        manager.setDataEncoding(QStringLiteral("UTF-8"));
        sendCapture(QStringLiteral("123456789"), false, 0, QByteArray("123456789") + QByteArray::fromHex("31"), 1,
                    QStringLiteral("BCC/XOR actual byte"));
        sendCapture(QStringLiteral("123456789"), false, 0, QByteArray("123456789") + QByteArray::fromHex("dd"), 2,
                    QStringLiteral("Sum8 actual byte"));
        sendCapture(QStringLiteral("123456789"), false, 0, QByteArray("123456789") + QByteArray::fromHex("374b"), 3,
                    QStringLiteral("CRC16 Modbus actual bytes (123456789 -> 37 4B)"));
        auto preview = [](const QString &data, int type) { return ChecksumHelper::hexChecksumPreview(data, false, type); };
        check(QStringLiteral("BCC checksum preview"), preview(QStringLiteral("123456789"),1)==QStringLiteral("31"), preview(QStringLiteral("123456789"),1));
        check(QStringLiteral("Sum8 checksum preview"), preview(QStringLiteral("123456789"),2)==QStringLiteral("DD"), preview(QStringLiteral("123456789"),2));
        check(QStringLiteral("CRC16 Modbus checksum preview"), preview(QStringLiteral("123456789"),3)==QStringLiteral("37 4B"), preview(QStringLiteral("123456789"),3));
    }

    void testSplitDecode(const QString &label, const QString &encoding,
                         const QByteArray &wireBytes, const QString &expectedText) {
        manager.setDataEncoding(encoding);
        const int signalStart = int(rxSignals.size());
        QByteArray collectedHex;
        for (int i = 0; i < wireBytes.size(); ++i) {
            peer.write(wireBytes.constData() + i, 1); peer.flush();
            QElapsedTimer timer; timer.start();
            while (timer.elapsed() < 1000 && collectedHex.size() < i + 1) {
                QCoreApplication::processEvents();
                QByteArray accumulated;
                for (int j = signalStart; j < int(rxSignals.size()); ++j) {
                    const QByteArray compact = rxSignals[j].hex.toLatin1().replace(" ", "");
                    accumulated += QByteArray::fromHex(compact);
                }
                collectedHex = accumulated;
                QThread::msleep(2);
            }
        }
        QElapsedTimer settle; settle.start();
        while (settle.elapsed() < 200 && int(rxSignals.size()) == signalStart) QCoreApplication::processEvents();
        QString decoded;
        for (int j = signalStart; j < int(rxSignals.size()); ++j) decoded += rxSignals[j].ascii;
        const bool gotEveryByte = collectedHex == wireBytes;
        check(QStringLiteral("RX split decode %1" ).arg(label),
              gotEveryByte && decoded == expectedText,
              QStringLiteral("wire HEX %1/%2; decoded %3")
                  .arg(collectedHex.size()).arg(wireBytes.size()).arg(decoded));
    }

    void testRapidEnqueue() {
        drainPeer();
        manager.setLineEndingMode(0);
        const quint64 txCountBefore = recordStore.txCount();
        const int txSignalBefore = int(txSignals.size());
        QByteArray expected;
        for (int i = 0; i < 64; ++i) {
            const QByteArray frame = QStringLiteral("burst-%1|").arg(i, 2, 10, QLatin1Char('0')).toLatin1();
            expected += frame;
            manager.sendData(QString::fromLatin1(frame), false);
        }
        const QByteArray actual = readPeer(expected.size(), 5000);
        QElapsedTimer timer; timer.start();
        while (timer.elapsed() < 1000 && recordStore.txCount() - txCountBefore < quint64(expected.size())) {
            QCoreApplication::processEvents(); QThread::msleep(2);
        }
        check(QStringLiteral("64 rapid queued sends preserve wire order"), actual == expected,
              QStringLiteral("wire=%1/%2 bytes").arg(actual.size()).arg(expected.size()));
        check(QStringLiteral("64 rapid queued sends emit one TX record per frame"),
              int(txSignals.size()) - txSignalBefore == 64,
              QStringLiteral("TX records=%1").arg(int(txSignals.size()) - txSignalBefore));
        check(QStringLiteral("64 rapid queued sends RecordStore TX count"),
              recordStore.txCount() - txCountBefore == quint64(expected.size()),
              QStringLiteral("counter delta=%1 expected=%2")
                  .arg(recordStore.txCount() - txCountBefore).arg(expected.size()));
    }

    void testRawLargePacketDiagnostics() {
        manager.closePort();
        if (!productionPort) {
            check(QStringLiteral("raw QSerialPort diagnostics open"), false,
                  QStringLiteral("SerialManager child QSerialPort not found"), true);
            return;
        }
        productionPort->setPortName(QStringLiteral("COM1"));
        productionPort->setBaudRate(115200);
        productionPort->setDataBits(QSerialPort::Data8);
        productionPort->setParity(QSerialPort::NoParity);
        productionPort->setStopBits(QSerialPort::OneStop);
        productionPort->setFlowControl(QSerialPort::NoFlowControl);
        if (!productionPort->open(QIODevice::ReadWrite)) {
            check(QStringLiteral("raw QSerialPort diagnostics open"), false,
                  productionPort->errorString(), true);
            return;
        }
        auto singleWrite = [this](const QByteArray &payload, bool callFlush, const QString &label) {
            drainPeer();
            const qint64 writtenBefore = productionBytesWritten;
            const qint64 accepted = productionPort->write(payload);
            const qint64 queued = productionPort->bytesToWrite();
            const bool flushResult = callFlush ? productionPort->flush() : false;
            const QByteArray got = readPeer(payload.size(), 5000);
            check(QStringLiteral("raw single-write diagnostic %1").arg(label), got == payload,
                  QStringLiteral("accepted=%1 queued=%2 flush-called=%3 flush-result=%4 bytesWritten=%5 wire=%6/%7")
                      .arg(accepted).arg(queued).arg(callFlush).arg(flushResult)
                      .arg(productionBytesWritten - writtenBefore).arg(got.size()).arg(payload.size()), true);
        };
        singleWrite(QByteArray(4096, '\xA5'), false, QStringLiteral("4096"));
        singleWrite(QByteArray(8192, '\xA5'), false, QStringLiteral("8192"));
        singleWrite(QByteArray(32768, '\xA5'), false, QStringLiteral("32768 no flush"));
        singleWrite(QByteArray(32768, '\xA5'), true, QStringLiteral("32768 with flush"));

        const QByteArray payload(32768, '\xA5');
        QByteArray received;
        bool allAccepted = true;
        for (int offset = 0; offset < payload.size(); offset += 4096) {
            const QByteArray chunk = payload.mid(offset, 4096);
            if (productionPort->write(chunk) != chunk.size()) allAccepted = false;
            received += readPeer(chunk.size(), 2000);
        }
        check(QStringLiteral("raw chunked diagnostic 32768 (8x4096)"), allAccepted && received == payload,
              QStringLiteral("accepted-all=%1 wire=%2/%3")
                  .arg(allAccepted).arg(received.size()).arg(payload.size()), true);
        productionPort->close();
        QCoreApplication::processEvents();
    }

    void testDisconnectReconnect() {
        manager.closePort(); connected = false;
        const int oldErrors = errors.size(); manager.sendData(QStringLiteral("x"), false);
        check(QStringLiteral("send after disconnect reports error"), errors.size() == oldErrors + 1);
        const bool reopened = manager.openPort(QStringLiteral("COM1"), 115200); connected = reopened;
        check(QStringLiteral("reconnect COM1"), reopened,
              reopened || errors.empty() ? QString() : errors.back());
        if (reopened) sendCapture(QStringLiteral("again"), false, 0, QByteArray("again"), 0, QStringLiteral("send after reconnect"));
    }

    void cleanup() {
        manager.closePort();
        if (peer.isOpen()) peer.close();
        QCoreApplication::processEvents();
        check(QStringLiteral("both COM ports released"), !manager.isOpen() && !peer.isOpen());
    }

    QJsonObject json() const {
        QJsonArray arr; int productionPassed=0, productionFailed=0, diagnosticPassed=0, diagnosticFailed=0;
        for (const auto &c : cases) {
            QJsonObject o; o["name"]=c.name; o["passed"]=c.passed; o["detail"]=c.detail; o["category"]=c.category; arr.append(o);
            if (c.category == QStringLiteral("diagnostic")) c.passed ? ++diagnosticPassed : ++diagnosticFailed;
            else c.passed ? ++productionPassed : ++productionFailed;
        }
        QJsonObject root; root["suite"]="serial_loopback"; root["timestampUtc"]=QDateTime::currentDateTimeUtc().toString(Qt::ISODate);
        root["ports"]=QJsonArray{"COM1","COM2"}; root["passed"]=productionPassed; root["failed"]=productionFailed;
        root["productionPassed"]=productionPassed; root["productionFailed"]=productionFailed;
        root["diagnosticsPassed"]=diagnosticPassed; root["diagnosticsObserved"]=diagnosticFailed; root["cases"]=arr;
        root["diagnosticsBaselineFile"]="_verify_build/serial-loopback-results-before.json";
        root["diagnosticObservation"]="Prior raw QSerialPort controls showed single writes above 4096 bytes delivered only 4096 bytes by this virtual pair; 8x4096 raw writes delivered all 32768 bytes. See preserved before JSON.";
        return root;
    }
    int failures() const { int n=0; for (const auto &c:cases) if(c.category == QStringLiteral("production") && !c.passed) ++n; return n; }
    int diagnosticFailures() const { int n=0; for (const auto &c:cases) if(c.category == QStringLiteral("diagnostic") && !c.passed) ++n; return n; }

private:
    struct Signal { QString ascii, hex; bool isHex; };
    SerialManager manager; QSerialPort peer; RecordStore recordStore; QSerialPort *productionPort=nullptr;
    qint64 productionBytesWritten=0; bool connected=false; QByteArray peerCaptured;
    std::vector<CaseResult> cases; std::vector<Signal> txSignals, rxSignals; std::vector<QString> errors;
};

int main(int argc, char **argv) {
    QCoreApplication app(argc, argv);
    LoopbackQA qa;
    bool ready = qa.init();
    if (ready) { qa.testTransmitReceive(); qa.testEncodingsAndChecksums(); qa.testDisconnectReconnect(); }
    qa.cleanup();
    const QString outPath = QDir::current().filePath(QStringLiteral("_verify_build/serial-loopback-results.json"));
    QDir().mkpath(QFileInfo(outPath).absolutePath());
    QFile out(outPath);
    if (out.open(QIODevice::WriteOnly|QIODevice::Truncate)) out.write(QJsonDocument(qa.json()).toJson(QJsonDocument::Indented));
    else { std::cerr << "Could not write results JSON: " << outPath.toStdString() << std::endl; return 2; }
    std::cout << "SUMMARY productionPassed=" << (qa.json()["productionPassed"].toInt())
              << " productionFailed=" << qa.failures()
              << " diagnosticsObserved=" << qa.diagnosticFailures()
              << " results=" << outPath.toStdString() << std::endl;
    return qa.failures() == 0 ? 0 : 1;
}
