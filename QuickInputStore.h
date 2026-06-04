#ifndef QUICKINPUTSTORE_H
#define QUICKINPUTSTORE_H

#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QFile>
#include <QStandardPaths>
#include <QDir>
#include <QUrl>
#include <QFileInfo>
#include <QTimer>
#include "SerialManager.h"

class QuickInputStore : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList items READ items NOTIFY itemsChanged)
    Q_PROPERTY(bool isLoopSending READ isLoopSending NOTIFY isLoopSendingChanged)

public:
    explicit QuickInputStore(QObject *parent = nullptr) : QObject(parent)
        , m_serialManager(nullptr), m_loopSending(false), m_loopIndex(0) {
        m_filePath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + "/quickinputs.json";
        m_loopTimer = new QTimer(this);
        connect(m_loopTimer, &QTimer::timeout, this, &QuickInputStore::onLoopTick);
        m_delayTimer = new QTimer(this);
        m_delayTimer->setSingleShot(true);
        connect(m_delayTimer, &QTimer::timeout, this, &QuickInputStore::onDelayFinished);
        load();
    }

    void setSerialManager(SerialManager *mgr) { m_serialManager = mgr; }

    QVariantList items() const { return m_items; }
    bool isLoopSending() const { return m_loopSending; }

    Q_INVOKABLE void addItem(const QString &name = "新快捷指令", const QString &payload = "",
                             bool isHex = true, int delay = 0, bool enabled = true, const QString &remark = "") {
        QVariantMap item;
        item["name"] = name;
        item["payload"] = payload;
        item["isHex"] = isHex;
        item["delay"] = delay;
        item["enabled"] = enabled;
        item["remark"] = remark;
        m_items.append(item);
        emit itemsChanged();
        save();
    }

    Q_INVOKABLE void removeItem(int index) {
        if (index >= 0 && index < m_items.size()) {
            m_items.removeAt(index);
            emit itemsChanged();
            save();
        }
    }

    Q_INVOKABLE void updateItem(int index, const QString &name, const QString &payload,
                                bool isHex, int delay, bool enabled, const QString &remark) {
        if (index >= 0 && index < m_items.size()) {
            QVariantMap item;
            item["name"] = name;
            item["payload"] = payload;
            item["isHex"] = isHex;
            item["delay"] = delay;
            item["enabled"] = enabled;
            item["remark"] = remark;
            m_items[index] = item;
            emit itemsChanged();
            save();
        }
    }

    Q_INVOKABLE void moveItem(int from, int to) {
        if (from >= 0 && from < m_items.size() && to >= 0 && to < m_items.size() && from != to) {
            QVariantMap item = m_items[from].toMap();
            m_items.removeAt(from);
            m_items.insert(to, item);
            emit itemsChanged();
            save();
        }
    }

    Q_INVOKABLE void clearAll() {
        m_items.clear();
        emit itemsChanged();
        save();
    }

    Q_INVOKABLE void enableAll() {
        for (int i = 0; i < m_items.size(); ++i) {
            QVariantMap item = m_items[i].toMap();
            item["enabled"] = true;
            m_items[i] = item;
        }
        emit itemsChanged();
        save();
    }

    Q_INVOKABLE void disableAll() {
        for (int i = 0; i < m_items.size(); ++i) {
            QVariantMap item = m_items[i].toMap();
            item["enabled"] = false;
            m_items[i] = item;
        }
        emit itemsChanged();
        save();
    }

    Q_INVOKABLE void resetDefaults() {
        m_items.clear();
        addItem("示例指令", "FF 01 00 00 00", true, 100, true, "示例备注");
        emit itemsChanged();
        save();
    }

    Q_INVOKABLE void exportToFile(const QString &path) {
        save(QUrl(path).toLocalFile());
    }

    Q_INVOKABLE void importFromFile(const QString &path) {
        load(QUrl(path).toLocalFile());
    }

    Q_INVOKABLE void startLoopSend(int intervalMs) {
        if (m_loopSending) return;
        m_loopSending = true;
        m_loopIndex = 0;
        emit isLoopSendingChanged();
        m_loopTimer->start(intervalMs);
    }

    Q_INVOKABLE void stopLoopSend() {
        if (!m_loopSending) return;
        m_loopSending = false;
        m_loopTimer->stop();
        m_delayTimer->stop();
        emit isLoopSendingChanged();
    }

signals:
    void itemsChanged();
    void isLoopSendingChanged();

private slots:
    void onLoopTick() {
        sendNextEnabledItem();
    }

    void onDelayFinished() {
        sendNextEnabledItem();
    }

private:
    void sendNextEnabledItem() {
        if (!m_loopSending || !m_serialManager) return;

        int attempts = 0;
        while (attempts < m_items.size()) {
            if (m_loopIndex >= m_items.size())
                m_loopIndex = 0;

            QVariantMap item = m_items[m_loopIndex].toMap();
            m_loopIndex++;

            if (item["enabled"].toBool()) {
                int delay = item["delay"].toInt();
                // Send via SerialManager
                QMetaObject::invokeMethod(m_serialManager, "sendData",
                    Q_ARG(QString, item["payload"].toString()),
                    Q_ARG(bool, item["isHex"].toBool()));

                if (delay > 0) {
                    m_loopTimer->stop();
                    m_delayTimer->start(delay);
                    return;
                }
                break;
            }
            attempts++;
        }
    }

    void save(QString path = "") {
        if (path.isEmpty()) path = m_filePath;
        QFileInfo fileInfo(path);
        QDir().mkpath(fileInfo.absolutePath());

        QJsonArray root;
        for (const auto &i : m_items) {
            QVariantMap im = i.toMap();
            QJsonObject obj;
            obj["name"] = im["name"].toString();
            obj["payload"] = im["payload"].toString();
            obj["isHex"] = im["isHex"].toBool();
            obj["delay"] = im["delay"].toInt();
            obj["enabled"] = im["enabled"].toBool();
            obj["remark"] = im["remark"].toString();
            root.append(obj);
        }
        QFile file(path);
        if (file.open(QIODevice::WriteOnly)) {
            file.write(QJsonDocument(root).toJson());
            file.close();
        }
    }

    void load(QString path = "") {
        if (path.isEmpty()) path = m_filePath;
        if (path.isEmpty()) return;
        QFile file(path);
        if (!file.open(QIODevice::ReadOnly)) return;
        QJsonArray root = QJsonDocument::fromJson(file.readAll()).array();
        m_items.clear();
        for (int i = 0; i < root.size(); ++i) {
            QJsonObject obj = root[i].toObject();
            QVariantMap item;
            item["name"] = obj["name"].toString();
            item["payload"] = obj["payload"].toString();
            item["isHex"] = obj["isHex"].toBool();
            item["delay"] = obj["delay"].toInt(0);
            item["enabled"] = obj["enabled"].toBool(true);
            item["remark"] = obj["remark"].toString();
            m_items.append(item);
        }
        emit itemsChanged();
    }

    QVariantList m_items;
    QString m_filePath;
    SerialManager *m_serialManager;
    bool m_loopSending;
    int m_loopIndex;
    QTimer *m_loopTimer;
    QTimer *m_delayTimer;
};

#endif // QUICKINPUTSTORE_H
