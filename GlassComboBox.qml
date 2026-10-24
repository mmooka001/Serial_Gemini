pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

ComboBox {
    id: control

    property bool dark: true
    property bool portDetails: false
    property color textColor: "#ffffff"
    property color secondaryTextColor: "#afb1b3"
    property color inputColor: "#1e1f22"
    property color surfaceColor: "#2b2d30"
    property color outlineColor: "#22ffffff"
    property color accentColor: "#3574f0"

    hoverEnabled: true
    leftPadding: 12
    rightPadding: 30
    topPadding: 0
    bottomPadding: 0
    font.pixelSize: 12

    background: Rectangle {
        radius: 9
        color: control.inputColor
        border.color: control.popup.visible || control.visualFocus
                      ? Qt.rgba(control.accentColor.r, control.accentColor.g, control.accentColor.b, 0.55)
                      : control.outlineColor
        Behavior on border.color { ColorAnimation { duration: 140 } }
    }
    contentItem: Text {
        text: control.displayText
        color: control.textColor
        font: control.font
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    indicator: Text {
        x: control.width - width - 11
        y: (control.height - height) / 2
        text: "\uE70D"
        font.family: "Segoe Fluent Icons"
        font.pixelSize: 10
        color: control.secondaryTextColor
        rotation: control.popup.visible ? 180 : 0
        Behavior on rotation { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    }

    delegate: ItemDelegate {
        id: option
        required property int index
        required property var modelData
        width: optionsView.width
        implicitHeight: Math.max(36, contentItem.implicitHeight + topPadding + bottomPadding)
        leftPadding: 12
        rightPadding: 28
        topPadding: control.portDetails ? 9 : 7
        bottomPadding: topPadding
        hoverEnabled: true
        highlighted: control.highlightedIndex === index

        contentItem: Column {
            spacing: 4
            Text {
                width: parent.width
                text: control.textRole ? String(option.modelData[control.textRole]) : String(option.modelData)
                color: control.textColor
                font.pixelSize: 12
                font.weight: control.currentIndex === option.index ? Font.DemiBold : Font.Normal
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                visible: control.portDetails && text.length > 0
                text: {
                    if (!control.portDetails)
                        return ""
                    var info = option.modelData
                    return (info.description || "")
                            + (info.manufacturer ? " (" + info.manufacturer + ")" : "")
                }
                color: control.secondaryTextColor
                font.pixelSize: 10
                wrapMode: Text.Wrap
            }
        }
        background: Item { }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: "\uE73E"
            font.family: "Segoe Fluent Icons"
            font.pixelSize: 10
            color: control.accentColor
            visible: control.currentIndex === option.index
        }
    }

    popup: Popup {
        id: menu
        y: control.height + 6
        width: Math.max(control.width, 120)
        implicitHeight: Math.min(optionsView.contentHeight + topPadding + bottomPadding, 280)
        padding: 6
        topMargin: 6
        bottomMargin: 6
        onAboutToShow: glass.animationsEnabled = false
        onOpened: {
            optionsView.forceLayout()
            optionsView.positionViewAtIndex(control.currentIndex, ListView.Contain)
            Qt.callLater(function() { glass.animationsEnabled = true })
        }
        onClosed: glass.animationsEnabled = false

        background: Rectangle {
            color: control.surfaceColor
            radius: 12
            border.color: control.outlineColor
        }
        contentItem: Item {
            implicitHeight: optionsView.contentHeight

            ListView {
                id: optionsView
                anchors.fill: parent
                clip: true
                model: menu.visible ? control.delegateModel : null
                currentIndex: control.highlightedIndex
                highlight: null
                cacheBuffer: 400
                boundsBehavior: Flickable.StopAtBounds
                ScrollIndicator.vertical: ScrollIndicator { }
            }

            LiquidGlassSelection {
                id: glass
                anchors.fill: parent
                clip: true
                sourceItem: optionsView.contentItem
                sourceRect: Qt.rect(0, optionsView.contentY, optionsView.width, optionsView.height)
                selectedIndex: optionsView.currentIndex
                selectedItem: optionsView.currentItem
                horizontalInset: 2
                verticalInset: 1
                moveDuration: 220
                magnification: 1.02
                glassStrength: 1.6
                dark: control.dark
            }
        }
    }
}
