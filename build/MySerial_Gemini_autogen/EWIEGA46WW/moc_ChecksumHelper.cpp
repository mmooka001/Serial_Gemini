/****************************************************************************
** Meta object code from reading C++ file 'ChecksumHelper.h'
**
** Created by: The Qt Meta Object Compiler version 69 (Qt 6.11.0)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../../../ChecksumHelper.h"
#include <QtCore/qmetatype.h>

#include <QtCore/qtmochelpers.h>

#include <memory>


#include <QtCore/qxptype_traits.h>
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'ChecksumHelper.h' doesn't include <QObject>."
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
struct qt_meta_tag_ZN14ChecksumHelperE_t {};
} // unnamed namespace

template <> constexpr inline auto ChecksumHelper::qt_create_metaobjectdata<qt_meta_tag_ZN14ChecksumHelperE_t>()
{
    namespace QMC = QtMocConstants;
    QtMocHelpers::StringRefStorage qt_stringData {
        "ChecksumHelper",
        "calculate",
        "",
        "data",
        "ChecksumType",
        "type",
        "hexChecksumPreview",
        "isHex",
        "None",
        "BCC",
        "Sum8",
        "CRC16_Modbus"
    };

    QtMocHelpers::UintData qt_methods {
        // Method 'calculate'
        QtMocHelpers::MethodData<QByteArray(const QByteArray &, enum ChecksumType)>(1, 2, QMC::AccessPublic, QMetaType::QByteArray, {{
            { QMetaType::QByteArray, 3 }, { 0x80000000 | 4, 5 },
        }}),
        // Method 'hexChecksumPreview'
        QtMocHelpers::MethodData<QString(const QString &, bool, int)>(6, 2, QMC::AccessPublic, QMetaType::QString, {{
            { QMetaType::QString, 3 }, { QMetaType::Bool, 7 }, { QMetaType::Int, 5 },
        }}),
    };
    QtMocHelpers::UintData qt_properties {
    };
    QtMocHelpers::UintData qt_enums {
        // enum 'ChecksumType'
        QtMocHelpers::EnumData<enum ChecksumType>(4, 4, QMC::EnumFlags{}).add({
            {    8, ChecksumType::None },
            {    9, ChecksumType::BCC },
            {   10, ChecksumType::Sum8 },
            {   11, ChecksumType::CRC16_Modbus },
        }),
    };
    return QtMocHelpers::metaObjectData<ChecksumHelper, qt_meta_tag_ZN14ChecksumHelperE_t>(QMC::MetaObjectFlag{}, qt_stringData,
            qt_methods, qt_properties, qt_enums);
}
Q_CONSTINIT const QMetaObject ChecksumHelper::staticMetaObject = { {
    QMetaObject::SuperData::link<QObject::staticMetaObject>(),
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN14ChecksumHelperE_t>.stringdata,
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN14ChecksumHelperE_t>.data,
    qt_static_metacall,
    nullptr,
    qt_staticMetaObjectRelocatingContent<qt_meta_tag_ZN14ChecksumHelperE_t>.metaTypes,
    nullptr
} };

void ChecksumHelper::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    auto *_t = static_cast<ChecksumHelper *>(_o);
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: { QByteArray _r = _t->calculate((*reinterpret_cast<std::add_pointer_t<QByteArray>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<enum ChecksumType>>(_a[2])));
            if (_a[0]) *reinterpret_cast<QByteArray*>(_a[0]) = std::move(_r); }  break;
        case 1: { QString _r = _t->hexChecksumPreview((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<bool>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<int>>(_a[3])));
            if (_a[0]) *reinterpret_cast<QString*>(_a[0]) = std::move(_r); }  break;
        default: ;
        }
    }
}

const QMetaObject *ChecksumHelper::metaObject() const
{
    return QObject::d_ptr->metaObject ? QObject::d_ptr->dynamicMetaObject() : &staticMetaObject;
}

void *ChecksumHelper::qt_metacast(const char *_clname)
{
    if (!_clname) return nullptr;
    if (!strcmp(_clname, qt_staticMetaObjectStaticContent<qt_meta_tag_ZN14ChecksumHelperE_t>.strings))
        return static_cast<void*>(this);
    return QObject::qt_metacast(_clname);
}

int ChecksumHelper::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        if (_id < 2)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 2;
    }
    if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        if (_id < 2)
            *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType();
        _id -= 2;
    }
    return _id;
}
QT_WARNING_POP
