#include "../CommandStore.h"
#include <QCoreApplication>
#include <QScopeGuard>
#include <QUuid>
#include <QTemporaryDir>
#include <cassert>
#include <iostream>

int main(int argc, char **argv) {
    QCoreApplication app(argc, argv);
    app.setOrganizationName("GeminiTests");
    app.setApplicationName("CommandOrder_" + QUuid::createUuid().toString(QUuid::Id128));
    QStandardPaths::setTestModeEnabled(true);
    const QString directory = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    const auto cleanup = qScopeGuard([directory] {
        QFile::remove(directory + "/commands.json");
        QDir().rmdir(directory);
    });

    QTemporaryDir commandDirectory;
    CommandStore store(nullptr, commandDirectory.path());
    store.addGroup("Commands");
    store.addCommand(0, "A", "AA", true);
    store.addCommand(0, "B", "AT", false);
    store.addCommand(0, "C", "CC", true);
    store.addGroup("Other");
    store.addCommand(1, "D", "DD", true);
    const QVariantList original = store.groups();
    int changes = 0;
    QObject::connect(&store, &CommandStore::groupsChanged, [&] { ++changes; });
    assert(!store.moveCommand(-1, 0, 1));
    assert(!store.moveCommand(0, -1, 1));
    assert(!store.moveCommand(0, 0, 3));
    assert(store.groups() == original && changes == 0);

    assert(store.moveCommand(0, 0, 2, {{"name", "Edited A"}, {"payload", "AA 55"}}));
    QVariantList commands = store.groups()[0].toMap()["commands"].toList();
    assert(commands[0].toMap()["name"] == "B");
    assert(commands[1].toMap()["name"] == "C");
    assert(commands[2].toMap()["name"] == "Edited A");
    assert(commands[2].toMap()["payload"] == "AA 55");
    assert(commands[2].toMap()["isHex"].toBool());
    assert(store.groups()[1] == original[1] && changes == 1);
    assert(store.moveCommand(0, 2, 0));
    commands = store.groups()[0].toMap()["commands"].toList();
    assert(commands[0].toMap()["name"] == "Edited A");
    assert(commands[1].toMap()["name"] == "B");
    assert(!commands[1].toMap()["isHex"].toBool());
    CommandStore reloaded(nullptr, commandDirectory.path());
    assert(reloaded.groups() == store.groups());
    std::cout << "Command reordering preserves edits, modes, other groups and saved order.\n";
}
