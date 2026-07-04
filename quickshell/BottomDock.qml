import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root
    required property var modelData
    anchors { bottom: true }
    margins { bottom: 10 }

    signal summonWalker
    signal summonKitty
    signal summonFirefox
    signal summonYoutube

    implicitWidth: 300
    implicitHeight: 56
    exclusiveZone: 56
    aboveWindows: false
    color: "transparent"

    Rectangle {
        id: glassBg
        anchors.fill: parent
        anchors.bottomMargin: 0
        color: "#CC1a1b2e"
        radius: 20
        clip: true

        layer.enabled: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blurMax: 32
            brightness: -0.1
            saturation: 0.2
        }

        Rectangle {
            anchors.fill: parent
            radius: 20
            color: "transparent"
            border.color: "#33ffffff"
            border.width: 1
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: 19
            color: "#10ffffff"
        }
    }

    RowLayout {
        id: dockRow
        anchors.centerIn: parent
        spacing: 12

        DockIcon {
            icon: ""
            label: "Walker"
            onClicked: summonWalker()
            highlightColor: "#7ec8e3"
        }

        Rectangle {
            width: 1
            height: 36
            color: "#44ffffff"
            Layout.alignment: Qt.AlignVCenter
        }

        DockIcon {
            icon: ""
            label: "Kitty"
            onClicked: summonKitty()
            highlightColor: "#7ec8e3"
        }

        DockIcon {
            icon: "󰈹"
            label: "Firefox"
            onClicked: summonFirefox()
            highlightColor: "#7ec8e3"
        }

        DockIcon {
            icon: "󰗃"
            label: "YouTube"
            onClicked: summonYoutube()
            highlightColor: "#ff4444"
        }
    }
}
