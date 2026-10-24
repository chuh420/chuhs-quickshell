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
        Rectangle {
            width: parent.width * control.visualPosition
            height: 6
            radius: 3
            color: control.accent
            Behavior on width { enabled: !control.pressed; NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: Theme.normal } }
        }
    }
    handle: Rectangle {
        property real size: control.pressed ? 18 : sliderHover.hovered ? 16 : 14
        x: control.leftPadding + control.visualPosition * (control.availableWidth - 14) - (size - 14) / 2
        y: (control.height - height) / 2
        implicitWidth: size
        implicitHeight: size
        width: implicitWidth
        height: implicitHeight
        radius: size / 2.3
        color: control.pressed ? control.accent : Theme.text
        Behavior on x { enabled: !control.pressed; NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
        Behavior on size { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: Theme.fast } }
    }
}
