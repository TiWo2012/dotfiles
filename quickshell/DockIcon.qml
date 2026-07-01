import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets

Item {
    id: root
    width: 56
    height: 56

    property string icon
    property string label
    property color highlightColor: "#7ec8e3"
    signal clicked

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: 16
        color: mouseArea.containsMouse ? "#33ffffff" : "transparent"
        Behavior on color { PropertyAnimation { duration: 150 } }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            radius: 14
            color: "transparent"
            border.color: mouseArea.containsMouse ? "#22ffffff" : "transparent"
            border.width: 1
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 2

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.icon
            color: "#ffffff"
            font.family: "FiraCodeNerdFont"
            font.pixelSize: 24
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.label
            color: "#aaffffff"
            font.family: "FiraCodeNerdFont"
            font.pixelSize: 9
            visible: mouseArea.containsMouse
        }
    }

    Rectangle {
        id: indicator
        width: 8
        height: 2
        radius: 1
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 2
        color: root.highlightColor
        opacity: 0.0
        Behavior on opacity { PropertyAnimation { duration: 200 } }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
