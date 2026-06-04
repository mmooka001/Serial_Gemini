#ifndef RECORDSTORE_H
#define RECORDSTORE_H

#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QDateTime>
#include <QFile>
#include <QUrl>
#include <QTextStream>

class RecordStore : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList records READ records NOTIFY recordsChanged)
    Q_PROPERTY(quint64 rxCount READ rxCount NOTIFY rxCountChanged)
    Q_PROPERTY(quint64 txCount READ txCount NOTIFY txCountChanged)

public:
    explicit RecordStore(QObject *parent = nullptr) : QObject(parent)
        , m_rxCount(0), m_txCount(0) {}

    QVariantList records() const { return m_records; }
    quint64 rxCount() const { return m_rxCount; }
    quint64 txCount() const { return m_txCount; }

    Q_INVOKABLE void addRecord(const QString &type, const QString &content,
                               const QString &hexContent, int displayMode = 0) {
        QVariantMap rec;
        rec["type"] = type;
        rec["content"] = content;
        rec["hexContent"] = hexContent;
        rec["timestamp"] = QDateTime::currentDateTime().toString("yyyy-MM-dd hh:mm:ss.zzz");
        rec["displayMode"] = displayMode;
        m_records.append(rec);

        // Update counters
        if (type == "read") {
            m_rxCount += hexContent.split(' ', Qt::SkipEmptyParts).size();
            emit rxCountChanged();
        } else if (type == "write") {
            m_txCount += hexContent.split(' ', Qt::SkipEmptyParts).size();
            emit txCountChanged();
        }

        // Auto-trim to 10000 records
        while (m_records.size() > 10000) {
            m_records.removeFirst();
        }

        emit recordsChanged();
    }

    Q_INVOKABLE void clearRecords() {
        m_records.clear();
        m_rxCount = 0;
        m_txCount = 0;
        emit recordsChanged();
        emit rxCountChanged();
        emit txCountChanged();
    }

    Q_INVOKABLE void exportRecords(const QString &path) {
        QString localPath = QUrl(path).toLocalFile();
        QFile file(localPath);
        if (!file.open(QIODevice::WriteOnly | QIODevice::Text))
            return;
        QTextStream ts(&file);
        ts << "Type,Timestamp,Content,HexContent,DisplayMode\n";
        for (const auto &r : m_records) {
            QVariantMap rec = r.toMap();
            ts << rec["type"].toString() << ","
               << rec["timestamp"].toString() << ","
               << rec["content"].toString().replace(",", ";") << ","
               << rec["hexContent"].toString() << ","
               << rec["displayMode"].toInt() << "\n";
        }
        file.close();
    }

signals:
    void recordsChanged();
    void rxCountChanged();
    void txCountChanged();

private:
    QVariantList m_records;
    quint64 m_rxCount;
    quint64 m_txCount;
};

#endif // RECORDSTORE_H
