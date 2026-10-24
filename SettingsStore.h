#ifndef SETTINGSSTORE_H
#define SETTINGSSTORE_H

#include <QObject>
#include <QSettings>

class SettingsStore : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int lineEndingMode READ lineEndingMode WRITE setLineEndingMode NOTIFY lineEndingModeChanged)
    Q_PROPERTY(QString dataEncoding READ dataEncoding WRITE setDataEncoding NOTIFY dataEncodingChanged)
    Q_PROPERTY(bool hasDecimalMode READ hasDecimalMode WRITE setHasDecimalMode NOTIFY hasDecimalModeChanged)
    Q_PROPERTY(int sidePanelWidth READ sidePanelWidth WRITE setSidePanelWidth NOTIFY sidePanelWidthChanged)
    Q_PROPERTY(int themeMode READ themeMode WRITE setThemeMode NOTIFY themeModeChanged)
    Q_PROPERTY(int colorStyle READ colorStyle WRITE setColorStyle NOTIFY colorStyleChanged)

public:
    explicit SettingsStore(QObject *parent = nullptr) : QObject(parent) {
        QSettings s;
        m_lineEndingMode = s.value("settings/lineEndingMode", 0).toInt();
        m_dataEncoding = s.value("settings/dataEncoding", "UTF-8").toString();
        m_hasDecimalMode = s.value("settings/hasDecimalMode", false).toBool();
        m_sidePanelWidth = s.value("settings/sidePanelWidth", 300).toInt();
        m_themeMode = s.value("settings/themeMode", 4).toInt(); // Default to 4 (Classic Dark)
        m_colorStyle = qBound(0, s.value("settings/colorStyle", 2).toInt(), 3);
    }

    int lineEndingMode() const { return m_lineEndingMode; }
    void setLineEndingMode(int mode) {
        if (m_lineEndingMode != mode) {
            m_lineEndingMode = mode;
            QSettings s; s.setValue("settings/lineEndingMode", mode);
            emit lineEndingModeChanged();
        }
    }

    QString dataEncoding() const { return m_dataEncoding; }
    void setDataEncoding(const QString &encoding) {
        if (m_dataEncoding != encoding) {
            m_dataEncoding = encoding;
            QSettings s; s.setValue("settings/dataEncoding", encoding);
            emit dataEncodingChanged();
        }
    }

    bool hasDecimalMode() const { return m_hasDecimalMode; }
    void setHasDecimalMode(bool on) {
        if (m_hasDecimalMode != on) {
            m_hasDecimalMode = on;
            QSettings s; s.setValue("settings/hasDecimalMode", on);
            emit hasDecimalModeChanged();
        }
    }

    int sidePanelWidth() const { return m_sidePanelWidth; }
    void setSidePanelWidth(int width) {
        if (m_sidePanelWidth != width) {
            m_sidePanelWidth = width;
            QSettings s; s.setValue("settings/sidePanelWidth", width);
            emit sidePanelWidthChanged();
        }
    }

    int colorStyle() const { return m_colorStyle; }
    void setColorStyle(int style) {
        style = qBound(0, style, 3);
        if (m_colorStyle != style) {
            m_colorStyle = style;
            QSettings s; s.setValue("settings/colorStyle", style);
            emit colorStyleChanged();
        }
    }

    int themeMode() const { return m_themeMode; }
    void setThemeMode(int mode) {
        if (m_themeMode != mode) {
            m_themeMode = mode;
            QSettings s; s.setValue("settings/themeMode", mode);
            emit themeModeChanged();
        }
    }

signals:
    void colorStyleChanged();
    void lineEndingModeChanged();
    void dataEncodingChanged();
    void hasDecimalModeChanged();
    void sidePanelWidthChanged();
    void themeModeChanged();

private:
    int m_colorStyle;
    int m_lineEndingMode;
    QString m_dataEncoding;
    bool m_hasDecimalMode;
    int m_sidePanelWidth;
    int m_themeMode;
};

#endif // SETTINGSSTORE_H
