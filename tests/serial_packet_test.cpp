#include <QSignalSpy>
#include <QTest>

#include "SerialManager.h"

class SerialPacketTest : public QObject
{
    Q_OBJECT

private slots:
    void timedPacketKeepsFirstTimestamp()
    {
        SerialManager manager;
        QSignalSpy received(&manager, &SerialManager::dataReceived);
        manager.configureReceivePackets(0, 100, 4);
        manager.bufferReceivedBytes("AB", 1000);
        QTest::qWait(25);
        manager.bufferReceivedBytes("CD", 1025);
        QCOMPARE(received.size(), 0);
        QTRY_COMPARE_WITH_TIMEOUT(received.size(), 1, 400);
        QCOMPARE(received.at(0).at(1).toString(), "41 42 43 44");
        QCOMPARE(received.at(0).at(4).toLongLong(), 1000);
    }

    void fixedPacketsFlushRemainderAndPreserveUtf8()
    {
        SerialManager manager;
        QSignalSpy received(&manager, &SerialManager::dataReceived);
        manager.configureReceivePackets(1, 20, 2);
        manager.bufferReceivedBytes(QStringLiteral("A中B").toUtf8(), 1000);
        QCOMPARE(received.size(), 2);
        QCOMPARE(received.at(0).at(1).toString(), "41 E4");
        QCOMPARE(received.at(1).at(1).toString(), "B8 AD");
        QCOMPARE(received.at(0).at(0).toString() + received.at(1).at(0).toString(), QStringLiteral("A中"));
        QTRY_COMPARE_WITH_TIMEOUT(received.size(), 3, 300);
        QCOMPARE(received.at(2).at(1).toString(), "42");
    }

    void clearDropsPartialPacket()
    {
        SerialManager manager;
        QSignalSpy received(&manager, &SerialManager::dataReceived);
        manager.configureReceivePackets(1, 20, 5);
        manager.bufferReceivedBytes("old", 1000);
        manager.discardReceivePacket();
        manager.bufferReceivedBytes("new", 1100);
        QTRY_COMPARE_WITH_TIMEOUT(received.size(), 1, 300);
        QCOMPARE(received.at(0).at(0).toString(), "new");
    }

    void stalledWriteClearsPendingQueue()
    {
        SerialManager manager;
        QSignalSpy stalled(&manager, &SerialManager::sendingStalled);
        manager.m_pendingWrites.enqueue({QByteArray("test"), 0, false, "UTF-8"});
        manager.m_queuedWriteBytes = 4;
        manager.m_writeInFlight = 4;
        manager.m_writeWatchdog.start(1);
        QTRY_COMPARE_WITH_TIMEOUT(stalled.size(), 1, 300);
        QVERIFY(manager.m_pendingWrites.isEmpty());
        QCOMPARE(manager.m_queuedWriteBytes, 0);
        QCOMPARE(manager.m_writeInFlight, 0);
    }
};

QTEST_GUILESS_MAIN(SerialPacketTest)
#include "serial_packet_test.moc"
