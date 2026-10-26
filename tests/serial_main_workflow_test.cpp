#include <QCoreApplication>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMetaProperty>
#include <QQuickWindow>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QSerialPort>
#include <QStandardPaths>
#include <QThread>
#include <QElapsedTimer>
#include <QSettings>
#include <functional>
#include <iostream>
#include <memory>
#include <vector>

#include "SerialManager.h"
#include "ChecksumHelper.h"
#include "CommandStore.h"
#include "SettingsStore.h"
#include "RecordStore.h"

class AcrylicHelper final : public QObject {
    Q_OBJECT
public:
    Q_INVOKABLE void enable(QQuickWindow *) {}
    Q_INVOKABLE void setTint(double, double, double, double) {}
};

struct CheckResult { QString name; bool passed; QString detail; };

struct MainInstance {
    explicit MainInstance(const QString &suffix) {
        const QString appName = QStringLiteral("SerialMainWorkflowQA_%1").arg(suffix);
        QCoreApplication::setApplicationName(appName);
        QCoreApplication::setOrganizationName(QStringLiteral("CodexSerialMainWorkflowQA"));
        QCoreApplication::setOrganizationDomain(QStringLiteral("codex.local"));
        appDataPath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
        serial = std::make_unique<SerialManager>();
        commands = std::make_unique<CommandStore>();
        settings = std::make_unique<SettingsStore>();
        records = std::make_unique<RecordStore>();
        checksum = std::make_unique<ChecksumHelper>();
        acrylic = std::make_unique<AcrylicHelper>();
        engine = std::make_unique<QQmlApplicationEngine>();
        engine->rootContext()->setContextProperty(QStringLiteral("serialManager"), serial.get());
        engine->rootContext()->setContextProperty(QStringLiteral("commandStore"), commands.get());
        engine->rootContext()->setContextProperty(QStringLiteral("ChecksumHelper"), checksum.get());
        engine->rootContext()->setContextProperty(QStringLiteral("settingsStore"), settings.get());
        engine->rootContext()->setContextProperty(QStringLiteral("recordStore"), records.get());
        engine->rootContext()->setContextProperty(QStringLiteral("acrylic"), acrylic.get());
        QObject::connect(serial.get(), &SerialManager::dataReceived, records.get(),
            [this](const QString &ascii, const QString &hex, bool isSent, bool) {
                records->onDataReceived(ascii, hex, isSent);
            });
    }

    bool load() {
        QObject::connect(engine.get(), &QQmlApplicationEngine::objectCreated,
                         engine.get(), [this](QObject *object, const QUrl &) {
            if (object && !root) root = object;
        });
        engine->loadFromModule(QStringLiteral("MySerial_Gemini"), QStringLiteral("Main"));
        QCoreApplication::processEvents();
        if (!root && !engine->rootObjects().isEmpty()) root = engine->rootObjects().first();
        if (root) {
            input = root->findChild<QObject *>(QStringLiteral("sendMessageInput"));
            for (QObject *child : root->findChildren<QObject *>()) {
                if (child->metaObject()->indexOfProperty("inputText") >= 0
                    && child->metaObject()->indexOfProperty("checksumType") >= 0
                    && child->metaObject()->indexOfProperty("hexMode") >= 0) {
                    inputSender = child;
                    break;
                }
            }
        }
        return root && input && inputSender;
    }

    std::unique_ptr<SerialManager> serial;
    std::unique_ptr<CommandStore> commands;
    std::unique_ptr<SettingsStore> settings;
    std::unique_ptr<RecordStore> records;
    std::unique_ptr<ChecksumHelper> checksum;
    std::unique_ptr<AcrylicHelper> acrylic;
    std::unique_ptr<QQmlApplicationEngine> engine;
    QObject *root = nullptr;
    QObject *input = nullptr;
    QObject *inputSender = nullptr;
    QString appDataPath;
};

class MainWorkflowQA {
public:
    MainWorkflowQA() : mainA(QStringLiteral("A")), mainB(QStringLiteral("B")) {}

    void check(const QString &name, bool passed, const QString &detail = {}) {
        results.push_back({name, passed, detail});
        std::cout << (passed ? "PASS " : "FAIL ") << name.toStdString();
        if (!detail.isEmpty()) std::cout << " - " << detail.toStdString();
        std::cout << std::endl;
    }

    bool initialize() {
        const bool loadedA = mainA.load();
        const bool loadedB = mainB.load();
        check(QStringLiteral("load two production Main.qml windows offscreen"), loadedA && loadedB,
              QStringLiteral("A=%1 B=%2").arg(loadedA).arg(loadedB));
        if (!loadedA || !loadedB) return false;

        mainA.settings->setLineEndingMode(0);
        mainB.settings->setLineEndingMode(0);
        mainA.settings->setDataEncoding(QStringLiteral("UTF-8"));
        mainB.settings->setDataEncoding(QStringLiteral("UTF-8"));
        mainA.serial->setDataEncoding(QStringLiteral("UTF-8"));
        mainB.serial->setDataEncoding(QStringLiteral("UTF-8"));

        const bool openedA = mainA.serial->openPort(QStringLiteral("COM1"), 115200);
        const bool openedB = mainB.serial->openPort(QStringLiteral("COM2"), 115200);
        check(QStringLiteral("real SerialManager endpoints open COM1 and COM2"), openedA && openedB,
              QStringLiteral("COM1=%1 COM2=%2").arg(openedA).arg(openedB));
        if (!openedA || !openedB) return false;

        QObject::connect(mainA.serial.get(), &SerialManager::dataReceived, mainA.serial.get(),
            [this](const QString &, const QString &hex, bool sent, bool) {
                if (sent) ++txA;
                else rxA += QByteArray::fromHex(hex.toLatin1().replace(" ", ""));
            });
        QObject::connect(mainB.serial.get(), &SerialManager::dataReceived, mainB.serial.get(),
            [this](const QString &, const QString &hex, bool sent, bool) {
                if (sent) ++txB;
                else rxB += QByteArray::fromHex(hex.toLatin1().replace(" ", ""));
            });
        return true;
    }

    void run() {
        testDoSendAndSendCommand();
        testCommandAndManualLoops();
        testDisconnectStopsAndReconnects();
    }

    void cleanup() {
        if (mainA.root) {
            mainA.root->setProperty("loopSending", false);
            if (mainA.inputSender) mainA.inputSender->setProperty("running", false);
        }
        if (mainB.root) {
            mainB.root->setProperty("loopSending", false);
            if (mainB.inputSender) mainB.inputSender->setProperty("running", false);
        }
        if (mainA.serial) mainA.serial->closePort();
        if (mainB.serial) mainB.serial->closePort();
        QCoreApplication::processEvents();
        check(QStringLiteral("COM1 and COM2 are released"),
              mainA.serial && mainB.serial && !mainA.serial->isOpen() && !mainB.serial->isOpen());
    }

    int failures() const {
        int count = 0; for (const auto &r : results) if (!r.passed) ++count; return count;
    }
    int passed() const { return int(results.size()) - failures(); }
    QJsonObject json() const {
        QJsonArray cases;
        for (const auto &r : results) {
            QJsonObject item; item["name"] = r.name; item["passed"] = r.passed; item["detail"] = r.detail; cases.append(item);
        }
        QJsonObject root; root["suite"] = "serial_main_workflow";
        root["timestampUtc"] = QDateTime::currentDateTimeUtc().toString(Qt::ISODate);
        root["platform"] = "offscreen"; root["ports"] = QJsonArray{"COM1", "COM2"};
        root["passed"] = passed(); root["failed"] = failures();
        root["mainAAppData"] = mainA.appDataPath; root["mainBAppData"] = mainB.appDataPath;
        root["cases"] = cases; return root;
    }

private:
    static bool invoke(QObject *object, const char *method) {
        return object && QMetaObject::invokeMethod(object, method, Qt::DirectConnection);
    }
    static bool invokeBool(QObject *object, const char *method) {
        bool result = false;
        const bool called = object && QMetaObject::invokeMethod(object, method, Qt::DirectConnection,
                                                                  Q_RETURN_ARG(bool, result));
        return called && result;
    }
    bool waitFor(const std::function<bool()> &predicate, int timeoutMs = 2500) {
        QElapsedTimer timer; timer.start();
        while (timer.elapsed() < timeoutMs) {
            QCoreApplication::processEvents();
            if (predicate()) return true;
            QThread::msleep(1);
        }
        QCoreApplication::processEvents(); return predicate();
    }
    void pumpFor(int durationMs) {
        QElapsedTimer timer; timer.start();
        while (timer.elapsed() < durationMs) {
            QCoreApplication::processEvents();
            QThread::msleep(1);
        }
        QCoreApplication::processEvents();
    }
    bool waitRx(const QByteArray &rx, int offset, int count, int timeoutMs = 2500) {
        return waitFor([&rx, offset, count]() { return rx.size() >= offset + count; }, timeoutMs);
    }
    int countOccurrences(const QByteArray &bytes, const QByteArray &needle) const {
        int count = 0, offset = 0;
        while ((offset = bytes.indexOf(needle, offset)) >= 0) { ++count; offset += needle.size(); }
        return count;
    }
    QObject *findLoopTimer(QObject *root) const {
        if (!root) return nullptr;
        const int wanted = root->property("loopInterval").toInt();
        for (QObject *child : root->findChildren<QObject *>()) {
            if (child->metaObject()->indexOfProperty("repeat") < 0
                || child->metaObject()->indexOfProperty("interval") < 0
                || child->metaObject()->indexOfProperty("running") < 0) continue;
            if (!child->property("repeat").toBool() && child->property("interval").toInt() == wanted)
                return child;
        }
        return nullptr;
    }
    void stopCommandLoop(MainInstance &instance) {
        instance.root->setProperty("loopSending", false);
        instance.root->setProperty("loopIndex", -1);
        if (QObject *timer = findLoopTimer(instance.root)) QMetaObject::invokeMethod(timer, "stop", Qt::DirectConnection);
    }

    void testDoSendAndSendCommand() {
        const int offset = rxB.size();
        mainA.root->setProperty("globalTxHex", false);
        mainA.input->setProperty("text", QStringLiteral("MAIN-DO-SEND|"));
        const bool invoked = invoke(mainA.root, "doSend");
        const QByteArray payload("MAIN-DO-SEND|");
        const bool arrived = waitRx(rxB, offset, payload.size());
        check(QStringLiteral("Main.doSend actual COM1->COM2 bytes"),
              invoked && arrived && rxB.mid(offset, payload.size()) == payload,
              QStringLiteral("bytes=%1/%2").arg(arrived ? payload.size() : rxB.size() - offset).arg(payload.size()));
        const QVariantList history = mainA.root->property("sendHistory").toList();
        check(QStringLiteral("Main.doSend records manual input history"),
              !history.isEmpty() && history.first().toString() == QStringLiteral("MAIN-DO-SEND|"));

        const int presetOffset = rxB.size();
        const bool presetInvoked = QMetaObject::invokeMethod(mainA.root, "sendCommand", Qt::DirectConnection,
            Q_RETURN_ARG(QVariant, presetResult), Q_ARG(QVariant, QVariant(QStringLiteral("PRESET|"))),
            Q_ARG(QVariant, QVariant(false)));
        const QByteArray preset("PRESET|");
        const bool presetArrived = waitRx(rxB, presetOffset, preset.size());
        check(QStringLiteral("Main.sendCommand actual preset bytes"),
              presetInvoked && presetArrived && rxB.mid(presetOffset, preset.size()) == preset,
              QStringLiteral("bytes=%1/%2").arg(presetArrived ? preset.size() : rxB.size() - presetOffset).arg(preset.size()));
    }

    void testCommandAndManualLoops() {
        mainA.commands->addGroup(QStringLiteral("QA ordered commands"));
        mainA.commands->addCommand(0, QStringLiteral("QA_A"), QStringLiteral("QA_A|"), false);
        mainA.commands->addCommand(0, QStringLiteral("QA_B"), QStringLiteral("QA_B|"), false);
        mainA.commands->addCommand(0, QStringLiteral("QA_UNSELECTED"), QStringLiteral("NO|"), false);
        QVariantMap selected; selected["0:0"] = true; selected["0:1"] = true; selected["0:2"] = false;
        mainA.root->setProperty("checkedMap", selected);
        mainA.root->setProperty("loopInterval", 45);
        mainA.root->setProperty("globalTxHex", true);
        mainA.root->setProperty("sendInterval", 95);
        mainA.input->setProperty("text", QStringLiteral("\"M;\""));

        rxB.clear(); txA = 0;
        const bool startedManual = invoke(mainA.inputSender, "toggleRepeat");
        const bool manualRunning = mainA.root->property("autoSending").toBool();
        const bool startedCommand = invoke(mainA.root, "startLoopSend");
        const bool commandRunning = mainA.root->property("loopSending").toBool();
        const bool gotMixed = waitFor([this]() {
            const int cmdA = countOccurrences(rxB, QByteArray("QA_A|"));
            const int cmdB = countOccurrences(rxB, QByteArray("QA_B|"));
            const int manual = countOccurrences(rxB, QByteArray("M;"));
            return cmdA >= 3 && cmdB >= 3 && manual >= 2;
        }, 900);
        const QByteArray manualBufferBeforeStop = mainA.input->property("text").toString().toLatin1();
        const int commandCountBefore = countOccurrences(rxB, QByteArray("QA_A|")) + countOccurrences(rxB, QByteArray("QA_B|"));
        const int manualCountBefore = countOccurrences(rxB, QByteArray("M;"));
        const QByteArray commandOnly = QByteArray(rxB).replace("M;", "");
        const bool ordered = commandOnly.startsWith("QA_A|QA_B|")
                          && countOccurrences(commandOnly, QByteArray("QA_A|")) >= 3
                          && countOccurrences(commandOnly, QByteArray("QA_B|")) >= 3
                          && !commandOnly.contains("NO|");
        const bool intervalSeparation = commandCountBefore > manualCountBefore;
        check(QStringLiteral("Main command loop iterates selected commands in library order beside manual repeat"),
              startedManual && manualRunning && startedCommand && commandRunning && gotMixed && ordered && intervalSeparation,
              QStringLiteral("A/B=%1/%2 manual=%3; ordered=%4; faster command cadence=%5")
                  .arg(countOccurrences(commandOnly, QByteArray("QA_A|")))
                  .arg(countOccurrences(commandOnly, QByteArray("QA_B|")))
                  .arg(manualCountBefore).arg(ordered).arg(intervalSeparation));
        check(QStringLiteral("manual input HEX buffer and intervals stay independent from command loop"),
              mainA.input->property("text").toString() == QStringLiteral("4D 3B")
                  && mainA.root->property("globalTxHex").toBool()
                  && mainA.root->property("sendInterval").toInt() == 95
                  && mainA.root->property("loopInterval").toInt() == 45,
              QStringLiteral("buffer=%1 txHex=%2 manualMs=%3 commandMs=%4")
                  .arg(mainA.input->property("text").toString())
                  .arg(mainA.root->property("globalTxHex").toBool())
                  .arg(mainA.root->property("sendInterval").toInt())
                  .arg(mainA.root->property("loopInterval").toInt()));

        stopCommandLoop(mainA);
        const bool commandStopped = !mainA.root->property("loopSending").toBool();
        const int postStopOffset = rxB.size();
        pumpFor(200);
        const QByteArray postCommandStop = rxB.mid(postStopOffset);
        const int postStopCmds = countOccurrences(postCommandStop, QByteArray("QA_A|"))
                               + countOccurrences(postCommandStop, QByteArray("QA_B|"));
        const int postStopManuals = countOccurrences(postCommandStop, QByteArray("M;"));
        check(QStringLiteral("stopping command-library loop leaves manual repeat running"),
              commandStopped && mainA.root->property("autoSending").toBool()
                  && postStopCmds == 0 && postStopManuals >= 1,
              QStringLiteral("post-stop commands=%1 manual=%2 running=%3 txA=%4")
                  .arg(postStopCmds).arg(postStopManuals).arg(mainA.root->property("autoSending").toBool()).arg(txA));
        const int stableOffset = rxB.size();
        invoke(mainA.inputSender, "toggleRepeat");
        const bool manualStopped = !mainA.root->property("autoSending").toBool();
        pumpFor(220);
        check(QStringLiteral("stopping manual repeat leaves command and manual traffic stable"),
              manualStopped && rxB.size() == stableOffset,
              QStringLiteral("before=%1 after=%2").arg(stableOffset).arg(rxB.size()));

        const int manualAgainOffset = rxB.size();
        mainA.root->setProperty("globalTxHex", false);
        mainA.input->setProperty("text", QStringLiteral("MANUAL-AGAIN|"));
        const bool againInvoked = invoke(mainA.root, "doSend");
        const QByteArray manualAgain("MANUAL-AGAIN|");
        const bool againArrived = waitRx(rxB, manualAgainOffset, manualAgain.size());
        check(QStringLiteral("Main.doSend works after both repeat modes stop"),
              againInvoked && againArrived && rxB.mid(manualAgainOffset, manualAgain.size()) == manualAgain,
              QStringLiteral("arrived=%1").arg(againArrived));
    }

    void testDisconnectStopsAndReconnects() {
        mainA.root->setProperty("globalTxHex", false);
        mainA.root->setProperty("loopInterval", 45);
        mainA.commands->addGroup(QStringLiteral("QA reconnect commands"));
        mainA.commands->addCommand(1, QStringLiteral("QA_RECONNECT"), QStringLiteral("RECONNECTED|"), false);
        QVariantMap checked; checked["1:0"] = true;
        mainA.root->setProperty("checkedMap", checked);
        const bool startCommand = invoke(mainA.root, "startLoopSend");
        const bool startManual = invoke(mainA.inputSender, "toggleRepeat");
        const bool hadTraffic = waitFor([this]() { return countOccurrences(rxB, QByteArray("RECONNECTED|")) >= 2; }, 600);
        mainA.serial->closePort();
        const bool commandStopped = waitFor([this]() { return !mainA.root->property("loopSending").toBool(); }, 500);
        const bool manualStopped = waitFor([this]() { return !mainA.root->property("autoSending").toBool(); }, 500);
        const int offset = rxB.size();
        QThread::msleep(200); QCoreApplication::processEvents();
        check(QStringLiteral("disconnect stops both Main command loop and SendController repeat"),
              startCommand && startManual && hadTraffic && commandStopped && manualStopped && rxB.size() == offset,
              QStringLiteral("traffic=%1 commandStopped=%2 manualStopped=%3")
                  .arg(hadTraffic).arg(commandStopped).arg(manualStopped));

        const bool reopened = mainA.serial->openPort(QStringLiteral("COM1"), 115200);
        mainA.input->setProperty("text", QStringLiteral("RECONNECT-MANUAL|"));
        const bool manualSend = invoke(mainA.root, "doSend");
        const QByteArray expected("RECONNECT-MANUAL|");
        const int reconnectOffset = rxB.size();
        const bool arrived = waitRx(rxB, reconnectOffset, expected.size());
        check(QStringLiteral("reconnect restores Main.doSend"),
              reopened && manualSend && arrived && rxB.mid(reconnectOffset, expected.size()) == expected,
              QStringLiteral("reopened=%1 arrived=%2").arg(reopened).arg(arrived));

        const int commandOffset = rxB.size();
        const bool restartedCommand = invoke(mainA.root, "startLoopSend");
        const bool commandArrived = waitRx(rxB, commandOffset, QByteArray("RECONNECTED|").size(), 600);
        stopCommandLoop(mainA);
        check(QStringLiteral("reconnect allows selected command loop to restart"),
              restartedCommand && commandArrived,
              QStringLiteral("arrived=%1").arg(commandArrived));
    }

    MainInstance mainA, mainB;
    QByteArray rxA, rxB;
    quint64 txA = 0, txB = 0;
    std::vector<CheckResult> results;
    QVariant presetResult;
};

int main(int argc, char **argv) {
    qputenv("QT_QPA_PLATFORM", "offscreen");
    qputenv("QT_QUICK_BACKEND", "software");
    QGuiApplication app(argc, argv);
    QCoreApplication::setOrganizationName(QStringLiteral("CodexSerialMainWorkflowQA"));
    QCoreApplication::setApplicationName(QStringLiteral("SerialMainWorkflowQA_BOOTSTRAP"));
    QCoreApplication::setOrganizationDomain(QStringLiteral("codex.local"));
    QStandardPaths::setTestModeEnabled(true);
    QSettings::setDefaultFormat(QSettings::IniFormat);
    const QString root = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(root);
    QSettings::setPath(QSettings::IniFormat, QSettings::UserScope, root);
    qmlRegisterUncreatableType<ChecksumHelper>("com.gemini.serial", 1, 0, "Checksum", "Enum only");

    MainWorkflowQA qa;
    const bool ready = qa.initialize();
    if (ready) qa.run();
    qa.cleanup();

    const QString outPath = QDir::current().filePath(QStringLiteral("_verify_build/main-serial-qa/serial-main-workflow-results.json"));
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
#include "serial_main_workflow_test.moc"
