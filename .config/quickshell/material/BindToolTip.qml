import QtQuick
import QtQuick.Controls

ToolTip {
    id: tip
    property bool below: false
    delay: 650
    popupType: Popup.Window
    x: parent ? (parent.width - implicitWidth) / 2 : 0
    y: below && parent ? parent.height + 8 : -implicitHeight - 8
    margins: 8
    enter: Transition { ParallelAnimation { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.fast; easing.type: Easing.OutCubic } NumberAnimation { property: "scale"; from: 0.94; to: 1; duration: Theme.normal; easing.type: Easing.OutBack } } }
    exit: Transition { NumberAnimation { property: "opacity"; to: 0; duration: 100 } }
    horizontalPadding: Math.round(10 * Theme.uiScale)
    verticalPadding: Math.round(6 * Theme.uiScale)
    contentItem: Text {
        text: tip.text
        color: Theme.text
        font.family: Theme.font
        font.pixelSize: Math.round(11 * Theme.uiScale)
        wrapMode: Text.NoWrap
    }
    background: Rectangle {
        color: Theme.surface
        border.color: Theme.line
        border.width: 1
        radius: 8
    }
}
