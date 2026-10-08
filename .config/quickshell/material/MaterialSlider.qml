import QtQuick
import QtQuick.Controls
Slider {
    id: control
    implicitWidth: 200
    implicitHeight: 32
    padding: 7
    property color accent: Theme.green
    property string shortcut: ""
    from: 0
    to: 100
    live: true
    snapMode: Slider.NoSnap
    HoverHandler { id: sliderHover }
    BindToolTip {
        text: control.shortcut
        visible: sliderHover.hovered && control.shortcut !== ""
    }
    background: Rectangle {
        implicitWidth: 200
        implicitHeight: 6
        x: control.leftPadding
        y: (control.height - height) / 2
        width: control.availableWidth
        height: 6
        radius: 3
        color: Theme.elevated
        Rectangle { width: parent.width * control.visualPosition; height: 6; radius: 3; color: control.accent }
    }
    handle: Rectangle {
        x: control.leftPadding + control.visualPosition * (control.availableWidth - width)
        y: (control.height - height) / 2
        implicitWidth: 14
        implicitHeight: 14
        width: implicitWidth
        height: implicitHeight
        radius: 6
        color: Theme.text
    }
}
