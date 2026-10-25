#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QUrl>
#include <QQuickWindow>
#include <QPointer>
#include <QAbstractNativeEventFilter>
#include <QPlatformSurfaceEvent>
#include <QTimer>

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
#ifndef DWMWA_WINDOW_CORNER_PREFERENCE
#define DWMWA_WINDOW_CORNER_PREFERENCE 33
#endif
#ifndef DWMWA_BORDER_COLOR
#define DWMWA_BORDER_COLOR 34
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
class AcrylicHelper : public QObject, public QAbstractNativeEventFilter {
    Q_OBJECT
public:
    Q_INVOKABLE void enable(QQuickWindow *w) {
        if (!w || m_window == w) return;
        m_window = w;
        w->installEventFilter(this);
        qGuiApp->installNativeEventFilter(this);
        connect(w, &QWindow::flagsChanged, this, [this] { queueNativeRefresh(); });
        connect(w, &QWindow::visibilityChanged, this, [this] {
            QTimer::singleShot(0, this, [this] { updateFrame(); });
        });
        refreshNativeWindow();
    }
    Q_INVOKABLE void setTint(double r, double g, double b, double a) {
        UINT rr = UINT(qBound(0.0, r, 1.0) * 255.0);
        UINT gg = UINT(qBound(0.0, g, 1.0) * 255.0);
        UINT bb = UINT(qBound(0.0, b, 1.0) * 255.0);
        UINT aa = UINT(qBound(0.0, a, 1.0) * 255.0);
        m_gradient = (aa << 24) | (bb << 16) | (gg << 8) | rr;
        apply();
    }
    bool nativeEventFilter(const QByteArray &eventType, void *message, qintptr *result) override {
        if (eventType != "windows_generic_MSG" || !m_window)
            return false;
        const auto *msg = static_cast<MSG *>(message);
        if (msg->hwnd != m_hwnd || msg->message != WM_NCCALCSIZE || !msg->wParam
            || !IsZoomed(m_hwnd) || m_window->visibility() == QWindow::FullScreen)
            return false;

        MONITORINFO monitorInfo = {};
        monitorInfo.cbSize = sizeof(monitorInfo);
        if (!GetMonitorInfoW(MonitorFromWindow(m_hwnd, MONITOR_DEFAULTTONEAREST), &monitorInfo))
            return false;
        // 最大化窗口的外框可延伸到屏幕外，客户区必须限制在当前显示器工作区内。
        auto *params = reinterpret_cast<NCCALCSIZE_PARAMS *>(msg->lParam);
        const RECT &proposed = params->rgrc[0];
        const RECT &work = monitorInfo.rcWork;
        if (proposed.right - proposed.left < work.right - work.left
            || proposed.bottom - proposed.top < work.bottom - work.top)
            return false;
        params->rgrc[0] = work;
        *result = 0;
        return true;
    }
    bool eventFilter(QObject *object, QEvent *event) override {
        if (object == m_window && event->type() == QEvent::PlatformSurface) {
            const auto *surface = static_cast<QPlatformSurfaceEvent *>(event);
            if (surface->surfaceEventType() == QPlatformSurfaceEvent::SurfaceAboutToBeDestroyed)
                m_hwnd = nullptr;
            else
                queueNativeRefresh();
        }
        return QObject::eventFilter(object, event);
    }
private:
    void queueNativeRefresh() {
        if (m_refreshPending) return;
        m_refreshPending = true;
        QTimer::singleShot(0, this, [this] {
            m_refreshPending = false;
            refreshNativeWindow();
        });
    }
    void refreshNativeWindow() {
        if (!m_window) return;
        HWND hwnd = reinterpret_cast<HWND>(m_window->winId());
        if (m_hwnd != hwnd) {
            m_hwnd = hwnd;
            m_cornerPreference = -1;
            BOOL darkMode = TRUE;
            DwmSetWindowAttribute(m_hwnd, DWMWA_USE_IMMERSIVE_DARK_MODE, &darkMode, sizeof(darkMode));
            int backdrop = DWMSBT_NONE;
            DwmSetWindowAttribute(m_hwnd, DWMWA_SYSTEMBACKDROP_TYPE, &backdrop, sizeof(backdrop));
            const COLORREF noBorder = 0xFFFFFFFE;
            DwmSetWindowAttribute(m_hwnd, DWMWA_BORDER_COLOR, &noBorder, sizeof(noBorder));
        }
        const LONG style = GetWindowLongW(m_hwnd, GWL_STYLE);
        const LONG wanted = style | WS_THICKFRAME | WS_CAPTION | WS_MAXIMIZEBOX | WS_MINIMIZEBOX;
        if (style != wanted) {
            SetWindowLongW(m_hwnd, GWL_STYLE, wanted);
            SetWindowPos(m_hwnd, nullptr, 0, 0, 0, 0,
                         SWP_FRAMECHANGED | SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE);
        }
        updateFrame();
        apply();
        m_window->requestUpdate();
    }
    void updateFrame() {
        if (!m_window || !m_hwnd) return;
        const bool edgeToEdge = m_window->visibility() == QWindow::Maximized
                            || m_window->visibility() == QWindow::FullScreen;
        const int cornerPreference = edgeToEdge ? 1 : 2; // DWMWCP_DONOTROUND / DWMWCP_ROUND
        if (cornerPreference == m_cornerPreference) return;
        m_cornerPreference = cornerPreference;
        DwmSetWindowAttribute(m_hwnd, DWMWA_WINDOW_CORNER_PREFERENCE,
                              &cornerPreference, sizeof(cornerPreference));
        const int inset = edgeToEdge ? 0 : 1;
        const MARGINS margins = { inset, inset, inset, inset };
        DwmExtendFrameIntoClientArea(m_hwnd, &margins);
    }

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
    bool m_refreshPending = false;
    int m_cornerPreference = -1;
    HWND m_hwnd = nullptr;
    QPointer<QQuickWindow> m_window;
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
    serialManager.setDataEncoding(settingsStore.dataEncoding());
    QObject::connect(&settingsStore, &SettingsStore::dataEncodingChanged, &serialManager, [&] {
        serialManager.setDataEncoding(settingsStore.dataEncoding());
    });
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

    }, Qt::QueuedConnection);
    engine.load(url);

    return app.exec();
}

#ifdef Q_OS_WIN
#include "main.moc"
#endif
