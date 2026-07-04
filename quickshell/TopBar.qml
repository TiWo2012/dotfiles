import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root
    required property var modelData
    anchors { left: true; top: true; right: true }
    margins { top: 10; left: 10; right: 10 }
    color: "transparent"

    property string clockText: ""
    property string activeWindowTitle: ""
    property bool _showDate: false

    property var cpuUsage: []
    property real cpuTotal: 0
    property bool _cpuDropdownVisible: false
    property bool _cpuHoverActive: false

    signal openCalendar
    signal openBluetooth
    signal openNetwork
    signal openAudio
    signal openBtop

    implicitHeight: 26
    exclusiveZone: 26
    aboveWindows: false

    function _updateClock() {
        const n = new Date()
        const days = ["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"]
        const months = ["January","February","March","April","May","June","July","August","September","October","November","December"]
        const time = days[n.getDay()] + " " + n.getHours().toString().padStart(2,"0") + ":" + n.getMinutes().toString().padStart(2,"0")
        const date = n.getDate().toString().padStart(2,"0") + " " + months[n.getMonth()] + " W" + root._weekNumber(n) + " " + n.getFullYear()
        root.clockText = root._showDate ? date : time
    }

    function _weekNumber(d) {
        const utc = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()))
        utc.setUTCDate(utc.getUTCDate() + 4 - (utc.getUTCDay() || 7))
        const yearStart = new Date(Date.UTC(utc.getUTCFullYear(), 0, 1))
        return Math.ceil((((utc - yearStart) / 86400000) + 1) / 7)
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root._updateClock()
    }

    Timer {
        id: cpuDropdownHideTimer
        interval: 200
        onTriggered: {
            root._cpuDropdownVisible = false
            root._cpuHoverActive = false
        }
    }

    PanelWindow {
        id: cpuDropdown
        visible: root._cpuDropdownVisible
        implicitWidth: 180
        implicitHeight: 24 + (root.cpuUsage.length + 1) * 15
        color: "transparent"
        anchors.right: true
        anchors.top: true
        margins { top: 40; right: 10 }
        exclusiveZone: -1
        aboveWindows: true

        Rectangle {
            anchors.fill: parent
            color: "#CC1a1b2e"
            radius: 10

            layer.enabled: true
            layer.effect: MultiEffect {
                blurEnabled: true
                blurMax: 32
                brightness: -0.1
                saturation: 0.2
            }

            Rectangle {
                anchors.fill: parent
                radius: 10
                color: "transparent"
                border.color: "#33ffffff"
                border.width: 1
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: 9
                color: "#10ffffff"
            }

            Column {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 1
                Text {
                    text: "CPU " + root.cpuTotal.toFixed(1) + "%"
                    color: "#ffffff"
                    font.family: "FiraCodeNerdFont"
                    font.pixelSize: 11
                    leftPadding: 4
                }
                Repeater {
                    model: root.cpuUsage.length
                    Text {
                        text: "C" + index + " " + root.cpuUsage[index].toFixed(1) + "%"
                        color: "#aaffffff"
                        font.family: "FiraCodeNerdFont"
                        font.pixelSize: 11
                        leftPadding: 4
                    }
                }
            }

            MouseArea {
                id: dropdownArea
                anchors.fill: parent
                hoverEnabled: true
                onEntered: cpuDropdownHideTimer.stop()
                onExited: {
                    if (!cpuArea.containsMouse) cpuDropdownHideTimer.restart()
                }
            }
        }
    }

    Rectangle {
        id: glassBg
        anchors.fill: parent
        color: "#CC1a1b2e"
        radius: 13
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
            radius: 13
            color: "transparent"
            border.color: "#33ffffff"
            border.width: 1
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: 12
            color: "#10ffffff"
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 8

            Item {
                id: powerItem
                Layout.fillHeight: true
                implicitWidth: powerLabel.implicitWidth

                Text {
                    id: powerLabel
                    anchors.centerIn: parent
                    text: "⏻"
                    color: "#ffffff"
                    font.family: "FiraCodeNerdFont"
                    font.pixelSize: 13
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached({ command: ["sh", "/home/timo/.config/quickshell/powermenu.sh"] })
                }
            }

            Item {
                id: titleItem
                Layout.fillHeight: true
                implicitWidth: titleText.implicitWidth

                Text {
                    id: titleText
                    anchors.centerIn: parent
                    text: activeWindowTitle || " niri"
                    color: "#ffffff"
                    font.family: "FiraCodeNerdFont"
                    font.pixelSize: 13
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }

            Item { Layout.fillWidth: true }

            Item {
                id: clockItem
                Layout.fillHeight: true
                implicitWidth: clockLabel.implicitWidth

                Text {
                    id: clockLabel
                    anchors.centerIn: parent
                    text: root.clockText
                    color: "#ffffff"
                    font.family: "FiraCodeNerdFont"
                    font.pixelSize: 13
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: {
                        if (mouse.button === Qt.RightButton) root.openCalendar()
                        else {
                            root._showDate = !root._showDate
                            root._updateClock()
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true }

            Item {
                id: iconGroup
                Layout.fillHeight: true
                implicitWidth: iconRow.implicitWidth

                RowLayout {
                    id: iconRow
                    anchors.centerIn: parent
                    spacing: 8

                    Item {
                        width: cpuTxt.width; height: cpuTxt.height
                        Text { id: cpuTxt; text: "󰍛"; color: "#ffffff"; font.family: "FiraCodeNerdFont"; font.pixelSize: 13 }
                        MouseArea {
                            id: cpuArea
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton
                            onClicked: root.openBtop()
                            onEntered: {
                                cpuDropdownHideTimer.stop()
                                root._cpuDropdownVisible = true
                                root._cpuHoverActive = true
                            }
                            onExited: {
                                if (!root._cpuHoverActive) return
                                cpuDropdownHideTimer.restart()
                            }
                        }
                    }

                    Item {
                        width: btTxt.width; height: btTxt.height
                        Text { id: btTxt; text: ""; color: "#ffffff"; font.family: "FiraCodeNerdFont"; font.pixelSize: 13 }
                        MouseArea {
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: root.openBluetooth()
                        }
                    }

                    Item {
                        width: netTxt.width; height: netTxt.height
                        Text { id: netTxt; text: "󰤨"; color: "#ffffff"; font.family: "FiraCodeNerdFont"; font.pixelSize: 13 }
                        MouseArea {
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: root.openNetwork()
                        }
                    }

                    Item {
                        width: audTxt.width; height: audTxt.height
                        Text { id: audTxt; text: ""; color: "#ffffff"; font.family: "FiraCodeNerdFont"; font.pixelSize: 13 }
                        MouseArea {
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: root.openAudio()
                        }
                    }
                }
            }
        }
    }
}
