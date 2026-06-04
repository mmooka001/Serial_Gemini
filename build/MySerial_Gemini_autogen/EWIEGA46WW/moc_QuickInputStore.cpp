/****************************************************************************
** Meta object code from reading C++ file 'QuickInputStore.h'
**
** Created by: The Qt Meta Object Compiler version 69 (Qt 6.11.0)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../../../QuickInputStore.h"
#include <QtCore/qmetatype.h>

#include <QtCore/qtmochelpers.h>

#include <memory>


#include <QtCore/qxptype_traits.h>
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'QuickInputStore.h' doesn't include <QObject>."
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
struct qt_meta_tag_ZN15QuickInputStoreE_t {};
} // unnamed namespace

template <> constexpr inline auto QuickInputStore::qt_create_metaobjectdata<qt_meta_tag_ZN15QuickInputStoreE_t>()
{
    namespace QMC = QtMocConstants;
    QtMocHelpers::StringRefStorage qt_stringData {
        "QuickInputStore",
        "itemsChanged",
        "",
        "isLoopSendingChanged",
        "onLoopTick",
        "onDelayFinished",
        "addItem",
        "name",
        "payload",
        "isHex",
        "delay",
        "enabled",
        "remark",
        "removeItem",
        "index",
        "updateItem",
        "moveItem",
        "from",
        "to",
        "clearAll",
        "enableAll",
        "disableAll",
        "resetDefaults",
        "exportToFile",
        "path",
        "importFromFile",
        "startLoopSend",
        "intervalMs",
        "stopLoopSend",
        "items",
        "QVariantList",
        "isLoopSending"
    };

    QtMocHelpers::UintData qt_methods {
        // Signal 'itemsChanged'
        QtMocHelpers::SignalData<void()>(1, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'isLoopSendingChanged'
        QtMocHelpers::SignalData<void()>(3, 2, QMC::AccessPublic, QMetaType::Void),
        // Slot 'onLoopTick'
        QtMocHelpers::SlotData<void()>(4, 2, QMC::AccessPrivate, QMetaType::Void),
        // Slot 'onDelayFinished'
        QtMocHelpers::SlotData<void()>(5, 2, QMC::AccessPrivate, QMetaType::Void),
        // Method 'addItem'
        QtMocHelpers::MethodData<void(const QString &, const QString &, bool, int, bool, const QString &)>(6, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 7 }, { QMetaType::QString, 8 }, { QMetaType::Bool, 9 }, { QMetaType::Int, 10 },
            { QMetaType::Bool, 11 }, { QMetaType::QString, 12 },
        }}),
        // Method 'addItem'
        QtMocHelpers::MethodData<void(const QString &, const QString &, bool, int, bool)>(6, 2, QMC::AccessPublic | QMC::MethodCloned, QMetaType::Void, {{
            { QMetaType::QString, 7 }, { QMetaType::QString, 8 }, { QMetaType::Bool, 9 }, { QMetaType::Int, 10 },
            { QMetaType::Bool, 11 },
        }}),
        // Method 'addItem'
        QtMocHelpers::MethodData<void(const QString &, const QString &, bool, int)>(6, 2, QMC::AccessPublic | QMC::MethodCloned, QMetaType::Void, {{
            { QMetaType::QString, 7 }, { QMetaType::QString, 8 }, { QMetaType::Bool, 9 }, { QMetaType::Int, 10 },
        }}),
        // Method 'addItem'
        QtMocHelpers::MethodData<void(const QString &, const QString &, bool)>(6, 2, QMC::AccessPublic | QMC::MethodCloned, QMetaType::Void, {{
            { QMetaType::QString, 7 }, { QMetaType::QString, 8 }, { QMetaType::Bool, 9 },
        }}),
        // Method 'addItem'
        QtMocHelpers::MethodData<void(const QString &, const QString &)>(6, 2, QMC::AccessPublic | QMC::MethodCloned, QMetaType::Void, {{
            { QMetaType::QString, 7 }, { QMetaType::QString, 8 },
        }}),
        // Method 'addItem'
        QtMocHelpers::MethodData<void(const QString &)>(6, 2, QMC::AccessPublic | QMC::MethodCloned, QMetaType::Void, {{
            { QMetaType::QString, 7 },
        }}),
        // Method 'addItem'
        QtMocHelpers::MethodData<void()>(6, 2, QMC::AccessPublic | QMC::MethodCloned, QMetaType::Void),
        // Method 'removeItem'
        QtMocHelpers::MethodData<void(int)>(13, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::Int, 14 },
        }}),
        // Method 'updateItem'
        QtMocHelpers::MethodData<void(int, const QString &, const QString &, bool, int, bool, const QString &)>(15, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::Int, 14 }, { QMetaType::QString, 7 }, { QMetaType::QString, 8 }, { QMetaType::Bool, 9 },
            { QMetaType::Int, 10 }, { QMetaType::Bool, 11 }, { QMetaType::QString, 12 },
        }}),
        // Method 'moveItem'
        QtMocHelpers::MethodData<void(int, int)>(16, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::Int, 17 }, { QMetaType::Int, 18 },
        }}),
        // Method 'clearAll'
        QtMocHelpers::MethodData<void()>(19, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'enableAll'
        QtMocHelpers::MethodData<void()>(20, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'disableAll'
        QtMocHelpers::MethodData<void()>(21, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'resetDefaults'
        QtMocHelpers::MethodData<void()>(22, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'exportToFile'
        QtMocHelpers::MethodData<void(const QString &)>(23, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 24 },
        }}),
        // Method 'importFromFile'
        QtMocHelpers::MethodData<void(const QString &)>(25, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 24 },
        }}),
        // Method 'startLoopSend'
        QtMocHelpers::MethodData<void(int)>(26, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::Int, 27 },
        }}),
        // Method 'stopLoopSend'
        QtMocHelpers::MethodData<void()>(28, 2, QMC::AccessPublic, QMetaType::Void),
    };
    QtMocHelpers::UintData qt_properties {
        // property 'items'
        QtMocHelpers::PropertyData<QVariantList>(29, 0x80000000 | 30, QMC::DefaultPropertyFlags | QMC::EnumOrFlag, 0),
        // property 'isLoopSending'
        QtMocHelpers::PropertyData<bool>(31, QMetaType::Bool, QMC::DefaultPropertyFlags, 1),
    };
    QtMocHelpers::UintData qt_enums {
    };
    return QtMocHelpers::metaObjectData<QuickInputStore, qt_meta_tag_ZN15QuickInputStoreE_t>(QMC::MetaObjectFlag{}, qt_stringData,
            qt_methods, qt_properties, qt_enums);
}
Q_CONSTINIT const QMetaObject QuickInputStore::staticMetaObject = { {
    QMetaObject::SuperData::link<QObject::staticMetaObject>(),
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN15QuickInputStoreE_t>.stringdata,
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN15QuickInputStoreE_t>.data,
    qt_static_metacall,
    nullptr,
    qt_staticMetaObjectRelocatingContent<qt_meta_tag_ZN15QuickInputStoreE_t>.metaTypes,
    nullptr
} };

void QuickInputStore::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    auto *_t = static_cast<QuickInputStore *>(_o);
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: _t->itemsChanged(); break;
        case 1: _t->isLoopSendingChanged(); break;
        case 2: _t->onLoopTick(); break;
        case 3: _t->onDelayFinished(); break;
        case 4: _t->addItem((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<bool>>(_a[3])),(*reinterpret_cast<std::add_pointer_t<int>>(_a[4])),(*reinterpret_cast<std::add_pointer_t<bool>>(_a[5])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[6]))); break;
        case 5: _t->addItem((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<bool>>(_a[3])),(*reinterpret_cast<std::add_pointer_t<int>>(_a[4])),(*reinterpret_cast<std::add_pointer_t<bool>>(_a[5]))); break;
        case 6: _t->addItem((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<bool>>(_a[3])),(*reinterpret_cast<std::add_pointer_t<int>>(_a[4]))); break;
        case 7: _t->addItem((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<bool>>(_a[3]))); break;
        case 8: _t->addItem((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2]))); break;
        case 9: _t->addItem((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 10: _t->addItem(); break;
        case 11: _t->removeItem((*reinterpret_cast<std::add_pointer_t<int>>(_a[1]))); break;
        case 12: _t->updateItem((*reinterpret_cast<std::add_pointer_t<int>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[3])),(*reinterpret_cast<std::add_pointer_t<bool>>(_a[4])),(*reinterpret_cast<std::add_pointer_t<int>>(_a[5])),(*reinterpret_cast<std::add_pointer_t<bool>>(_a[6])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[7]))); break;
        case 13: _t->moveItem((*reinterpret_cast<std::add_pointer_t<int>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<int>>(_a[2]))); break;
        case 14: _t->clearAll(); break;
        case 15: _t->enableAll(); break;
        case 16: _t->disableAll(); break;
        case 17: _t->resetDefaults(); break;
        case 18: _t->exportToFile((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 19: _t->importFromFile((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 20: _t->startLoopSend((*reinterpret_cast<std::add_pointer_t<int>>(_a[1]))); break;
        case 21: _t->stopLoopSend(); break;
        default: ;
        }
    }
    if (_c == QMetaObject::IndexOfMethod) {
        if (QtMocHelpers::indexOfMethod<void (QuickInputStore::*)()>(_a, &QuickInputStore::itemsChanged, 0))
            return;
        if (QtMocHelpers::indexOfMethod<void (QuickInputStore::*)()>(_a, &QuickInputStore::isLoopSendingChanged, 1))
            return;
    }
    if (_c == QMetaObject::ReadProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 0: *reinterpret_cast<QVariantList*>(_v) = _t->items(); break;
        case 1: *reinterpret_cast<bool*>(_v) = _t->isLoopSending(); break;
        default: break;
        }
    }
}

const QMetaObject *QuickInputStore::metaObject() const
{
    return QObject::d_ptr->metaObject ? QObject::d_ptr->dynamicMetaObject() : &staticMetaObject;
}

void *QuickInputStore::qt_metacast(const char *_clname)
{
    if (!_clname) return nullptr;
    if (!strcmp(_clname, qt_staticMetaObjectStaticContent<qt_meta_tag_ZN15QuickInputStoreE_t>.strings))
        return static_cast<void*>(this);
    return QObject::qt_metacast(_clname);
}

int QuickInputStore::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        if (_id < 22)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 22;
    }
    if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        if (_id < 22)
            *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType();
        _id -= 22;
    }
    if (_c == QMetaObject::ReadProperty || _c == QMetaObject::WriteProperty
            || _c == QMetaObject::ResetProperty || _c == QMetaObject::BindableProperty
            || _c == QMetaObject::RegisterPropertyMetaType) {
        qt_static_metacall(this, _c, _id, _a);
        _id -= 2;
    }
    return _id;
}

// SIGNAL 0
void QuickInputStore::itemsChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 0, nullptr);
}

// SIGNAL 1
void QuickInputStore::isLoopSendingChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 1, nullptr);
}
QT_WARNING_POP
