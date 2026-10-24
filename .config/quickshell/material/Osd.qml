import QtQuick
import Quickshell
import Quickshell.Wayland
PanelWindow {
    id: window
    required property var shell
    property bool open: false
    property real reveal: 0
    readonly property string kind: shell.osdKind
    readonly property bool hasBar: kind === "volume" || kind === "brightness"
    readonly property real level: kind === "volume" ? (shell.muted ? 0 : shell.volume) : kind === "brightness" ? shell.brightness : 0
    screen: shell.focusedScreen
    visible: open || reveal > 0
    anchors { bottom: true }
    margins { bottom: 72 }
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 300 * Theme.uiScale
    implicitHeight: 60 * Theme.uiScale
    color: "transparent"
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "material-osd"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    Behavior on reveal { NumberAnimation { duration: window.open ? 260 : 180; easing.type: window.open ? Easing.OutBack : Easing.InCubic } }
    Connections {
        target: window.shell
        function onOsdSerialChanged() { window.open = true; window.reveal = 1; hide.restart(); bump.restart() }
    }
    Timer { id: hide; interval: 1400; onTriggered: { window.open = false; window.reveal = 0 } }
    function icon() {
        if (kind === "volume") return shell.muted ? "󰖁" : shell.volume > 66 ? "󰕾" : shell.volume > 33 ? "󰖀" : "󰕿"
        if (kind === "brightness") return shell.brightness > 66 ? "󰃠" : shell.brightness > 33 ? "󰃟" : "󰃞"
        if (kind === "mic") return shell.micMuted ? "󰍭" : "󰍬"
        if (kind === "clipboard") return "󰅍"
        if (kind === "layout") return "󰕰"
        if (kind === "hotkeys") return shell.hotkeysPaused ? "󰌐" : "󰌌"
        return "󰌌"
    }
    function caption() {
        if (kind === "volume") return shell.muted ? "muted" : shell.volume + "%"
        if (kind === "brightness") return shell.brightness + "%"
        if (kind === "mic") return shell.micMuted ? "microphone muted" : "microphone on"
        if (kind === "clipboard" || kind === "layout") return shell.osdText
        if (kind === "hotkeys") return shell.hotkeysPaused ? "hotkeys paused · super + esc" : "hotkeys active"
        return shell.keyboardLayout.name || shell.keyboardLayout.label
    }
    property real pulse: 1
    SequentialAnimation {
        id: bump
        NumberAnimation { target: window; property: "pulse"; to: 1.18; duration: 80; easing.type: Easing.OutQuad }
        SpringAnimation { target: window; property: "pulse"; to: 1; spring: 5; damping: 0.3 }
    }
    Rectangle {
        id: pill
        width: 300
        height: 60
        scale: Theme.uiScale
        transformOrigin: Item.TopLeft
        radius: 18
        color: Theme.bg
        border.color: Theme.line
        opacity: Math.max(0, Math.min(1, window.reveal))
        transform: [
            Translate { y: 18 * (1 - window.reveal) },
            Scale { origin.x: 150; origin.y: 30; xScale: 0.9 + 0.1 * window.reveal; yScale: 0.9 + 0.1 * window.reveal }
        ]
        Row {
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 20; rightMargin: 20 }
            spacing: 14
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: 24
                horizontalAlignment: Text.AlignHCenter
                text: window.icon()
                color: window.kind === "brightness" || (window.kind === "hotkeys" && window.shell.hotkeysPaused) ? Theme.yellow : (window.kind === "volume" && window.shell.muted) || (window.kind === "mic" && window.shell.micMuted) ? Theme.muted : Theme.green
                Behavior on color { ColorAnimation { duration: Theme.normal } }
                font.family: Theme.icons
                font.pixelSize: 22
                scale: window.pulse
            }
            Rectangle {
                visible: window.hasBar
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 24 - 44 - 28
                height: 6
                radius: 3
                color: Theme.elevated
                Rectangle {
                    width: parent.width * Math.max(0, Math.min(100, window.level)) / 100
                    height: parent.height
                    radius: 3
                    color: window.kind === "brightness" ? Theme.yellow : Theme.green
                    Behavior on width { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: Theme.normal } }
                }
            }
            SwapText {
                anchors.verticalCenter: parent.verticalCenter
                width: window.hasBar ? 44 : parent.width - 24 - 14
                height: 18
                text: window.caption()
                color: Theme.text
                family: window.hasBar ? Theme.icons : Theme.font
                pixelSize: window.hasBar ? 12 : 14
                distance: 5
            }
        }
    }
}
