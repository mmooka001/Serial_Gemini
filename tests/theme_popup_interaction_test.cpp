#include <QDateTime>
#include <QClipboard>
#include <QGuiApplication>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMetaProperty>
#include <QQuickItem>
#include <QQuickWindow>
#include <QQuickTextDocument>
#include <QTextCursor>
#include <QTextDocument>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QSerialPort>
#include <QStandardPaths>
#include <QSettings>
#include <QTest>
#include <QThread>
#include <QElapsedTimer>
#include <QTemporaryDir>
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
            check(QStringLiteral("status shows the encoded byte count for the terminal selection"),
                  window->property("selectedBytes").toInt() == xml.toUtf8().size());

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

            window->setProperty("globalTxHex", false);
            inputObject->setProperty("text", QStringLiteral("abc"));
            inputObject->setProperty("cursorPosition", 3);
            QTest::keyClick(window, Qt::Key_Return);
            check(QStringLiteral("Enter attempts to send without inserting a newline"),
                  inputObject->property("text").toString() == QStringLiteral("abc"));
            auto *notice = window->findChild<QQuickItem *>("sendNotice");
            check(QStringLiteral("send warning sits above a top-aligned editor"),
                  notice && notice->property("text").toString() == QStringLiteral("请先连接串口。")
                  && notice->mapToScene(QPointF()).y() < input->mapToScene(QPointF()).y()
                  && inputObject->property("verticalAlignment").toInt() == Qt::AlignTop);
            QTest::keyClick(window, Qt::Key_Return, Qt::ShiftModifier);
            check(QStringLiteral("Shift+Enter inserts a newline"),
                  inputObject->property("text").toString() == QStringLiteral("abc\n"));
        }
        check(QStringLiteral("terminal clear resets record count and counters"),
              QMetaObject::invokeMethod(window, "clearTerminal") && records.recordCount() == 0
              && records.rxCount() == 0 && records.txCount() == 0);
        auto *navigation = window->findChild<QQuickItem *>("toolNavigation");
        if (navigation) {
            const QPoint compareButton = navigation->mapToScene(
                QPointF(navigation->width() / 2, 2 * 52 + 24)).toPoint();
            QTest::mouseClick(window, Qt::LeftButton, Qt::NoModifier, compareButton);
        }
        pump(150);
        check(QStringLiteral("the third navigation button opens comparison on a real click"),
              window->property("sidePanel").toInt() == 4);
        auto *compare = window->findChild<QQuickItem *>("compareWorkspace");
        auto *left = window->findChild<QQuickItem *>("compareInputA");
        auto *right = window->findChild<QQuickItem *>("compareInputB");
        auto *result = window->findChild<QQuickItem *>("compareResultText");
        auto *quickDocument = result ? result->property("textDocument").value<QQuickTextDocument *>() : nullptr;
        QTextDocument *document = quickDocument ? quickDocument->textDocument() : nullptr;
        if (compare && left && right && result && document) {
            const auto backgroundAt = [document](int position) {
                QTextCursor cursor(document);
                cursor.setPosition(position + 1);
                return cursor.charFormat().background();
            };
            left->setProperty("text", "ABCDEF");
            right->setProperty("text", QString());
            const QPoint inputB = right->mapToScene(QPointF(14, 14)).toPoint();
            QTest::mouseClick(window, Qt::LeftButton, Qt::NoModifier, inputB);
            QGuiApplication::clipboard()->setText(QStringLiteral("ABxyCDEF"));
            QTest::keyClick(window, Qt::Key_V, Qt::ControlModifier);
            pump(230);
            check(QStringLiteral("editing either input updates the comparison automatically"),
                  compare->isVisible() && left->isVisible() && right->isVisible()
                  && left->mapToScene(QPointF()).x() < compare->mapToScene(QPointF()).x()
                  && left->mapToScene(QPointF()).y() < right->mapToScene(QPointF()).y()
                  && document->toPlainText() == QStringLiteral("ABCDEF\nxy"), document->toPlainText());
            check(QStringLiteral("inserted text is highlighted beneath the intact A line"),
                  backgroundAt(0).style() == Qt::NoBrush
                  && backgroundAt(5).style() == Qt::NoBrush
                  && backgroundAt(7).color() == QColor(compare->property("addedBackground").toString()));

            const QString original = QStringLiteral("  <A>&\n\nold\ntail");
            left->setProperty("text", original);
            right->setProperty("text", QStringLiteral("  <A>&\n\nnew\ntail"));
            pump(230);
            check(QStringLiteral("replacement keeps all of A verbatim and marks both changed spans"),
                  document->toPlainText() == QStringLiteral("  <A>&\n\nold\nnew\ntail")
                  && backgroundAt(8).color() == QColor(compare->property("removedBackground").toString())
                  && backgroundAt(12).color() == QColor(compare->property("addedBackground").toString()),
                  document->toPlainText());

            right->setProperty("text", original);
            pump(230);
            check(QStringLiteral("matching text leaves the entire original visible without highlights"),
                  document->toPlainText() == original && backgroundAt(8).style() == Qt::NoBrush
                  && compare->property("summary").toString() == QStringLiteral("两份内容一致"));

            const QString whitespace = QStringLiteral("\n  x\t  \n");
            left->setProperty("text", whitespace);
            right->setProperty("text", whitespace);
            pump(230);
            check(QStringLiteral("leading and trailing line breaks, spaces and tabs stay visible"),
                  document->toPlainText() == whitespace);

            const QString countedText = QStringLiteral("中\nA");
            left->setProperty("text", countedText);
            right->setProperty("text", countedText);
            pump(230);
            result->forceActiveFocus();
            QTest::keyClick(window, Qt::Key_A, Qt::ControlModifier);
            const QString encoding = settings.dataEncoding();
            settings.setDataEncoding(QStringLiteral("UTF-8"));
            const bool utf8Count = window->property("hasByteSelection").toBool()
                && window->property("selectedBytes").toInt() == 5;
            settings.setDataEncoding(QStringLiteral("GBK"));
            check(QStringLiteral("comparison result selection counts encoded bytes including line breaks"),
                  utf8Count && window->property("selectedBytes").toInt() == 4);
            settings.setDataEncoding(encoding);

            const QString commonLines = QStringLiteral("unchanged line\n").repeated(120);
            left->setProperty("text", commonLines + "old");
            right->setProperty("text", commonLines + "new");
            pump(230);
            for (const auto *name : {"compareInputAScrollBar", "compareInputBScrollBar", "compareResultScrollBar"}) {
                auto *bar = window->findChild<QQuickItem *>(name);
                bool scrolled = false;
                if (bar && bar->isVisible() && bar->property("size").toReal() < 1) {
                    const QPoint bottom = bar->mapToScene(QPointF(bar->width() / 2, bar->height() - 8)).toPoint();
                    QTest::mouseClick(window, Qt::LeftButton, Qt::NoModifier, bottom);
                    pump(60);
                    scrolled = bar->property("position").toReal() > 0;
                }
                check(QStringLiteral("%1 scrolls long text on click").arg(QString::fromLatin1(name)), scrolled,
                      bar ? QStringLiteral("visible=%1 size=%2 position=%3 geometry=%4,%5 %6x%7")
                                .arg(bar->isVisible()).arg(bar->property("size").toReal()).arg(bar->property("position").toReal())
                                .arg(bar->mapToScene(QPointF()).x()).arg(bar->mapToScene(QPointF()).y())
                                .arg(bar->width()).arg(bar->height()) : QStringLiteral("missing"));
            }
        } else {
            check(QStringLiteral("comparison workspace and its editors are available"), false);
        }
        window->setProperty("sidePanel", 3);
        pump(160);
        auto *interfaceSize = window->findChild<QQuickItem *>("interfaceSizeInput");
        auto *contentSize = window->findChild<QQuickItem *>("contentSizeInput");
        auto *contentUp = window->findChild<QQuickItem *>("contentSizeInputUp");
        auto *contentDown = window->findChild<QQuickItem *>("contentSizeInputDown");
        auto *port = window->findChild<QQuickItem *>("connectionPortSelector");
        auto *commandFile = window->findChild<QQuickItem *>("commandFileSelector");
        if (interfaceSize && contentSize && contentUp && contentDown && port && commandFile && input) {
            const auto enterSize = [&](QQuickItem *field, const QString &value) {
                field->forceActiveFocus();
                field->setProperty("text", value);
                QTest::keyClick(window, Qt::Key_Return);
                pump(50);
            };
            const int originalInterface = window->property("interfaceTextSize").toInt();
            const int originalSend = input->property("font").value<QFont>().pixelSize();
            const int originalContent = window->property("contentTextSize").toInt();
            enterSize(interfaceSize, "20");
            check(QStringLiteral("interface size scales the port dropdown without changing message fonts"),
                  window->property("interfaceTextSize").toInt() == 20
                  && port->property("font").value<QFont>().pixelSize() == qRound(13.0 * 20 / 14)
                  && input->property("font").value<QFont>().pixelSize() == originalSend);
            enterSize(contentSize, "18");
            const auto clickArrow = [&](QQuickItem *arrow) {
                const QPoint point = arrow->mapToScene(QPointF(arrow->width()/2, arrow->height()/2)).toPoint();
                QTest::mouseClick(window, Qt::LeftButton, Qt::NoModifier, point);
                pump(40);
            };
            clickArrow(contentUp);
            const int raisedSize = input->property("font").value<QFont>().pixelSize();
            clickArrow(contentDown);
            check(QStringLiteral("data font arrows step the shared size and persist it"),
                  raisedSize == 19 && input->property("font").value<QFont>().pixelSize() == 18
                  && settings.uiPreference("contentTextSize", 0).toInt() == 18);
            enterSize(interfaceSize, "14");
            check(QStringLiteral("commands use the equivalent of the former 15 px scale at 14 px"),
                  commandFile->property("font").value<QFont>().pixelSize() == qRound(12.0 * 15 / 14));
            window->setProperty("interfaceTextSize", originalInterface);
            window->setProperty("contentTextSize", originalContent);
        } else {
            check(QStringLiteral("font settings and their target controls are present"), false);
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
    QTemporaryDir commandDirectory;
    CommandStore commands{nullptr, commandDirectory.path()};
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
    qputenv("QT_QUICK_CONTROLS_STYLE", "Basic");
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
