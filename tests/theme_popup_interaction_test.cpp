#include <QDateTime>
#include <QClipboard>
#include <QGuiApplication>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMetaProperty>
#include <QQuickItem>
#include <QQuickWindow>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QSerialPort>
#include <QStandardPaths>
#include <QSettings>
#include <QTest>
#include <QThread>
#include <QElapsedTimer>
#include <iostream>
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

struct Check { QString name; bool passed; QString detail; };

class ThemePopupInteractionTest {
public:
    ThemePopupInteractionTest() {
        QCoreApplication::setOrganizationName(QStringLiteral("CodexThemePopupQA"));
        QCoreApplication::setOrganizationDomain(QStringLiteral("codex.local"));
        QCoreApplication::setApplicationName(QStringLiteral("ThemePopupInteractionQA"));
        const QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
        QDir().mkpath(dir);
        QSettings::setPath(QSettings::IniFormat, QSettings::UserScope, dir);
        serial.setDataEncoding(QStringLiteral("UTF-8"));
        engine.rootContext()->setContextProperty(QStringLiteral("serialManager"), &serial);
        engine.rootContext()->setContextProperty(QStringLiteral("commandStore"), &commands);
        engine.rootContext()->setContextProperty(QStringLiteral("ChecksumHelper"), &checksum);
        engine.rootContext()->setContextProperty(QStringLiteral("settingsStore"), &settings);
        engine.rootContext()->setContextProperty(QStringLiteral("recordStore"), &records);
        engine.rootContext()->setContextProperty(QStringLiteral("acrylic"), &acrylic);
        QObject::connect(&serial, &SerialManager::dataReceived, &records,
            [this](const QString &ascii, const QString &hex, bool isSent, bool) {
                records.onDataReceived(ascii, hex, isSent);
            });
    }

    void check(const QString &name, bool passed, const QString &detail = {}) {
        results.push_back({name, passed, detail});
        std::cout << (passed ? "PASS " : "FAIL ") << name.toStdString();
        if (!detail.isEmpty()) std::cout << " - " << detail.toStdString();
        std::cout << std::endl;
    }

    int run() {
        qmlRegisterUncreatableType<ChecksumHelper>("com.gemini.serial", 1, 0, "Checksum", "Enum only");
        engine.loadFromModule(QStringLiteral("MySerial_Gemini"), QStringLiteral("Main"));
        pump(250);
        const auto roots = engine.rootObjects();
        window = roots.isEmpty() ? nullptr : qobject_cast<QQuickWindow *>(roots.first());
        QObject *buttonObject = window ? window->findChild<QObject *>(QStringLiteral("themeToggleButton")) : nullptr;
        button = qobject_cast<QQuickItem *>(buttonObject);
        popup = window ? window->findChild<QObject *>(QStringLiteral("themeAppearancePopup")) : nullptr;
        check(QStringLiteral("full production Main.qml loads offscreen with theme button and popup"),
              window && button && popup,
              QStringLiteral("window=%1 button=%2 popup=%3 serialAOpen=%4")
                  .arg(bool(window)).arg(bool(button)).arg(bool(popup)).arg(serial.isOpen()));
        if (!window || !button || !popup) return failures();

        const bool invoked = QMetaObject::invokeMethod(buttonObject, "clicked", Qt::DirectConnection);
        pump(150);
        const Geometry first = geometry();
        check(QStringLiteral("direct clicked signal opens theme appearance popup"),
              invoked && popup->property("visible").toBool() && popup->property("opened").toBool(),
              stateDetail(first));
        check(QStringLiteral("opened popup has usable nonzero geometry within the window"),
              first.width > 0 && first.height > 0 && first.contentX >= 0 && first.contentY >= 0
                  && first.contentX + first.width <= window->contentItem()->width() + 2
                  && first.contentY + first.height <= window->contentItem()->height() + 2,
              stateDetail(first));

        const QPoint clickPos = button->mapToItem(window->contentItem(),
            QPointF(button->width() / 2.0, button->height() / 2.0)).toPoint();
        QTest::mouseClick(window, Qt::LeftButton, Qt::NoModifier, clickPos);
        pump(150);
        check(QStringLiteral("first real mouse click on theme button closes open popup"),
              !popup->property("visible").toBool() && !popup->property("opened").toBool(),
              QStringLiteral("button center=(%1,%2); %3").arg(clickPos.x()).arg(clickPos.y()).arg(stateDetail(geometry())));

        QTest::mouseClick(window, Qt::LeftButton, Qt::NoModifier, clickPos);
        pump(150);
        const Geometry reopened = geometry();
        check(QStringLiteral("second real mouse click on theme button reopens popup"),
              popup->property("visible").toBool() && popup->property("opened").toBool(),
              QStringLiteral("button center=(%1,%2); %3").arg(clickPos.x()).arg(clickPos.y()).arg(stateDetail(reopened)));
        check(QStringLiteral("popup remains inside its window after repeated clicks"),
              reopened.width > 0 && reopened.height > 0 && reopened.contentX >= 0 && reopened.contentY >= 0
                  && reopened.contentX + reopened.width <= window->contentItem()->width() + 2
                  && reopened.contentY + reopened.height <= window->contentItem()->height() + 2,
              stateDetail(reopened));

        const QPoint outsidePopup(window->width() / 5, window->height() / 2);
        QTest::mouseClick(window, Qt::LeftButton, Qt::NoModifier, outsidePopup);
        pump(150);
        check(QStringLiteral("real outside click closes the theme popup"),
              !popup->property("visible").toBool() && !popup->property("opened").toBool(),
              QStringLiteral("outside point=(%1,%2); %3")
                  .arg(outsidePopup.x()).arg(outsidePopup.y()).arg(stateDetail(geometry())));
        check(QStringLiteral("theme popup test did not open a serial port"), !serial.isOpen());

        if (popup->property("opened").toBool()) QMetaObject::invokeMethod(popup, "close", Qt::DirectConnection);

        // Exercise selection through the actual production Main.qml delegate hierarchy.
        // Keep the serial backend closed; emitting the production signal only feeds the QML model.
        const QString xml = QStringLiteral("<b>QA-COPY-01</b>");
        window->setProperty("globalRxHex", false);
        emit serial.dataReceived(xml, QString::fromLatin1(xml.toUtf8().toHex(' ').toUpper()), false, false);
        pump(250);
        for (QObject *obj : window->findChildren<QObject *>()) {
            if (QString::fromLatin1(obj->metaObject()->className()).contains(QStringLiteral("QQuickListView"))
                && obj->property("count").toInt() > 0)
                QMetaObject::invokeMethod(obj, "positionViewAtEnd", Qt::DirectConnection);
        }
        pump(200);
        QObject *editorObject = window->findChild<QObject *>(QStringLiteral("terminalTextEditor"));
        for (QObject *obj : window->findChildren<QObject *>()) {
            if (!QString::fromLatin1(obj->metaObject()->className()).contains(QStringLiteral("QQuickListView"))
                || obj->property("count").toInt() < 1) continue;
            QQuickItem *row = nullptr;
            QMetaObject::invokeMethod(obj, "itemAtIndex", Qt::DirectConnection,
                                      Q_RETURN_ARG(QQuickItem *, row), Q_ARG(int, obj->property("count").toInt() - 1));
            if (row) {
                QObject *nestedEditor = row->findChild<QObject *>(QStringLiteral("terminalTextEditor"));
                if (nestedEditor) { editorObject = nestedEditor; break; }
            }
        }
        QString modelState;
        const auto descendants = window->findChildren<QObject *>();
        for (QObject *obj : descendants) {
            const QString cls = QString::fromLatin1(obj->metaObject()->className());
            if (cls.contains(QStringLiteral("ListView")) || cls.contains(QStringLiteral("ListModel"))) {
                QObject *modelObject = obj->property("model").value<QObject *>();
                modelState += QStringLiteral(" [%1 name=%2 count=%3 model=%4]")
                    .arg(cls, obj->objectName())
                    .arg(obj->property("count").toInt())
                    .arg(modelObject ? QString::fromLatin1(modelObject->metaObject()->className()) : QStringLiteral("null"));
            }
        }
        QQuickItem *editor = qobject_cast<QQuickItem *>(editorObject);
        QObject *inputObject = window->findChild<QObject *>(QStringLiteral("sendMessageInput"));
        QQuickItem *input = qobject_cast<QQuickItem *>(inputObject);
        const QString shownText = editorObject ? editorObject->property("text").toString() : QString();
        check(QStringLiteral("production RX signal renders XML as literal TXT in terminal editor"),
              editor && input && shownText == xml,
              QStringLiteral("editor=%1 text=%2 input=%3 serialOpen=%4")
                  .arg(bool(editor)).arg(shownText).arg(bool(input)).arg(serial.isOpen()) + modelState);

        if (editor && input) {
            const QPoint start = editor->mapToItem(window->contentItem(), QPointF(2, editor->height() / 2)).toPoint();
            const QPoint end = editor->mapToItem(window->contentItem(), QPointF(editor->width() - 2, editor->height() / 2)).toPoint();
            QTest::mousePress(window, Qt::LeftButton, Qt::NoModifier, start);
            QTest::mouseMove(window, end, 120);
            QTest::mouseRelease(window, Qt::LeftButton, Qt::NoModifier, end);
            pump(100);
            const QString dragged = editorObject->property("selectedText").toString();
            const bool dragFocus = editorObject->property("activeFocus").toBool();
            const int selStart = editorObject->property("selectionStart").toInt();
            const int selEnd = editorObject->property("selectionEnd").toInt();
            check(QStringLiteral("real mouse drag selects terminal text under full Main layout"),
                  !dragged.isEmpty(),
                  QStringLiteral("selected=%1 activeFocus=%2 selection=%3..%4 editor=(%5,%6 %7x%8) drag=(%9,%10)->(%11,%12)")
                      .arg(dragged).arg(dragFocus).arg(selStart).arg(selEnd)
                      .arg(editor->x()).arg(editor->y()).arg(editor->width()).arg(editor->height())
                      .arg(start.x()).arg(start.y()).arg(end.x()).arg(end.y()));

            QTest::mouseClick(window, Qt::LeftButton, Qt::NoModifier,
                              editor->mapToItem(window->contentItem(), QPointF(editor->width() / 2, editor->height() / 2)).toPoint());
            QTest::keyClick(window, Qt::Key_A, Qt::ControlModifier);
            QTest::keyClick(window, Qt::Key_C, Qt::ControlModifier);
            pump(100);
            const QString clipboardText = QGuiApplication::clipboard()->text();
            check(QStringLiteral("Ctrl+A and Ctrl+C copy the complete literal XML"),
                  clipboardText == xml,
                  QStringLiteral("clipboard=%1 activeFocus=%2 selected=%3")
                      .arg(clipboardText).arg(editorObject->property("activeFocus").toBool())
                      .arg(editorObject->property("selectedText").toString()));

            inputObject->setProperty("text", QString());
            const QPoint inputCenter = input->mapToItem(window->contentItem(), QPointF(input->width() / 2, input->height() / 2)).toPoint();
            QTest::mouseClick(window, Qt::LeftButton, Qt::NoModifier, inputCenter);
            QTest::keyClick(window, Qt::Key_V, Qt::ControlModifier);
            pump(100);
            const QString pasted = inputObject->property("text").toString();
            check(QStringLiteral("Ctrl+V pastes the copied literal into the send input"), pasted == xml,
                  QStringLiteral("pasted=%1 inputFocus=%2 input=(%3,%4 %5x%6) clipboard=%7")
                      .arg(pasted).arg(inputObject->property("activeFocus").toBool())
                      .arg(input->x()).arg(input->y()).arg(input->width()).arg(input->height()).arg(clipboardText));
        }
        check(QStringLiteral("terminal selection test did not open a serial port"), !serial.isOpen());
        serial.closePort();
        pump(50);
        return failures();
    }

    QJsonObject json() const {
        QJsonArray cases;
        for (const auto &r : results) {
            QJsonObject item; item["name"] = r.name; item["passed"] = r.passed; item["detail"] = r.detail; cases.append(item);
        }
        int failed = failures();
        QJsonObject root; root["suite"] = "theme_popup_interaction_and_terminal_selection";
        root["timestampUtc"] = QDateTime::currentDateTimeUtc().toString(Qt::ISODate);
        root["platform"] = "offscreen"; root["serialPortsOpened"] = false;
        root["passed"] = int(results.size()) - failed; root["failed"] = failed; root["cases"] = cases;
        return root;
    }
    int failures() const { int f=0; for (const auto &r : results) if (!r.passed) ++f; return f; }
    int passed() const { return int(results.size()) - failures(); }

private:
    struct Geometry { double x=0,y=0,width=0,height=0,contentX=0,contentY=0; QString parentClass; };
    Geometry geometry() const {
        Geometry g;
        if (!popup || !window) return g;
        g.x = popup->property("x").toDouble(); g.y = popup->property("y").toDouble();
        g.width = popup->property("width").toDouble(); g.height = popup->property("height").toDouble();
        QObject *parentObject = popup->property("parent").value<QObject *>();
        QQuickItem *contentItem = qobject_cast<QQuickItem *>(popup->property("contentItem").value<QObject *>());
        if (contentItem) {
            const QPointF mapped = contentItem->mapToItem(window->contentItem(), QPointF(0, 0));
            g.contentX = mapped.x(); g.contentY = mapped.y();
        }
        g.parentClass = parentObject ? QString::fromLatin1(parentObject->metaObject()->className()) : QStringLiteral("null");
        return g;
    }
    QString stateDetail(const Geometry &g) const {
        return QStringLiteral("visible=%1 opened=%2 x=%3 y=%4 w=%5 h=%6 actualContent=(%7,%8) parent=%9 window=%10x%11")
            .arg(popup && popup->property("visible").toBool()).arg(popup && popup->property("opened").toBool())
            .arg(g.x).arg(g.y).arg(g.width).arg(g.height).arg(g.contentX).arg(g.contentY).arg(g.parentClass)
            .arg(window ? window->contentItem()->width() : 0).arg(window ? window->contentItem()->height() : 0);
    }
    void pump(int ms) {
        QElapsedTimer timer; timer.start();
        while (timer.elapsed() < ms) { QCoreApplication::processEvents(); QThread::msleep(1); }
        QCoreApplication::processEvents();
    }

    SerialManager serial;
    CommandStore commands;
    SettingsStore settings;
    RecordStore records;
    ChecksumHelper checksum;
    AcrylicHelper acrylic;
    QQmlApplicationEngine engine;
    QQuickWindow *window = nullptr;
    QQuickItem *button = nullptr;
    QObject *popup = nullptr;
    std::vector<Check> results;
};

int main(int argc, char **argv) {
    qputenv("QT_QPA_PLATFORM", "offscreen");
    qputenv("QT_QUICK_BACKEND", "software");
    QGuiApplication app(argc, argv);
    QCoreApplication::setOrganizationName(QStringLiteral("CodexThemePopupQA"));
    QCoreApplication::setOrganizationDomain(QStringLiteral("codex.local"));
    QCoreApplication::setApplicationName(QStringLiteral("ThemePopupInteractionQA"));
    QStandardPaths::setTestModeEnabled(true);
    QSettings::setDefaultFormat(QSettings::IniFormat);
    ThemePopupInteractionTest test;
    test.run();
    const QString outPath = QDir::current().filePath(QStringLiteral("_verify_build/theme-popup-qa/terminal-selection-results.json"));
    QDir().mkpath(QFileInfo(outPath).absolutePath());
    QFile out(outPath);
    if (!out.open(QIODevice::WriteOnly | QIODevice::Truncate)) return 2;
    out.write(QJsonDocument(test.json()).toJson(QJsonDocument::Indented));
    std::cout << "SUMMARY passed=" << test.passed() << " failed=" << test.failures()
              << " results=" << outPath.toStdString() << std::endl;
    return test.failures() ? 1 : 0;
}
#include "theme_popup_interaction_test.moc"
