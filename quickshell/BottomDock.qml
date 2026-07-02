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

    property bool workspaceEmpty: true
    signal summonWalker
    signal summonKitty
    signal summonFirefox
    signal summonYoutube

    property bool _proximity: false
    readonly property bool _shouldShow: workspaceEmpty || _proximity

    implicitWidth: 300
    implicitHeight: 56
    exclusiveZone: workspaceEmpty ? 56 : -1
    aboveWindows: !workspaceEmpty
    color: "transparent"

    Rectangle {
        id: glassBg
        anchors.fill: parent
        anchors.bottomMargin: 0
        color: root._shouldShow ? "#CC1a1b2e" : "transparent"
        radius: 20
        clip: true

        Behavior on color { PropertyAnimation { duration: 200; easing.type: Easing.InCubic } }

        layer.enabled: root._shouldShow
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
            opacity: root._shouldShow ? 1 : 0
            Behavior on opacity { PropertyAnimation { duration: 200; easing.type: Easing.InCubic } }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: 19
            color: "#10ffffff"
            opacity: root._shouldShow ? 1 : 0
            Behavior on opacity { PropertyAnimation { duration: 200; easing.type: Easing.InCubic } }
        }
    }

    MouseArea {
        id: activationArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton

        onEntered: {
            hideTimer.stop()
            if (!root.workspaceEmpty) root._proximity = true
        }

        onExited: {
            if (!root.workspaceEmpty) hideTimer.start()
        }

        Timer {
            id: hideTimer
            interval: 800
            onTriggered: {
                if (!root.workspaceEmpty) root._proximity = false
            }
        }
    }

    RowLayout {
        id: dockRow
        anchors.centerIn: parent
        spacing: 12
        anchors.verticalCenterOffset: root._shouldShow ? 0 : 120
        opacity: root._shouldShow ? 1 : 0

        transform: Scale {
            origin.x: dockRow.width / 2
            origin.y: dockRow.height
            xScale: root._shouldShow ? 1.0 : 1.06
            yScale: root._shouldShow ? 1.0 : 0.01
            Behavior on xScale { PropertyAnimation { duration: 180; easing.type: Easing.InCubic } }
            Behavior on yScale { PropertyAnimation { duration: 180; easing.type: Easing.InCubic } }
        }

        Behavior on anchors.verticalCenterOffset { PropertyAnimation { duration: 200; easing.type: Easing.InCubic } }
        Behavior on opacity { PropertyAnimation { duration: 200; easing.type: Easing.InCubic } }

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
