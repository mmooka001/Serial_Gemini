/****************************************************************************
** Meta object code from reading C++ file 'CommandStore.h'
**
** Created by: The Qt Meta Object Compiler version 69 (Qt 6.11.0)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../../../CommandStore.h"
#include <QtCore/qmetatype.h>

#include <QtCore/qtmochelpers.h>

#include <memory>


#include <QtCore/qxptype_traits.h>
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'CommandStore.h' doesn't include <QObject>."
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
struct qt_meta_tag_ZN12CommandStoreE_t {};
} // unnamed namespace

template <> constexpr inline auto CommandStore::qt_create_metaobjectdata<qt_meta_tag_ZN12CommandStoreE_t>()
{
    namespace QMC = QtMocConstants;
    QtMocHelpers::StringRefStorage qt_stringData {
        "CommandStore",
        "groupsChanged",
        "",
        "addGroup",
        "name",
        "addCommand",
        "groupIndex",
        "payload",
        "isHex",
        "updateGroupName",
        "index",
        "updateCommand",
        "cmdIndex",
        "setCommandHex",
        "deleteGroup",
        "deleteCommand",
        "exportToFile",
        "path",
        "importFromFile",
        "groups",
        "QVariantList"
    };

    QtMocHelpers::UintData qt_methods {
        // Signal 'groupsChanged'
        QtMocHelpers::SignalData<void()>(1, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'addGroup'
        QtMocHelpers::MethodData<void(const QString &)>(3, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 4 },
        }}),
        // Method 'addGroup'
        QtMocHelpers::MethodData<void()>(3, 2, QMC::AccessPublic | QMC::MethodCloned, QMetaType::Void),
        // Method 'addCommand'
        QtMocHelpers::MethodData<void(int, const QString &, const QString &, bool)>(5, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::Int, 6 }, { QMetaType::QString, 4 }, { QMetaType::QString, 7 }, { QMetaType::Bool, 8 },
        }}),
        // Method 'addCommand'
        QtMocHelpers::MethodData<void(int, const QString &, const QString &)>(5, 2, QMC::AccessPublic | QMC::MethodCloned, QMetaType::Void, {{
            { QMetaType::Int, 6 }, { QMetaType::QString, 4 }, { QMetaType::QString, 7 },
        }}),
        // Method 'addCommand'
        QtMocHelpers::MethodData<void(int, const QString &)>(5, 2, QMC::AccessPublic | QMC::MethodCloned, QMetaType::Void, {{
            { QMetaType::Int, 6 }, { QMetaType::QString, 4 },
        }}),
        // Method 'addCommand'
        QtMocHelpers::MethodData<void(int)>(5, 2, QMC::AccessPublic | QMC::MethodCloned, QMetaType::Void, {{
            { QMetaType::Int, 6 },
        }}),
        // Method 'updateGroupName'
        QtMocHelpers::MethodData<void(int, const QString &)>(9, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::Int, 10 }, { QMetaType::QString, 4 },
        }}),
        // Method 'updateCommand'
        QtMocHelpers::MethodData<void(int, int, const QString &, const QString &)>(11, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::Int, 6 }, { QMetaType::Int, 12 }, { QMetaType::QString, 4 }, { QMetaType::QString, 7 },
        }}),
        // Method 'setCommandHex'
        QtMocHelpers::MethodData<void(int, int, bool)>(13, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::Int, 6 }, { QMetaType::Int, 12 }, { QMetaType::Bool, 8 },
        }}),
        // Method 'deleteGroup'
        QtMocHelpers::MethodData<void(int)>(14, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::Int, 10 },
        }}),
        // Method 'deleteCommand'
        QtMocHelpers::MethodData<void(int, int)>(15, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::Int, 6 }, { QMetaType::Int, 12 },
        }}),
        // Method 'exportToFile'
        QtMocHelpers::MethodData<void(const QString &)>(16, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 17 },
        }}),
        // Method 'importFromFile'
        QtMocHelpers::MethodData<void(const QString &)>(18, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 17 },
        }}),
    };
    QtMocHelpers::UintData qt_properties {
        // property 'groups'
        QtMocHelpers::PropertyData<QVariantList>(19, 0x80000000 | 20, QMC::DefaultPropertyFlags | QMC::EnumOrFlag, 0),
    };
    QtMocHelpers::UintData qt_enums {
    };
    return QtMocHelpers::metaObjectData<CommandStore, qt_meta_tag_ZN12CommandStoreE_t>(QMC::MetaObjectFlag{}, qt_stringData,
            qt_methods, qt_properties, qt_enums);
}
Q_CONSTINIT const QMetaObject CommandStore::staticMetaObject = { {
    QMetaObject::SuperData::link<QObject::staticMetaObject>(),
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN12CommandStoreE_t>.stringdata,
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN12CommandStoreE_t>.data,
    qt_static_metacall,
    nullptr,
    qt_staticMetaObjectRelocatingContent<qt_meta_tag_ZN12CommandStoreE_t>.metaTypes,
    nullptr
} };

void CommandStore::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    auto *_t = static_cast<CommandStore *>(_o);
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: _t->groupsChanged(); break;
        case 1: _t->addGroup((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 2: _t->addGroup(); break;
        case 3: _t->addCommand((*reinterpret_cast<std::add_pointer_t<int>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[3])),(*reinterpret_cast<std::add_pointer_t<bool>>(_a[4]))); break;
        case 4: _t->addCommand((*reinterpret_cast<std::add_pointer_t<int>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[3]))); break;
        case 5: _t->addCommand((*reinterpret_cast<std::add_pointer_t<int>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2]))); break;
        case 6: _t->addCommand((*reinterpret_cast<std::add_pointer_t<int>>(_a[1]))); break;
        case 7: _t->updateGroupName((*reinterpret_cast<std::add_pointer_t<int>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2]))); break;
        case 8: _t->updateCommand((*reinterpret_cast<std::add_pointer_t<int>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<int>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[3])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[4]))); break;
        case 9: _t->setCommandHex((*reinterpret_cast<std::add_pointer_t<int>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<int>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<bool>>(_a[3]))); break;
        case 10: _t->deleteGroup((*reinterpret_cast<std::add_pointer_t<int>>(_a[1]))); break;
        case 11: _t->deleteCommand((*reinterpret_cast<std::add_pointer_t<int>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<int>>(_a[2]))); break;
        case 12: _t->exportToFile((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 13: _t->importFromFile((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        default: ;
        }
    }
    if (_c == QMetaObject::IndexOfMethod) {
        if (QtMocHelpers::indexOfMethod<void (CommandStore::*)()>(_a, &CommandStore::groupsChanged, 0))
            return;
    }
    if (_c == QMetaObject::ReadProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 0: *reinterpret_cast<QVariantList*>(_v) = _t->groups(); break;
        default: break;
        }
    }
}

const QMetaObject *CommandStore::metaObject() const
{
    return QObject::d_ptr->metaObject ? QObject::d_ptr->dynamicMetaObject() : &staticMetaObject;
}

void *CommandStore::qt_metacast(const char *_clname)
{
    if (!_clname) return nullptr;
    if (!strcmp(_clname, qt_staticMetaObjectStaticContent<qt_meta_tag_ZN12CommandStoreE_t>.strings))
        return static_cast<void*>(this);
    return QObject::qt_metacast(_clname);
}

int CommandStore::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        if (_id < 14)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 14;
    }
    if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        if (_id < 14)
            *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType();
        _id -= 14;
    }
    if (_c == QMetaObject::ReadProperty || _c == QMetaObject::WriteProperty
            || _c == QMetaObject::ResetProperty || _c == QMetaObject::BindableProperty
            || _c == QMetaObject::RegisterPropertyMetaType) {
        qt_static_metacall(this, _c, _id, _a);
        _id -= 1;
    }
    return _id;
}

// SIGNAL 0
void CommandStore::groupsChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 0, nullptr);
}
QT_WARNING_POP
