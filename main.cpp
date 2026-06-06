#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QUrl>
#include <QQuickWindow>

#ifdef Q_OS_WIN
#include <windows.h>
#include <dwmapi.h>
#pragma comment (lib, "dwmapi.lib")
#pragma comment (lib, "user32.lib")
#endif

#include "SerialManager.h"
#include "ChecksumHelper.h"
#include "CommandStore.h"
#include "SettingsStore.h"
#include "DataEncoder.h"
#include "RecordStore.h"

using namespace Qt::StringLiterals;

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    // 设置组织和应用名称，方便 CommandStore 定位存储路径
    app.setOrganizationName("Gemini");
    app.setApplicationName("MySerial_Gemini");

    QQmlApplicationEngine engine;

    SerialManager serialManager;
    CommandStore commandStore;
    ChecksumHelper checksumHelper;
    SettingsStore settingsStore;
    DataEncoder dataEncoder;
    RecordStore recordStore;

    engine.rootContext()->setContextProperty("serialManager", &serialManager);
    engine.rootContext()->setContextProperty("commandStore", &commandStore);
    engine.rootContext()->setContextProperty("ChecksumHelper", &checksumHelper);
    engine.rootContext()->setContextProperty("settingsStore", &settingsStore);
    engine.rootContext()->setContextProperty("dataEncoder", &dataEncoder);
    engine.rootContext()->setContextProperty("recordStore", &recordStore);

    // Connect SerialManager data to RecordStore
    QObject::connect(&serialManager, SIGNAL(dataReceived(QString,QString,bool,bool)),
                     &recordStore, SLOT(onDataReceived(QString,QString,bool)));
    
    // 注册 Checksum 类型
    qmlRegisterUncreatableType<ChecksumHelper>("com.gemini.serial", 1, 0, "Checksum", "Enum only");

    const QUrl url(u"qrc:/MySerial_Gemini/Main.qml"_s);
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     &app, [url](QObject *obj, const QUrl &objUrl) {
        if (!obj && url == objUrl)
            QCoreApplication::exit(-1);

#ifdef Q_OS_WIN
        // --- Windows 原生吸附交互 (Aero Snap) 开启逻辑 ---
        QQuickWindow *window = qobject_cast<QQuickWindow *>(obj);
        if (window) {
            HWND hwnd = (HWND)window->winId();
            
            // 获取当前样式
            LONG style = GetWindowLong(hwnd, GWL_STYLE);
            
            // 注入 ThickFrame (支持吸附) 和 Caption (支持分屏感应)
            style |= WS_THICKFRAME | WS_CAPTION | WS_MAXIMIZEBOX | WS_MINIMIZEBOX;
            SetWindowLong(hwnd, GWL_STYLE, style);

            // 启用窗口阴影
            const MARGINS shadow_margin = { 1, 1, 1, 1 };
            DwmExtendFrameIntoClientArea(hwnd, &shadow_margin);
            
            // 刷新窗口位置
            SetWindowPos(hwnd, NULL, 0, 0, 0, 0, SWP_FRAMECHANGED | SWP_NOMOVE | SWP_NOSIZE);
        }
#endif
    }, Qt::QueuedConnection);
    engine.load(url);

    return app.exec();
}
