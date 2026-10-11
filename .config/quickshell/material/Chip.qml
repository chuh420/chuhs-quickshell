import QtQuick
import QtQuick.Controls
Rectangle {
    id: root
    property bool compact: false
    property int fontSize: compact ? 11 : 12
    property int iconSize: fontSize
    property string label
    property color ink: Theme.text
    property bool selected: false
    property string shortcut: ""
    signal clicked()
    signal rightClicked()
    signal scrolled(int delta)
    implicitWidth: text.implicitWidth + (compact ? 16 : 24)
    implicitHeight: compact ? 22 : 30
    radius: compact ? 6 : 10
    color: selected ? Theme.elevated : mouse.containsMouse ? Theme.elevated : "transparent"
    Behavior on color { ColorAnimation { duration: 140 } }
    Text { id: text; anchors.centerIn: parent; text: Array.from(root.label).map(value => value.codePointAt(0) >= 0xe000 ? '<span style="font-size: ' + root.iconSize + 'px">' + value + '</span>' : value === '&' ? '&amp;' : value === '<' ? '&lt;' : value === '>' ? '&gt;' : value).join(""); textFormat: Text.RichText; color: root.ink; font.family: Theme.icons; font.pixelSize: root.fontSize }
    BindToolTip {
        text: root.shortcut
        below: root.compact
        visible: mouse.containsMouse && root.shortcut !== ""
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: event => event.button === Qt.RightButton ? root.rightClicked() : root.clicked()
        onWheel: event => root.scrolled(event.angleDelta.y)
    }
}
