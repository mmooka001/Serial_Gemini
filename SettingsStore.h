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
    Q_PROPERTY(int configPanelWidth READ configPanelWidth WRITE setConfigPanelWidth NOTIFY configPanelWidthChanged)
    Q_PROPERTY(int featurePanelWidth READ featurePanelWidth WRITE setFeaturePanelWidth NOTIFY featurePanelWidthChanged)
    Q_PROPERTY(int themeMode READ themeMode WRITE setThemeMode NOTIFY themeModeChanged)

public:
    explicit SettingsStore(QObject *parent = nullptr) : QObject(parent) {
        QSettings s;
        m_lineEndingMode = s.value("settings/lineEndingMode", 0).toInt();
        m_dataEncoding = s.value("settings/dataEncoding", "UTF-8").toString();
        m_hasDecimalMode = s.value("settings/hasDecimalMode", false).toBool();
        m_configPanelWidth = s.value("settings/configPanelWidth", 260).toInt();
        m_featurePanelWidth = s.value("settings/featurePanelWidth", 300).toInt();
        m_themeMode = s.value("settings/themeMode", 4).toInt(); // Default to 4 (Classic Dark)
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

    int configPanelWidth() const { return m_configPanelWidth; }
    void setConfigPanelWidth(int width) {
        if (m_configPanelWidth != width) {
            m_configPanelWidth = width;
            QSettings s; s.setValue("settings/configPanelWidth", width);
            emit configPanelWidthChanged();
        }
    }

    int featurePanelWidth() const { return m_featurePanelWidth; }
    void setFeaturePanelWidth(int width) {
        if (m_featurePanelWidth != width) {
            m_featurePanelWidth = width;
            QSettings s; s.setValue("settings/featurePanelWidth", width);
            emit featurePanelWidthChanged();
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
    void lineEndingModeChanged();
    void dataEncodingChanged();
    void hasDecimalModeChanged();
    void configPanelWidthChanged();
    void featurePanelWidthChanged();
    void themeModeChanged();

private:
    int m_lineEndingMode;
    QString m_dataEncoding;
    bool m_hasDecimalMode;
    int m_configPanelWidth;
    int m_featurePanelWidth;
    int m_themeMode;
};

#endif // SETTINGSSTORE_H
