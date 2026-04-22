#ifndef COMMANDSTORE_H
#define COMMANDSTORE_H

#include <QObject>
#include <QVariantList>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QFile>
#include <QStandardPaths>
#include <QDir>
#include <QUrl>
#include <QFileInfo>

class CommandStore : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList groups READ groups NOTIFY groupsChanged)

public:
    explicit CommandStore(QObject *parent = nullptr) : QObject(parent) {
        m_filePath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + "/commands.json";
        load();
    }

    QVariantList groups() const { return m_groups; }

    Q_INVOKABLE void addGroup(const QString &name = "新分组") {
        QVariantMap group;
        group["name"] = name;
        group["commands"] = QVariantList();
        m_groups.append(group);
        emit groupsChanged();
        save();
    }

    Q_INVOKABLE void addCommand(int groupIndex, const QString &name = "新指令", const QString &payload = "", bool isHex = true) {
        if (groupIndex < 0 || groupIndex >= m_groups.size()) return;
        QVariantMap group = m_groups[groupIndex].toMap();
        QVariantList commands = group["commands"].toList();
        QVariantMap cmd;
        cmd["name"] = name;
        cmd["payload"] = payload;
        cmd["isHex"] = isHex;
        commands.append(cmd);
        group["commands"] = commands;
        m_groups[groupIndex] = group;
        emit groupsChanged();
        save();
    }

    Q_INVOKABLE void updateGroupName(int index, const QString &name) {
        if (index >= 0 && index < m_groups.size()) {
            QVariantMap group = m_groups[index].toMap();
            group["name"] = name;
            m_groups[index] = group;
            emit groupsChanged();
            save();
        }
    }

    Q_INVOKABLE void updateCommand(int groupIndex, int cmdIndex, const QString &name, const QString &payload) {
        if (groupIndex < 0 || groupIndex >= m_groups.size()) return;
        QVariantMap group = m_groups[groupIndex].toMap();
        QVariantList commands = group["commands"].toList();
        if (cmdIndex >= 0 && cmdIndex < commands.size()) {
            QVariantMap cmd = commands[cmdIndex].toMap();
            cmd["name"] = name;
            cmd["payload"] = payload;
            commands[cmdIndex] = cmd;
            group["commands"] = commands;
            m_groups[groupIndex] = group;
            emit groupsChanged();
            save();
        }
    }

    Q_INVOKABLE void deleteGroup(int index) {
        if (index >= 0 && index < m_groups.size()) {
            m_groups.removeAt(index);
            emit groupsChanged();
            save();
        }
    }

    Q_INVOKABLE void deleteCommand(int groupIndex, int cmdIndex) {
        if (groupIndex < 0 || groupIndex >= m_groups.size()) return;
        QVariantMap group = m_groups[groupIndex].toMap();
        QVariantList commands = group["commands"].toList();
        if (cmdIndex >= 0 && cmdIndex < commands.size()) {
            commands.removeAt(cmdIndex);
            group["commands"] = commands;
            m_groups[groupIndex] = group;
            emit groupsChanged();
            save();
        }
    }

    Q_INVOKABLE void exportToFile(const QString &path) {
        save(QUrl(path).toLocalFile());
    }

    Q_INVOKABLE void importFromFile(const QString &path) {
        load(QUrl(path).toLocalFile());
    }

signals:
    void groupsChanged();

private:
    void save(QString path = "") {
        if (path.isEmpty()) path = m_filePath;
        QFileInfo fileInfo(path);
        QDir().mkpath(fileInfo.absolutePath());
        
        QJsonArray root;
        for (const auto &g : m_groups) {
            QVariantMap gm = g.toMap();
            QJsonObject groupObj;
            groupObj["name"] = gm["name"].toString();
            QJsonArray cmds;
            for (const auto &c : gm["commands"].toList()) {
                QVariantMap cm = c.toMap();
                QJsonObject cmdObj;
                cmdObj["name"] = cm["name"].toString();
                cmdObj["payload"] = cm["payload"].toString();
                cmdObj["isHex"] = cm["isHex"].toBool();
                cmds.append(cmdObj);
            }
            groupObj["commands"] = cmds;
            root.append(groupObj);
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
        m_groups.clear();
        for (int i = 0; i < root.size(); ++i) {
            QJsonObject groupObj = root[i].toObject();
            QVariantMap group;
            group["name"] = groupObj["name"].toString();
            QVariantList commands;
            QJsonArray cmds = groupObj["commands"].toArray();
            for (int j = 0; j < cmds.size(); ++j) {
                QJsonObject cmdObj = cmds[j].toObject();
                QVariantMap cmd;
                cmd["name"] = cmdObj["name"].toString();
                cmd["payload"] = cmdObj["payload"].toString();
                cmd["isHex"] = cmdObj["isHex"].toBool();
                commands.append(cmd);
            }
            group["commands"] = commands;
            m_groups.append(group);
        }
        emit groupsChanged();
    }

    QVariantList m_groups;
    QString m_filePath;
};

#endif // COMMANDSTORE_H
