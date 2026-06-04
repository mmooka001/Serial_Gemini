/****************************************************************************
** Meta object code from reading C++ file 'DataEncoder.h'
**
** Created by: The Qt Meta Object Compiler version 69 (Qt 6.11.0)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../../../DataEncoder.h"
#include <QtCore/qmetatype.h>

#include <QtCore/qtmochelpers.h>

#include <memory>


#include <QtCore/qxptype_traits.h>
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'DataEncoder.h' doesn't include <QObject>."
#elif Q_MOC_OUTPUT_REVISION != 69
#error "This file was generated using the moc from 6.11.0. It"
#error "cannot be used with the include files from this version of Qt."
#error "(The moc has changed too much.)"
#endif

#ifndef Q_CONSTINIT
#define Q_CONSTINIT
#endif

QT_WARNING_PUSH
QT_WARNING_DISABLE_DEPRECATED
QT_WARNING_DISABLE_GCC("-Wuseless-cast")
namespace {
struct qt_meta_tag_ZN11DataEncoderE_t {};
} // unnamed namespace

template <> constexpr inline auto DataEncoder::qt_create_metaobjectdata<qt_meta_tag_ZN11DataEncoderE_t>()
{
    namespace QMC = QtMocConstants;
    QtMocHelpers::StringRefStorage qt_stringData {
        "DataEncoder",
        "hexToString",
        "",
        "hex",
        "stringToHex",
        "str",
        "formatHex",
        "formatDec",
        "validateHex",
        "reformatHex",
        "decodeBytes",
        "data",
        "encoding",
        "encodeString"
    };

    QtMocHelpers::UintData qt_methods {
        // Method 'hexToString'
        QtMocHelpers::MethodData<QString(const QString &)>(1, 2, QMC::AccessPublic, QMetaType::QString, {{
            { QMetaType::QString, 3 },
        }}),
        // Method 'stringToHex'
        QtMocHelpers::MethodData<QString(const QString &)>(4, 2, QMC::AccessPublic, QMetaType::QString, {{
            { QMetaType::QString, 5 },
        }}),
        // Method 'formatHex'
        QtMocHelpers::MethodData<QString(const QString &)>(6, 2, QMC::AccessPublic, QMetaType::QString, {{
            { QMetaType::QString, 3 },
        }}),
        // Method 'formatDec'
        QtMocHelpers::MethodData<QString(const QString &)>(7, 2, QMC::AccessPublic, QMetaType::QString, {{
            { QMetaType::QString, 3 },
        }}),
        // Method 'validateHex'
        QtMocHelpers::MethodData<QString(const QString &)>(8, 2, QMC::AccessPublic, QMetaType::QString, {{
            { QMetaType::QString, 3 },
        }}),
        // Method 'reformatHex'
        QtMocHelpers::MethodData<QString(const QString &)>(9, 2, QMC::AccessPublic, QMetaType::QString, {{
            { QMetaType::QString, 3 },
        }}),
        // Method 'decodeBytes'
        QtMocHelpers::MethodData<QString(const QByteArray &, const QString &)>(10, 2, QMC::AccessPublic, QMetaType::QString, {{
            { QMetaType::QByteArray, 11 }, { QMetaType::QString, 12 },
        }}),
        // Method 'encodeString'
        QtMocHelpers::MethodData<QByteArray(const QString &, const QString &)>(13, 2, QMC::AccessPublic, QMetaType::QByteArray, {{
            { QMetaType::QString, 5 }, { QMetaType::QString, 12 },
        }}),
    };
    QtMocHelpers::UintData qt_properties {
    };
    QtMocHelpers::UintData qt_enums {
    };
    return QtMocHelpers::metaObjectData<DataEncoder, qt_meta_tag_ZN11DataEncoderE_t>(QMC::MetaObjectFlag{}, qt_stringData,
            qt_methods, qt_properties, qt_enums);
}
Q_CONSTINIT const QMetaObject DataEncoder::staticMetaObject = { {
    QMetaObject::SuperData::link<QObject::staticMetaObject>(),
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN11DataEncoderE_t>.stringdata,
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN11DataEncoderE_t>.data,
    qt_static_metacall,
    nullptr,
    qt_staticMetaObjectRelocatingContent<qt_meta_tag_ZN11DataEncoderE_t>.metaTypes,
    nullptr
} };

void DataEncoder::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    auto *_t = static_cast<DataEncoder *>(_o);
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: { QString _r = _t->hexToString((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])));
            if (_a[0]) *reinterpret_cast<QString*>(_a[0]) = std::move(_r); }  break;
        case 1: { QString _r = _t->stringToHex((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])));
            if (_a[0]) *reinterpret_cast<QString*>(_a[0]) = std::move(_r); }  break;
        case 2: { QString _r = _t->formatHex((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])));
            if (_a[0]) *reinterpret_cast<QString*>(_a[0]) = std::move(_r); }  break;
        case 3: { QString _r = _t->formatDec((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])));
            if (_a[0]) *reinterpret_cast<QString*>(_a[0]) = std::move(_r); }  break;
        case 4: { QString _r = _t->validateHex((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])));
            if (_a[0]) *reinterpret_cast<QString*>(_a[0]) = std::move(_r); }  break;
        case 5: { QString _r = _t->reformatHex((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])));
            if (_a[0]) *reinterpret_cast<QString*>(_a[0]) = std::move(_r); }  break;
        case 6: { QString _r = _t->decodeBytes((*reinterpret_cast<std::add_pointer_t<QByteArray>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2])));
            if (_a[0]) *reinterpret_cast<QString*>(_a[0]) = std::move(_r); }  break;
        case 7: { QByteArray _r = _t->encodeString((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2])));
            if (_a[0]) *reinterpret_cast<QByteArray*>(_a[0]) = std::move(_r); }  break;
        default: ;
        }
    }
}

const QMetaObject *DataEncoder::metaObject() const
{
    return QObject::d_ptr->metaObject ? QObject::d_ptr->dynamicMetaObject() : &staticMetaObject;
}

void *DataEncoder::qt_metacast(const char *_clname)
{
    if (!_clname) return nullptr;
    if (!strcmp(_clname, qt_staticMetaObjectStaticContent<qt_meta_tag_ZN11DataEncoderE_t>.strings))
        return static_cast<void*>(this);
    return QObject::qt_metacast(_clname);
}

int DataEncoder::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        if (_id < 8)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 8;
    }
    if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        if (_id < 8)
            *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType();
        _id -= 8;
    }
    return _id;
}
QT_WARNING_POP
