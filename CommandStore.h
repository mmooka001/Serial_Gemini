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
            if (group["name"].toString() == name) return;
            group["name"] = name;
            m_groups[index] = group;
            emit groupRenamed(index, name);
            save();
        }
    }

    Q_INVOKABLE void updateCommand(int groupIndex, int cmdIndex, const QString &name, const QString &payload,
                                   const QVariant &isHex = QVariant()) {
        if (groupIndex < 0 || groupIndex >= m_groups.size()) return;
        QVariantMap group = m_groups[groupIndex].toMap();
        QVariantList commands = group["commands"].toList();
        if (cmdIndex >= 0 && cmdIndex < commands.size()) {
            QVariantMap cmd = commands[cmdIndex].toMap();
            const QVariantMap previous = cmd;
            cmd["name"] = name;
            cmd["payload"] = payload;
            if (isHex.isValid()) cmd["isHex"] = isHex.toBool();
            if (cmd == previous) return;
            commands[cmdIndex] = cmd;
            group["commands"] = commands;
            m_groups[groupIndex] = group;
            emit commandChanged(groupIndex, cmdIndex, cmd);
            save();
        }
    }

    Q_INVOKABLE void setCommandHex(int groupIndex, int cmdIndex, bool isHex) {
        if (groupIndex < 0 || groupIndex >= m_groups.size()) return;
        QVariantMap group = m_groups[groupIndex].toMap();
        QVariantList commands = group["commands"].toList();
        if (cmdIndex >= 0 && cmdIndex < commands.size()) {
            QVariantMap cmd = commands[cmdIndex].toMap();
            if (cmd["isHex"].toBool() == isHex) return;
            cmd["isHex"] = isHex;
            commands[cmdIndex] = cmd;
            group["commands"] = commands;
            m_groups[groupIndex] = group;
            emit commandChanged(groupIndex, cmdIndex, cmd);
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

    Q_INVOKABLE bool moveCommand(int groupIndex, int from, int to, const QVariantMap &edits = QVariantMap()) {
        if (groupIndex < 0 || groupIndex >= m_groups.size()) return false;
        QVariantMap group = m_groups[groupIndex].toMap();
        QVariantList commands = group["commands"].toList();
        if (from < 0 || from >= commands.size() || to < 0 || to >= commands.size()) return false;
        QVariantMap command = commands[from].toMap();
        if (edits.contains("name")) command["name"] = edits["name"];
        if (edits.contains("payload")) command["payload"] = edits["payload"];
        commands[from] = command;
        commands.move(from, to);
        group["commands"] = commands;
        m_groups[groupIndex] = group;
        emit groupsChanged();
        save();
        return true;
    }

    Q_INVOKABLE bool moveGroup(int from, int to, const QString &name) {
        if (from < 0 || from >= m_groups.size() || to < 0 || to >= m_groups.size()) return false;
        QVariantMap group = m_groups[from].toMap();
        group["name"] = name;
        m_groups[from] = group;
        m_groups.move(from, to);
        emit groupsChanged();
        save();
        return true;
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
    void groupRenamed(int index, const QString &name);
    void commandChanged(int groupIndex, int commandIndex, const QVariantMap &command);

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
