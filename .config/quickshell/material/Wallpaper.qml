import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
PanelWindow {
    id: window
    required property var modelData
    required property var shell
    screen: modelData
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "material-wallpaper"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    readonly property string target: shell.currentWallpaper ? "file://" + shell.currentWallpaper : ""
    property real originX: width / 2
    property real originY: height / 2
    property real radius: 0
    readonly property real reach: Math.hypot(Math.max(originX, width - originX), Math.max(originY, height - originY)) + 80
    onTargetChanged: {
        if (!target) return
        if (!front.source.toString()) { front.source = target; return }
        if (target === front.source.toString() && !incoming.source.toString()) return
        const origin = shell.wallpaperOrigin
        const local = origin && (!origin.screen || origin.screen === modelData.name)
        originX = local ? origin.x : width / 2
        originY = local ? origin.y : height / 2
        reveal.stop()
        radius = 0
        incoming.source = target
    }
    Image {
        id: front
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: window.width
        sourceSize.height: window.height
        asynchronous: true
        cache: true
        onStatusChanged: if (status === Image.Ready && incoming.source.toString() === source.toString() && !reveal.running) { incoming.source = ""; window.radius = 0 }
    }
    Image {
        id: incoming
        anchors.fill: parent
        visible: false
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: window.width
        sourceSize.height: window.height
        asynchronous: true
        cache: true
        onStatusChanged: if (status === Image.Ready && source.toString()) reveal.restart()
    }
    Item {
        id: circle
        anchors.fill: parent
        opacity: 0
        layer.enabled: true
        Rectangle {
            width: window.radius * 2
            height: width
            radius: width / 2
            x: window.originX - window.radius
            y: window.originY - window.radius
            color: "white"
        }
    }
    MultiEffect {
        anchors.fill: parent
        source: incoming
        visible: incoming.source.toString() !== "" && incoming.status === Image.Ready
        maskEnabled: true
        maskSource: circle
        maskThresholdMin: 0.5
        maskSpreadAtMin: 0.25
        autoPaddingEnabled: false
    }
    NumberAnimation {
        id: reveal
        target: window
        property: "radius"
        from: 0
        to: window.reach
        duration: 900
        easing.type: Easing.InOutCubic
        onFinished: front.source = incoming.source
    }
}
