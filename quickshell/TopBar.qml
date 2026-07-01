import QtQuick
import QtQuick.Layouts
import Quickshell

PanelWindow {
    id: root
    anchors { left: true; top: true; right: true }
    implicitHeight: 26
    margins { top: 10; left: 10; right: 10 }
    exclusiveZone: implicitHeight
    color: "transparent"

    property string clockText: ""
    property string activeWindowTitle: ""
    property bool _showDate: false

    signal openCalendar
    signal openBluetooth
    signal openNetwork
    signal openAudio

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
        onTriggered: {
            const n = new Date()
            const days = ["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"]
            const months = ["January","February","March","April","May","June","July","August","September","October","November","December"]
            const time = days[n.getDay()] + " " + n.getHours().toString().padStart(2,"0") + ":" + n.getMinutes().toString().padStart(2,"0")
            const date = n.getDate().toString().padStart(2,"0") + " " + months[n.getMonth()] + " W" + root._weekNumber(n) + " " + n.getFullYear()
            root.clockText = root._showDate ? date : time
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 6

        Rectangle {
            id: leftPill
            Layout.fillHeight: true
            Layout.preferredWidth: leftText.implicitWidth + 28
            color: "#80000000"
            radius: 25
            clip: true

            Text {
                id: leftText
                x: 14
                anchors.verticalCenter: parent.verticalCenter
                text: activeWindowTitle || " niri"
                color: "#ffffff"
                font.family: "FiraCodeNerdFont"
                font.pixelSize: 13
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }

        Item { Layout.fillWidth: true }

        Rectangle {
            id: clockPill
            Layout.fillHeight: true
            Layout.preferredWidth: clockText.implicitWidth + 28
            color: "#80000000"
            radius: 25
            clip: true

            Text {
                id: clockText
                x: 14
                anchors.verticalCenter: parent.verticalCenter
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
                    else root._showDate = !root._showDate
                }
            }
        }

        Item { Layout.fillWidth: true }

        Rectangle {
            id: rightPill
            Layout.fillHeight: true
            Layout.preferredWidth: iconRow.implicitWidth + 28
            color: "#80000000"
            radius: 25
            clip: true

            RowLayout {
                id: iconRow
                x: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Text { text: "󰍛"; color: "#ffffff"; font.family: "FiraCodeNerdFont"; font.pixelSize: 13 }
                Text { text: ""; color: "#ffffff"; font.family: "FiraCodeNerdFont"; font.pixelSize: 13 }
                Text { text: "󰤨"; color: "#ffffff"; font.family: "FiraCodeNerdFont"; font.pixelSize: 13 }
                Text { text: ""; color: "#ffffff"; font.family: "FiraCodeNerdFont"; font.pixelSize: 13 }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                onClicked: {
                    const cx = mouse.x
                    for (let i = 0; i < iconRow.children.length; i++) {
                        const item = iconRow.children[i]
                        const itemX = iconRow.x + item.x
                        if (cx >= itemX && cx <= itemX + item.width) {
                            if (i === 0) {}
                            else if (i === 1) root.openBluetooth()
                            else if (i === 2) root.openNetwork()
                            else if (i === 3) root.openAudio()
                        }
                    }
                }
                cursorShape: Qt.PointingHandCursor
            }
        }
    }
}
