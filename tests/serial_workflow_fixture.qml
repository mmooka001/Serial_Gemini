import QtQuick
import ".."

QtObject {
    id: workflow
    required property var backend

    property alias inputText: sender.inputText
    property alias hexMode: sender.hexMode
    property alias checksumType: sender.checksumType
    property alias interval: sender.interval
    property alias running: sender.running
    property alias notice: sender.notice
    property alias controller: sender
    property string lastConverted: ""

    property QtObject senderObject: SendController {
        id: sender
        objectName: "sender"
        backend: workflow.backend
        onInputConverted: (hex) => {
            workflow.inputText = hex
            workflow.lastConverted = hex
        }
    }
}
