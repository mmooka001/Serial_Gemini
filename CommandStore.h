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
#include <QCoreApplication>
#include <QSettings>
#include <QSaveFile>
#include <QCryptographicHash>
#include <QLockFile>

class CommandStore : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList groups READ groups NOTIFY groupsChanged)
    Q_PROPERTY(QStringList files READ files NOTIFY filesChanged)
    Q_PROPERTY(QString currentFile READ currentFile NOTIFY currentFileChanged)
    Q_PROPERTY(QString directory READ directory CONSTANT)
    Q_PROPERTY(bool hasUnsavedChanges READ hasUnsavedChanges NOTIFY unsavedChangesChanged)
    Q_PROPERTY(QString statusMessage READ statusMessage NOTIFY statusChanged)
    Q_PROPERTY(bool hasError READ hasError NOTIFY statusChanged)

public:
    explicit CommandStore(QObject *parent = nullptr, const QString &directory = QString()) : QObject(parent) {
        m_directory = QDir::cleanPath(directory.isEmpty()
            ? QCoreApplication::applicationDirPath() + "/Commands" : QFileInfo(directory).absoluteFilePath());
        m_settingsKey = "commandLibrary/" + QString::fromLatin1(digest(m_directory.toUtf8()).toHex()) + "/";
        initialize();
    }

    QVariantList groups() const { return m_groups; }
    QStringList files() const { return m_files; }
    QString currentFile() const { return QFileInfo(m_filePath).fileName(); }
    QString directory() const { return m_directory; }
    bool hasUnsavedChanges() const { return m_dirty; }
    QString statusMessage() const { return m_statusMessage; }
    bool hasError() const { return m_hasError; }

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

    Q_INVOKABLE bool saveCurrent() { return !m_dirty || save(); }

    Q_INVOKABLE bool selectFile(const QString &name) {
        if (!m_files.contains(name)) return fail("指令文件不在目录中，请先刷新。");
        if (name == currentFile()) return saveCurrent();
        if (!saveCurrent()) return false;
        return load(QDir(m_directory).filePath(name));
    }

    Q_INVOKABLE bool refreshFiles(bool discardUnsaved = false) {
        if (!discardUnsaved && !saveCurrent()) return false;
        if (!ensureDirectory()) return false;
        scanFiles();
        if (m_files.isEmpty()) {
            // 外部删除全部文件时保留当前内容，由用户决定导出或新建，避免悄悄重建旧文件。
            if (discardUnsaved) {
                m_groups.clear();
                m_filePath.clear();
                m_diskDigest.clear();
                setDirty(false);
                emit currentFileChanged();
                emit groupsChanged();
                emit libraryReloaded();
            }
            return fail("目录中没有 JSON 指令文件。可导入文件或点击新建。");
        }
        const QString name = m_files.contains(currentFile()) ? currentFile() : m_files.first();
        if (!load(QDir(m_directory).filePath(name))) return false;
        setStatus("已刷新指令文件。");
        return true;
    }

    Q_INVOKABLE bool createFile() {
        if (!saveCurrent() || !ensureDirectory()) return false;
        QLockFile lock(QDir(m_directory).filePath(".library.lock"));
        if (!lock.tryLock()) return fail("另一窗口正在保存指令，请稍后重试。");
        const QString path = uniquePath("新指令.json");
        if (!writeFile(path, QJsonDocument(QJsonArray()).toJson())) return false;
        scanFiles();
        return load(path);
    }

    Q_INVOKABLE bool exportToFile(const QString &location) {
        const QString path = localPath(location);
        if (path.isEmpty()) return fail("请选择导出文件。");
        if (!m_filePath.isEmpty() && QFileInfo(path) == QFileInfo(m_filePath)) return saveCurrent();
        QLockFile lock(QDir(m_directory).filePath(".library.lock"));
        if (QDir(QFileInfo(path).absolutePath()) == QDir(m_directory) && !lock.tryLock())
            return fail("另一窗口正在保存指令，请稍后重试。");
        if (!writeFile(path, QJsonDocument(QJsonArray::fromVariantList(m_groups)).toJson())) return false;
        setStatus("已导出当前指令。" + QString(m_dirty ? "原文件仍有未保存修改。" : ""));
        return true;
    }

    Q_INVOKABLE bool importFromFile(const QString &location) {
        if (!saveCurrent() || !ensureDirectory()) return false;
        const QString source = localPath(location);
        QByteArray bytes;
        QVariantList groups;
        if (!readFile(source, bytes, groups)) return false;
        // 直接选择本目录的文件，不额外生成副本。
        if (QDir(QFileInfo(source).absolutePath()) == QDir(m_directory)
            && QFileInfo(source).suffix().compare("json", Qt::CaseInsensitive) == 0) {
            scanFiles();
            return load(source);
        }
        QLockFile lock(QDir(m_directory).filePath(".library.lock"));
        if (!lock.tryLock()) return fail("另一窗口正在保存指令，请稍后重试。");
        QString name = QFileInfo(source).fileName();
        if (!name.endsWith(".json", Qt::CaseInsensitive)) name += ".json";
        const QString destination = uniquePath(name);
        if (!writeFile(destination, bytes)) return false;
        scanFiles();
        if (!load(destination)) return false;
        setStatus("已导入：" + currentFile());
        return true;
    }

signals:
    void groupsChanged();
    void groupRenamed(int index, const QString &name);
    void commandChanged(int groupIndex, int commandIndex, const QVariantMap &command);
    void filesChanged();
    void currentFileChanged();
    void unsavedChangesChanged();
    void statusChanged();
    void libraryReloaded();

private:
    static QByteArray digest(const QByteArray &bytes) {
        return QCryptographicHash::hash(bytes, QCryptographicHash::Sha256);
    }

    static QString localPath(const QString &location) {
        const QUrl url(location);
        return url.isLocalFile() ? url.toLocalFile() : location;
    }

    void setStatus(const QString &message, bool error = false) {
        if (m_statusMessage == message && m_hasError == error) return;
        m_statusMessage = message;
        m_hasError = error;
        emit statusChanged();
    }

    bool fail(const QString &message) { setStatus(message, true); return false; }

    void setDirty(bool dirty) {
        if (m_dirty == dirty) return;
        m_dirty = dirty;
        emit unsavedChangesChanged();
    }

    bool ensureDirectory() {
        return QDir().mkpath(m_directory) || fail("无法创建 Commands 目录，请将软件放在可写入的文件夹。");
    }

    void scanFiles() {
        QStringList files;
        const auto entries = QDir(m_directory).entryInfoList(QDir::Files | QDir::NoSymLinks, QDir::Name | QDir::IgnoreCase);
        for (const QFileInfo &info : entries)
            if (info.suffix().compare("json", Qt::CaseInsensitive) == 0) files.append(info.fileName());
        if (files == m_files) return;
        m_files = files;
        emit filesChanged();
    }

    QString uniquePath(const QString &fileName) const {
        const QFileInfo info(fileName);
        QString path = QDir(m_directory).filePath(info.fileName());
        for (int suffix = 2; QFileInfo::exists(path); ++suffix)
            path = QDir(m_directory).filePath(info.completeBaseName() + " (" + QString::number(suffix) + ").json");
        return path;
    }

    bool readFile(const QString &path, QByteArray &bytes, QVariantList &groups) {
        QFile file(path);
        const QString name = QFileInfo(path).fileName();
        if (!file.open(QIODevice::ReadOnly)) return fail("无法读取 " + name + "：" + file.errorString());
        bytes = file.readAll();
        if (file.error() != QFileDevice::NoError) return fail("读取 " + name + " 失败：" + file.errorString());
        QJsonParseError error;
        const QJsonDocument document = QJsonDocument::fromJson(bytes, &error);
        if (error.error != QJsonParseError::NoError)
            return fail(name + " JSON 格式错误（位置 " + QString::number(error.offset) + "）：" + error.errorString());
        if (!document.isArray()) return fail(name + " 的根节点必须是指令分组数组。");
        const auto root = document.array();
        for (int i = 0; i < root.size(); ++i) {
            const auto group = root[i].toObject();
            if (!root[i].isObject() || !group["name"].isString() || !group["commands"].isArray())
                return fail(name + " 的第 " + QString::number(i + 1) + " 个分组缺少 name 或 commands。");
            const auto commands = group["commands"].toArray();
            for (int j = 0; j < commands.size(); ++j) {
                const auto command = commands[j].toObject();
                if (!commands[j].isObject() || !command["name"].isString() || !command["payload"].isString()
                    || (command.contains("isHex") && !command["isHex"].isBool()))
                    return fail(name + " 的第 " + QString::number(i + 1) + " 组、第 " + QString::number(j + 1)
                        + " 条指令格式错误（需 name、payload 和布尔值 isHex）。");
            }
        }
        groups = root.toVariantList();
        return true;
    }

    bool writeFile(const QString &path, const QByteArray &bytes) {
        // QSaveFile 先写临时文件再原子替换，写入失败时保留原文件。
        QSaveFile file(path);
        if (!file.open(QIODevice::WriteOnly)) return fail("无法保存 " + QFileInfo(path).fileName() + "：" + file.errorString());
        if (file.write(bytes) != bytes.size() || !file.commit())
            return fail("保存失败，原文件已保留：" + file.errorString());
        return true;
    }

    bool save() {
        setDirty(true);
        if (m_filePath.isEmpty()) return fail("请先选择、新建或导入指令文件。当前编辑仍保留，可导出备份。");
        QLockFile lock(QDir(m_directory).filePath(".library.lock"));
        if (!lock.tryLock()) return fail("另一窗口正在保存指令，当前编辑尚未保存，请稍后重试。");
        QFile existing(m_filePath);
        if (QFileInfo(m_filePath).isSymLink() || !existing.open(QIODevice::ReadOnly))
            return fail("当前文件已移走或不可读取。编辑仍保留，可导出备份后刷新。");
        const QByteArray currentBytes = existing.readAll();
        if (existing.error() != QFileDevice::NoError) return fail("读取当前文件失败，编辑尚未保存。");
        existing.close();
        if (digest(currentBytes) != m_diskDigest)
            return fail("当前文件已被外部修改。编辑仍保留，请先导出备份，或刷新读取外部版本。");
        const QByteArray bytes = QJsonDocument(QJsonArray::fromVariantList(m_groups)).toJson();
        if (!writeFile(m_filePath, bytes)) return false;
        m_diskDigest = digest(bytes);
        setDirty(false);
        setStatus(QString());
        return true;
    }

    bool load(const QString &path) {
        if (QFileInfo(path).isSymLink()) return fail("请选择 Commands 目录中的普通 JSON 文件。");
        QByteArray bytes;
        QVariantList groups;
        if (!readFile(path, bytes, groups)) return false;
        const bool fileChanged = m_filePath != path;
        m_filePath = path;
        m_diskDigest = digest(bytes);
        m_groups = groups;
        setDirty(false);
        QSettings().setValue(m_settingsKey + "currentFile", currentFile());
        if (fileChanged) emit currentFileChanged();
        emit groupsChanged();
        emit libraryReloaded();
        setStatus(QString());
        return true;
    }

    void initialize() {
        if (!ensureDirectory()) return;
        QLockFile lock(QDir(m_directory).filePath(".library.lock"));
        if (!lock.tryLock()) { fail("另一窗口正在保存指令，请稍后刷新。"); return; }
        QSettings settings;
        const QString legacy = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + "/commands.json";
        QString migrated;
        if (!settings.value(m_settingsKey + "initialized", false).toBool()) {
            if (QFileInfo::exists(legacy)) {
                QByteArray bytes;
                QVariantList groups;
                if (!readFile(legacy, bytes, groups)) return;
                migrated = uniquePath("旧版指令.json");
                if (!writeFile(migrated, bytes)) return;
            }
            settings.setValue(m_settingsKey + "initialized", true);
        }
        scanFiles();
        if (m_files.isEmpty()) {
            const QString path = uniquePath("默认指令.json");
            if (!writeFile(path, QJsonDocument(QJsonArray()).toJson())) return;
            scanFiles();
        }
        QString preferred = settings.value(m_settingsKey + "currentFile", QFileInfo(migrated).fileName()).toString();
        if (m_files.contains(preferred) && load(QDir(m_directory).filePath(preferred))) return;
        for (const QString &name : m_files)
            if (load(QDir(m_directory).filePath(name))) return;
    }

    QVariantList m_groups;
    QStringList m_files;
    QString m_directory;
    QString m_settingsKey;
    QString m_filePath;
    QByteArray m_diskDigest;
    QString m_statusMessage;
    bool m_dirty = false;
    bool m_hasError = false;
};

#endif // COMMANDSTORE_H
