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
