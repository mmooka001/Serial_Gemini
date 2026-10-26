#include <QCoreApplication>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QElapsedTimer>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QSerialPort>
#include <QThread>
#include <functional>
#include <iostream>
#include <vector>

#include "SerialManager.h"
#include "RecordStore.h"

struct Result { QString name; bool passed; QString detail; };

class WorkflowQA {
public:
    explicit WorkflowQA(const QString &fixturePath) : fixture(&engine, QUrl::fromLocalFile(fixturePath)) {}

    void check(const QString &name, bool passed, const QString &detail = {}) {
        results.push_back({name, passed, detail});
        std::cout << (passed ? "PASS " : "FAIL ") << name.toStdString();
        if (!detail.isEmpty()) std::cout << " - " << detail.toStdString();
        std::cout << std::endl;
    }

    bool initialize() {
        if (fixture.isError()) {
            QString errors;
            for (const auto &e : fixture.errors()) errors += e.toString() + QLatin1Char('\n');
            check(QStringLiteral("load production SendController fixture"), false, errors);
            return false;
        }
        const bool aOpen = backendA.openPort(QStringLiteral("COM1"), 115200);
        check(QStringLiteral("SerialManager A opens COM1"), aOpen, aOpen ? QString() : QStringLiteral("openPort returned false"));
        const bool bOpen = backendB.openPort(QStringLiteral("COM2"), 115200);
        check(QStringLiteral("SerialManager B opens COM2"), bOpen, bOpen ? QString() : QStringLiteral("openPort returned false"));
        if (!aOpen || !bOpen) return false;

        backendA.setLineEndingMode(0);
        backendB.setLineEndingMode(0);
        backendA.setDataEncoding(QStringLiteral("UTF-8"));
        backendB.setDataEncoding(QStringLiteral("UTF-8"));
        QObject::connect(&backendA, &SerialManager::dataReceived, &backendA,
            [this](const QString &, const QString &hex, bool sent, bool) {
                if (sent) ++txARecords;
                else rxA += QByteArray::fromHex(hex.toLatin1().replace(" ", ""));
            });
        QObject::connect(&backendB, &SerialManager::dataReceived, &backendB,
            [this](const QString &, const QString &hex, bool sent, bool) {
                if (sent) ++txBRecords;
                else rxB += QByteArray::fromHex(hex.toLatin1().replace(" ", ""));
            });
        QObject::connect(&backendA, &SerialManager::errorOccurred, &backendA,
            [this](const QString &e) { errorsA.push_back(e); });
        QObject::connect(&backendB, &SerialManager::errorOccurred, &backendB,
            [this](const QString &e) { errorsB.push_back(e); });

        flowA = createFlow(backendA, QStringLiteral("workflowA"));
        flowB = createFlow(backendB, QStringLiteral("workflowB"));
        controllerA = flowA ? flowA->findChild<QObject *>(QStringLiteral("sender")) : nullptr;
        controllerB = flowB ? flowB->findChild<QObject *>(QStringLiteral("sender")) : nullptr;
        check(QStringLiteral("create two QML controllers from production SendController.qml"),
              flowA && flowB && controllerA && controllerB,
              componentErrors());
        return flowA && flowB && controllerA && controllerB;
    }

    void run() {
        testSendOnce();
        testHexConversionWriteback();
        testChecksums();
        testIndependentLoopsAndStop();
        testDisconnectReconnect();
    }

    void cleanup() {
        if (flowA) flowA->setProperty("running", false);
        if (flowB) flowB->setProperty("running", false);
        backendA.closePort();
        backendB.closePort();
        QCoreApplication::processEvents();
        check(QStringLiteral("COM1 and COM2 are released"), !backendA.isOpen() && !backendB.isOpen());
        delete flowA; flowA = nullptr; controllerA = nullptr;
        delete flowB; flowB = nullptr; controllerB = nullptr;
        QCoreApplication::processEvents();
    }

    int failures() const {
        int count = 0;
        for (const auto &r : results) if (!r.passed) ++count;
        return count;
    }
    int passed() const { return int(results.size()) - failures(); }

    QJsonObject json() const {
        QJsonArray cases;
        for (const auto &r : results) {
            QJsonObject item; item["name"] = r.name; item["passed"] = r.passed; item["detail"] = r.detail;
            cases.append(item);
        }
        QJsonObject root;
        root["suite"] = "serial_qml_workflow";
        root["timestampUtc"] = QDateTime::currentDateTimeUtc().toString(Qt::ISODate);
        root["platform"] = "offscreen";
        root["ports"] = QJsonArray{"COM1", "COM2"};
        root["passed"] = passed(); root["failed"] = failures(); root["cases"] = cases;
        return root;
    }

private:
    QObject *createFlow(SerialManager &backend, const QString &name) {
        QObject *flow = fixture.createWithInitialProperties({
            {QStringLiteral("backend"), QVariant::fromValue(static_cast<QObject *>(&backend))}
        });
        if (flow) flow->setObjectName(name);
        return flow;
    }

    QString componentErrors() const {
        QString errors;
        for (const auto &e : fixture.errors()) errors += e.toString() + QLatin1Char('\n');
        return errors;
    }

    bool invokeBool(QObject *object, const char *function) {
        bool result = false;
        const bool invoked = QMetaObject::invokeMethod(object, function, Qt::DirectConnection, Q_RETURN_ARG(bool, result));
        if (!invoked) check(QStringLiteral("QML method invocation"), false, QString::fromLatin1(function));
        return invoked && result;
    }

    bool waitFor(const std::function<bool()> &predicate, int timeoutMs = 2500) {
        QElapsedTimer timer; timer.start();
        while (timer.elapsed() < timeoutMs) {
            QCoreApplication::processEvents();
            if (predicate()) return true;
            QThread::msleep(1);
        }
        QCoreApplication::processEvents();
        return predicate();
    }

    bool waitRx(QByteArray &rx, int offset, int count, int timeoutMs = 2500) {
        return waitFor([&rx, offset, count]() { return rx.size() >= offset + count; }, timeoutMs);
    }

    void testSendOnce() {
        const int offset = rxB.size();
        flowA->setProperty("inputText", QStringLiteral("qml-once"));
        flowA->setProperty("hexMode", false);
        flowA->setProperty("checksumType", 0);
        const bool sent = invokeBool(controllerA, "sendOnce");
        const QByteArray expected("qml-once");
        const bool arrived = waitRx(rxB, offset, expected.size());
        check(QStringLiteral("SendController.sendOnce actual COM1->COM2 bytes"),
              sent && arrived && rxB.mid(offset, expected.size()) == expected,
              QStringLiteral("received %1 bytes").arg(arrived ? expected.size() : rxB.size() - offset));
    }

    void testHexConversionWriteback() {
        const int offset = rxB.size();
        flowA->setProperty("inputText", QStringLiteral("\"QML中文\""));
        flowA->setProperty("hexMode", true);
        flowA->setProperty("checksumType", 0);
        const bool sent = invokeBool(controllerA, "sendOnce");
        const QByteArray expected = QString::fromUtf8("QML中文").toUtf8();
        const bool arrived = waitRx(rxB, offset, expected.size());
        const QString expectedHex = QString::fromLatin1(expected.toHex(' ').toUpper());
        const QString writtenBack = flowA->property("inputText").toString();
        check(QStringLiteral("HEX-mode nonhex conversion writes inputText back from inputConverted"),
              writtenBack == expectedHex,
              QStringLiteral("inputText=%1 expected=%2").arg(writtenBack, expectedHex));
        check(QStringLiteral("converted HEX payload reaches peer as intended text bytes"),
              sent && arrived && rxB.mid(offset, expected.size()) == expected,
              QStringLiteral("received %1 bytes").arg(arrived ? expected.size() : rxB.size() - offset));
    }

    void testChecksums() {
        struct Check { int type; const char *label; const char *suffixHex; };
        const Check checks[] = {{1, "BCC", "31"}, {2, "Sum8", "DD"}, {3, "CRC16 Modbus", "374B"}};
        for (const auto &checkSpec : checks) {
            const int offset = rxB.size();
            flowA->setProperty("inputText", QStringLiteral("123456789"));
            flowA->setProperty("hexMode", false);
            flowA->setProperty("checksumType", checkSpec.type);
            const bool sent = invokeBool(controllerA, "sendOnce");
            const QByteArray expected = QByteArray("123456789") + QByteArray::fromHex(checkSpec.suffixHex);
            const bool arrived = waitRx(rxB, offset, expected.size());
            check(QStringLiteral("SendController sendOnce with %1 sends checksum bytes").arg(QString::fromLatin1(checkSpec.label)),
                  sent && arrived && rxB.mid(offset, expected.size()) == expected,
                  QStringLiteral("received %1/%2 bytes").arg(arrived ? expected.size() : rxB.size() - offset).arg(expected.size()));
        }
    }

    void testIndependentLoopsAndStop() {
        rxA.clear(); rxB.clear();
        txARecords = txBRecords = 0;
        flowA->setProperty("inputText", QStringLiteral("A"));
        flowA->setProperty("hexMode", false);
        flowA->setProperty("checksumType", 0);
        flowA->setProperty("interval", 45);
        flowB->setProperty("inputText", QStringLiteral("B"));
        flowB->setProperty("hexMode", false);
        flowB->setProperty("checksumType", 0);
        flowB->setProperty("interval", 85);
        QMetaObject::invokeMethod(controllerA, "toggleRepeat", Qt::DirectConnection);
        QMetaObject::invokeMethod(controllerB, "toggleRepeat", Qt::DirectConnection);
        const bool bothStarted = flowA->property("running").toBool() && flowB->property("running").toBool();
        const bool gotA = waitFor([this]() { return rxB.size() >= 4; }, 900);
        const bool gotB = waitFor([this]() { return rxA.size() >= 3; }, 900);
        check(QStringLiteral("different-interval loops run bidirectionally"),
              bothStarted && gotA && gotB && QByteArray("AAAA").contains(rxB.left(4)) && rxA.startsWith("BBB"),
              QStringLiteral("A->B=%1 bytes B->A=%2 bytes").arg(rxB.size()).arg(rxA.size()));
        QMetaObject::invokeMethod(controllerA, "toggleRepeat", Qt::DirectConnection);
        QMetaObject::invokeMethod(controllerB, "toggleRepeat", Qt::DirectConnection);
        const bool stopped = !flowA->property("running").toBool() && !flowB->property("running").toBool();
        QCoreApplication::processEvents();
        const int rxASize = rxA.size(), rxBSize = rxB.size();
        QThread::msleep(220);
        QCoreApplication::processEvents();
        check(QStringLiteral("both loops stop and remain stable"), stopped && rxA.size() == rxASize && rxB.size() == rxBSize,
              QStringLiteral("before A/B=%1/%2 after A/B=%3/%4").arg(rxASize).arg(rxBSize).arg(rxA.size()).arg(rxB.size()));

        const int beforeManual = rxB.size();
        flowA->setProperty("inputText", QStringLiteral("manual-again"));
        const bool manualSent = invokeBool(controllerA, "sendOnce");
        const bool manualArrived = waitRx(rxB, beforeManual, 12);
        const int afterManual = rxB.size();
        QThread::msleep(180); QCoreApplication::processEvents();
        check(QStringLiteral("manual send works again after loops stop"),
              manualSent && manualArrived && rxB.mid(beforeManual, 12) == QByteArray("manual-again") && rxB.size() == afterManual,
              QStringLiteral("manual bytes=%1; stable after=%2").arg(afterManual - beforeManual).arg(rxB.size()));
    }

    void testDisconnectReconnect() {
        flowA->setProperty("inputText", QStringLiteral("loop-before-close"));
        flowA->setProperty("hexMode", false);
        flowA->setProperty("interval", 35);
        QMetaObject::invokeMethod(controllerA, "toggleRepeat", Qt::DirectConnection);
        const bool started = flowA->property("running").toBool();
        waitFor([this]() { return txARecords >= 2; }, 700);
        backendA.closePort();
        const bool stoppedOnDisconnect = waitFor([this]() { return !flowA->property("running").toBool(); }, 400);
        const int txAfterClose = txARecords;
        QThread::msleep(180); QCoreApplication::processEvents();
        const bool stableClosed = txARecords == txAfterClose;
        const bool sendRejected = !invokeBool(controllerA, "sendOnce");
        check(QStringLiteral("disconnect automatically stops active loop and blocks send"),
              started && stoppedOnDisconnect && stableClosed && sendRejected,
              QStringLiteral("started=%1 stopped=%2 stable=%3").arg(started).arg(stoppedOnDisconnect).arg(stableClosed));

        const bool reopened = backendA.openPort(QStringLiteral("COM1"), 115200);
        const int offset = rxB.size();
        flowA->setProperty("inputText", QStringLiteral("after-reconnect"));
        const bool manualSent = invokeBool(controllerA, "sendOnce");
        const QByteArray expected("after-reconnect");
        const bool arrived = waitRx(rxB, offset, expected.size());
        check(QStringLiteral("reconnect restores manual sending"),
              reopened && manualSent && arrived && rxB.mid(offset, expected.size()) == expected,
              QStringLiteral("reopened=%1 arrived=%2").arg(reopened).arg(arrived));

        flowA->setProperty("interval", 40);
        const int loopStart = rxB.size();
        QMetaObject::invokeMethod(controllerA, "toggleRepeat", Qt::DirectConnection);
        const bool loopResumed = waitRx(rxB, loopStart, 2, 600);
        QMetaObject::invokeMethod(controllerA, "toggleRepeat", Qt::DirectConnection);
        waitFor([this]() { return !flowA->property("running").toBool(); }, 250);
        check(QStringLiteral("loop can be restarted after reconnect"), loopResumed && !flowA->property("running").toBool());
    }

    QQmlEngine engine;
    QQmlComponent fixture;
    SerialManager backendA, backendB;
    QObject *flowA = nullptr; QObject *flowB = nullptr;
    QObject *controllerA = nullptr; QObject *controllerB = nullptr;
    QByteArray rxA, rxB;
    quint64 txARecords = 0, txBRecords = 0;
    std::vector<QString> errorsA, errorsB;
    std::vector<Result> results;
};

int main(int argc, char **argv) {
    qputenv("QT_QPA_PLATFORM", "offscreen");
    QGuiApplication app(argc, argv);
    const QString fixturePath = QDir::current().filePath(QStringLiteral("tests/serial_workflow_fixture.qml"));
    WorkflowQA qa(fixturePath);
    const bool ready = qa.initialize();
    if (ready) qa.run();
    qa.cleanup();
    const QString outPath = QDir::current().filePath(QStringLiteral("_verify_build/serial-qml-workflow-results.json"));
    QDir().mkpath(QFileInfo(outPath).absolutePath());
    QFile out(outPath);
    if (!out.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        std::cerr << "Could not write results JSON: " << outPath.toStdString() << std::endl;
        return 2;
    }
    out.write(QJsonDocument(qa.json()).toJson(QJsonDocument::Indented));
    std::cout << "SUMMARY passed=" << qa.passed() << " failed=" << qa.failures()
              << " results=" << outPath.toStdString() << std::endl;
    return qa.failures() == 0 ? 0 : 1;
}
