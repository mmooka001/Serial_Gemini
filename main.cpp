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

// MinGW 13.1 的 dwmapi.h 缺少这些 Win11 常量，手动补上
#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE
#define DWMWA_USE_IMMERSIVE_DARK_MODE 20
#endif
#ifndef DWMWA_SYSTEMBACKDROP_TYPE
#define DWMWA_SYSTEMBACKDROP_TYPE 38
#endif
#ifndef DWMSBT_NONE
#define DWMSBT_NONE 1
#endif

// ---- 未公开 API：SetWindowCompositionAttribute（任务栏同款亚克力，激活态不退化为实色）----
typedef struct _ACCENT_POLICY {
    UINT AccentState;    // 4 = ACCENT_ENABLE_ACRYLICBLURBEHIND
    UINT AccentFlags;
    UINT GradientColor;  // AABBGGRR
    UINT AnimationId;
} ACCENT_POLICY;

typedef struct _WINDOWCOMPOSITIONATTRIBDATA {
    int   Attrib;        // 19 = WCA_ACCENT_POLICY
    void *Data;
    SIZE_T SizeOfData;
} WINDOWCOMPOSITIONATTRIBDATA;

typedef BOOL (WINAPI *SetWindowCompositionAttributeFn)(HWND, WINDOWCOMPOSITIONATTRIBDATA *);

// QML 可调用的磨砂开关：enable 绑定窗口，setTint 按主题切染色
class AcrylicHelper : public QObject {
    Q_OBJECT
public:
    Q_INVOKABLE void enable(QQuickWindow *w) {
        if (!w) return;
        m_hwnd = reinterpret_cast<HWND>(w->winId());
        apply();
    }
    Q_INVOKABLE void setTint(double r, double g, double b, double a) {
        UINT rr = UINT(qBound(0.0, r, 1.0) * 255.0);
        UINT gg = UINT(qBound(0.0, g, 1.0) * 255.0);
        UINT bb = UINT(qBound(0.0, b, 1.0) * 255.0);
        UINT aa = UINT(qBound(0.0, a, 1.0) * 255.0);
        m_gradient = (aa << 24) | (bb << 16) | (gg << 8) | rr;
        apply();
    }
private:
    void apply() {
        if (!m_hwnd) return;
        static SetWindowCompositionAttributeFn fn = []() -> SetWindowCompositionAttributeFn {
            HMODULE u32 = GetModuleHandleW(L"user32.dll");
            return reinterpret_cast<SetWindowCompositionAttributeFn>(
                GetProcAddress(u32, "SetWindowCompositionAttribute"));
        }();
        if (!fn) return;
        ACCENT_POLICY policy;
        policy.AccentState   = 4;           // ACCENT_ENABLE_ACRYLICBLURBEHIND
        policy.AccentFlags   = 0;
        policy.GradientColor = m_gradient;
        policy.AnimationId   = 0;
        WINDOWCOMPOSITIONATTRIBDATA data;
        data.Attrib      = 19;              // WCA_ACCENT_POLICY
        data.Data        = &policy;
        data.SizeOfData  = sizeof(policy);
        fn(m_hwnd, &data);
    }
    HWND m_hwnd = nullptr;
    UINT m_gradient = 0x80101014;            // 默认深色 tint (黑 50%)
};
#endif

#include "SerialManager.h"
#include "ChecksumHelper.h"
#include "CommandStore.h"
#include "SettingsStore.h"
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
    RecordStore recordStore;
#ifdef Q_OS_WIN
    AcrylicHelper acrylicHelper;
#endif

    engine.rootContext()->setContextProperty("serialManager", &serialManager);
    engine.rootContext()->setContextProperty("commandStore", &commandStore);
    engine.rootContext()->setContextProperty("ChecksumHelper", &checksumHelper);
    engine.rootContext()->setContextProperty("settingsStore", &settingsStore);
    engine.rootContext()->setContextProperty("recordStore", &recordStore);
#ifdef Q_OS_WIN
    engine.rootContext()->setContextProperty("acrylic", &acrylicHelper);
#endif

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

            // 暗色沉浸式边框
            BOOL darkMode = TRUE;
            DwmSetWindowAttribute(hwnd, DWMWA_USE_IMMERSIVE_DARK_MODE, &darkMode, sizeof(darkMode));

            // 关闭系统 backdrop（改用 SetWindowCompositionAttribute 亚克力，二者互斥）
            int backdrop = DWMSBT_NONE;
            DwmSetWindowAttribute(hwnd, DWMWA_SYSTEMBACKDROP_TYPE, &backdrop, sizeof(backdrop));

            // 刷新窗口位置
            SetWindowPos(hwnd, NULL, 0, 0, 0, 0, SWP_FRAMECHANGED | SWP_NOMOVE | SWP_NOSIZE);
        }
#endif
    }, Qt::QueuedConnection);
    engine.load(url);

    return app.exec();
}

#ifdef Q_OS_WIN
#include "main.moc"
#endif
