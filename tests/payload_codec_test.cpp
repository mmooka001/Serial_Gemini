#include "../PayloadCodec.h"
#include "../ChecksumHelper.h"
#include <QCoreApplication>
#include <iostream>
#include <cassert>

int main(int argc, char **argv) {
    QCoreApplication app(argc, argv);
    const QByteArray raw = QByteArray::fromHex("aa5500");
    assert(PayloadCodec::isHex("0xAA 0x55 00"));
    assert(!PayloadCodec::isHex("AT+RST"));
    assert(!PayloadCodec::isHex("A"));
    assert(!PayloadCodec::isHex(QString::fromUtf8("１２")));
    assert(PayloadCodec::decode("AA 55 00", true) == raw);
    assert(PayloadCodec::decode("AT+RST", true) == QByteArray("AT+RST"));
    assert(PayloadCodec::decode("AA 55", false) == QByteArray("AA 55"));
    assert(PayloadCodec::decode(QString::fromUtf8("你好"), true).toHex() == "e4bda0e5a5bd");
    const QString chinese = QString::fromUtf8("你好");
    for (const QString &encoding : {QString("GBK"), QString("GB2312")}) {
        assert(PayloadCodec::decode(chinese, true, encoding).toHex() == "c4e3bac3");
        assert(PayloadCodec::decode(chinese, false, encoding).toHex() == "c4e3bac3");
        assert(PayloadCodec::decode("AA 55 00", true, encoding) == raw);
        assert(PayloadCodec::decodeText(QByteArray::fromHex("c4e3bac3"), encoding) == chinese);
        assert(ChecksumHelper::hexChecksumPreview(chinese, true, 2, encoding)
               == ChecksumHelper::calculate(QByteArray::fromHex("c4e3bac3"), ChecksumHelper::Sum8).toHex(' ').toUpper());
    }
    const QString latin = QString::fromUtf8("café");
    assert(PayloadCodec::encodeText(latin, "ISO-8859-1").toHex() == "636166e9");
    assert(PayloadCodec::decodeText(QByteArray::fromHex("636166e9"), "ISO-8859-1") == latin);
    assert(PayloadCodec::encodeText(latin, "ASCII") == "caf?");
    assert(PayloadCodec::encodeText(chinese, "ASCII") == "??");
    for (const QString &encoding : {QString("UTF-8"), QString("GBK"), QString("GB2312")}) {
        const QByteArray bytes = PayloadCodec::encodeText(chinese, encoding);
        for (int split = 1; split < bytes.size(); ++split) {
            PayloadCodec::StreamDecoder decoder;
            decoder.reset(encoding);
            const QString first = decoder.decode(bytes.left(split));
            const QString text = first + decoder.decode(bytes.mid(split));
            assert(text == chinese);
        }
    }
    PayloadCodec::StreamDecoder decoder;
    assert(decoder.decode(QByteArray::fromHex("e4")).isEmpty());
    decoder.reset("UTF-8");
    assert(decoder.decode("OK") == "OK");
    for (int ending = 0; ending <= 3; ++ending) {
        assert(PayloadCodec::frame(raw, true, ending) == raw);
        const QByteArray checksum = ChecksumHelper::calculate(raw, ChecksumHelper::Sum8);
        assert(PayloadCodec::frame(raw, true, ending, checksum) == raw + checksum);
    }
    assert(PayloadCodec::frame(raw + '\n', true, 1) == raw + '\n');
    assert(PayloadCodec::frame("AT", false, 0) == QByteArray("AT"));
    assert(PayloadCodec::frame("AT", false, 1) == QByteArray("AT\n"));
    assert(PayloadCodec::frame("AT", false, 2) == QByteArray("AT\r"));
    assert(PayloadCodec::frame("AT", false, 3) == QByteArray("AT\r\n"));
    const QByteArray utf8 = PayloadCodec::decode("AT+RST", true);
    assert(ChecksumHelper::hexChecksumPreview("AT+RST", true, 2)
           == ChecksumHelper::calculate(utf8, ChecksumHelper::Sum8).toHex(' ').toUpper());
    std::cout << "Payload bytes, HEX conversion, checksum and line-ending checks passed.\n";
}
