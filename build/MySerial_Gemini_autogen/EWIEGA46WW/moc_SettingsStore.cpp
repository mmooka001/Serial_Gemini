/****************************************************************************
** Meta object code from reading C++ file 'SettingsStore.h'
**
** Created by: The Qt Meta Object Compiler version 69 (Qt 6.11.0)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../../../SettingsStore.h"
#include <QtCore/qmetatype.h>

#include <QtCore/qtmochelpers.h>

#include <memory>


#include <QtCore/qxptype_traits.h>
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'SettingsStore.h' doesn't include <QObject>."
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
struct qt_meta_tag_ZN13SettingsStoreE_t {};
} // unnamed namespace

template <> constexpr inline auto SettingsStore::qt_create_metaobjectdata<qt_meta_tag_ZN13SettingsStoreE_t>()
{
    namespace QMC = QtMocConstants;
    QtMocHelpers::StringRefStorage qt_stringData {
        "SettingsStore",
        "lineEndingModeChanged",
        "",
        "customLineEndingChanged",
        "dataEncodingChanged",
        "hasDecimalModeChanged",
        "autoScrollEnabledChanged",
        "lineEndingMode",
        "customLineEnding",
        "dataEncoding",
        "hasDecimalMode",
        "autoScrollEnabled"
    };

    QtMocHelpers::UintData qt_methods {
        // Signal 'lineEndingModeChanged'
        QtMocHelpers::SignalData<void()>(1, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'customLineEndingChanged'
        QtMocHelpers::SignalData<void()>(3, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'dataEncodingChanged'
        QtMocHelpers::SignalData<void()>(4, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'hasDecimalModeChanged'
        QtMocHelpers::SignalData<void()>(5, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'autoScrollEnabledChanged'
        QtMocHelpers::SignalData<void()>(6, 2, QMC::AccessPublic, QMetaType::Void),
    };
    QtMocHelpers::UintData qt_properties {
        // property 'lineEndingMode'
        QtMocHelpers::PropertyData<int>(7, QMetaType::Int, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet, 0),
        // property 'customLineEnding'
        QtMocHelpers::PropertyData<QString>(8, QMetaType::QString, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet, 1),
        // property 'dataEncoding'
        QtMocHelpers::PropertyData<QString>(9, QMetaType::QString, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet, 2),
        // property 'hasDecimalMode'
        QtMocHelpers::PropertyData<bool>(10, QMetaType::Bool, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet, 3),
        // property 'autoScrollEnabled'
        QtMocHelpers::PropertyData<bool>(11, QMetaType::Bool, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet, 4),
    };
    QtMocHelpers::UintData qt_enums {
    };
    return QtMocHelpers::metaObjectData<SettingsStore, qt_meta_tag_ZN13SettingsStoreE_t>(QMC::MetaObjectFlag{}, qt_stringData,
            qt_methods, qt_properties, qt_enums);
}
Q_CONSTINIT const QMetaObject SettingsStore::staticMetaObject = { {
    QMetaObject::SuperData::link<QObject::staticMetaObject>(),
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN13SettingsStoreE_t>.stringdata,
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN13SettingsStoreE_t>.data,
    qt_static_metacall,
    nullptr,
    qt_staticMetaObjectRelocatingContent<qt_meta_tag_ZN13SettingsStoreE_t>.metaTypes,
    nullptr
} };

void SettingsStore::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    auto *_t = static_cast<SettingsStore *>(_o);
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: _t->lineEndingModeChanged(); break;
        case 1: _t->customLineEndingChanged(); break;
        case 2: _t->dataEncodingChanged(); break;
        case 3: _t->hasDecimalModeChanged(); break;
        case 4: _t->autoScrollEnabledChanged(); break;
        default: ;
        }
    }
    if (_c == QMetaObject::IndexOfMethod) {
        if (QtMocHelpers::indexOfMethod<void (SettingsStore::*)()>(_a, &SettingsStore::lineEndingModeChanged, 0))
            return;
        if (QtMocHelpers::indexOfMethod<void (SettingsStore::*)()>(_a, &SettingsStore::customLineEndingChanged, 1))
            return;
        if (QtMocHelpers::indexOfMethod<void (SettingsStore::*)()>(_a, &SettingsStore::dataEncodingChanged, 2))
            return;
        if (QtMocHelpers::indexOfMethod<void (SettingsStore::*)()>(_a, &SettingsStore::hasDecimalModeChanged, 3))
            return;
        if (QtMocHelpers::indexOfMethod<void (SettingsStore::*)()>(_a, &SettingsStore::autoScrollEnabledChanged, 4))
            return;
    }
    if (_c == QMetaObject::ReadProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 0: *reinterpret_cast<int*>(_v) = _t->lineEndingMode(); break;
        case 1: *reinterpret_cast<QString*>(_v) = _t->customLineEnding(); break;
        case 2: *reinterpret_cast<QString*>(_v) = _t->dataEncoding(); break;
        case 3: *reinterpret_cast<bool*>(_v) = _t->hasDecimalMode(); break;
        case 4: *reinterpret_cast<bool*>(_v) = _t->autoScrollEnabled(); break;
        default: break;
        }
    }
    if (_c == QMetaObject::WriteProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 0: _t->setLineEndingMode(*reinterpret_cast<int*>(_v)); break;
        case 1: _t->setCustomLineEnding(*reinterpret_cast<QString*>(_v)); break;
        case 2: _t->setDataEncoding(*reinterpret_cast<QString*>(_v)); break;
        case 3: _t->setHasDecimalMode(*reinterpret_cast<bool*>(_v)); break;
        case 4: _t->setAutoScrollEnabled(*reinterpret_cast<bool*>(_v)); break;
        default: break;
        }
    }
}

const QMetaObject *SettingsStore::metaObject() const
{
    return QObject::d_ptr->metaObject ? QObject::d_ptr->dynamicMetaObject() : &staticMetaObject;
}

void *SettingsStore::qt_metacast(const char *_clname)
{
    if (!_clname) return nullptr;
    if (!strcmp(_clname, qt_staticMetaObjectStaticContent<qt_meta_tag_ZN13SettingsStoreE_t>.strings))
        return static_cast<void*>(this);
    return QObject::qt_metacast(_clname);
}

int SettingsStore::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        if (_id < 5)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 5;
    }
    if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        if (_id < 5)
            *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType();
        _id -= 5;
    }
    if (_c == QMetaObject::ReadProperty || _c == QMetaObject::WriteProperty
            || _c == QMetaObject::ResetProperty || _c == QMetaObject::BindableProperty
            || _c == QMetaObject::RegisterPropertyMetaType) {
        qt_static_metacall(this, _c, _id, _a);
        _id -= 5;
    }
    return _id;
}

// SIGNAL 0
void SettingsStore::lineEndingModeChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 0, nullptr);
}

// SIGNAL 1
void SettingsStore::customLineEndingChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 1, nullptr);
}

// SIGNAL 2
void SettingsStore::dataEncodingChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 2, nullptr);
}

// SIGNAL 3
void SettingsStore::hasDecimalModeChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 3, nullptr);
}

// SIGNAL 4
void SettingsStore::autoScrollEnabledChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 4, nullptr);
}
QT_WARNING_POP
