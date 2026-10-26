import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.SystemTray
PanelWindow {
    id: bar
    required property var modelData
    required property var shell
    readonly property int sideMargin: Math.round(10 * Theme.uiScale)
    screen: modelData
    anchors { top: true; left: true; right: true }
    margins { top: Math.round(6 * Theme.uiScale); left: sideMargin; right: sideMargin }
    implicitHeight: Math.ceil(28 * Theme.uiScale)
    exclusiveZone: 42 - Math.round(6 * Theme.uiScale)
    color: "transparent"
    WlrLayershell.namespace: "material-bar"
    IdleInhibitor { window: bar; enabled: bar.shell.keepAwake }
    function anchorX(item) { return item.mapToItem(null, item.width / 2, 0).x + sideMargin }
    function batteryIcon(level, plugged) {
        const discharge = ["󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]
        const charge = ["󰢟", "󰢜", "󰂆", "󰂇", "󰂈", "󰢝", "󰂉", "󰢞", "󰂊", "󰂋", "󰂅"]
        const index = Math.max(0, Math.min(10, Math.round(level / 10)))
        return (plugged ? charge : discharge)[index]
    }
    function networkIcon() {
        if (!shell.networkConnected) return "󰤭"
        if (!shell.wifi.connected) return "󰈀"
        const current = shell.wifi.networks.find(network => network.connected)
        const strength = current ? current.strength : 100
        return strength > 75 ? "󰤨" : strength > 50 ? "󰤥" : strength > 25 ? "󰤢" : "󰤟"
    }
    property real enter: 0
    NumberAnimation on enter { from: 0; to: 1; duration: 620; easing.type: Easing.OutCubic }
    Rectangle {
        id: body
        width: parent.width / Theme.uiScale
        height: parent.height / Theme.uiScale
        scale: Theme.uiScale
        transformOrigin: Item.TopLeft
        radius: 9
        color: Theme.bg
        border.color: Theme.line
        opacity: bar.enter
        transform: Translate { y: -12 * (1 - bar.enter) }
        RowLayout {
            anchors { left: parent.left; leftMargin: 5; verticalCenter: parent.verticalCenter }
            spacing: 3
            Chip { id: launcherChip; compact: true; iconSize: 13; label: "󰣇"; shortcut: "Super + D"; ink: Theme.green; selected: bar.shell.panel === "launcher"; onClicked: bar.shell.openAt("launcher", bar) }
            Rectangle { width: 1; height: 12; color: Theme.line; Layout.leftMargin: 4; Layout.rightMargin: 6 }
            Workspaces {}
            SwapText {
                text: Hyprland.activeToplevel && Hyprland.activeToplevel.title ? Hyprland.activeToplevel.title : "still / material"
                key: Hyprland.activeToplevel ? String(Hyprland.activeToplevel.address) : "none"
                color: Theme.muted
                pixelSize: 10
                maxWidth: Math.max(70, bar.width / Theme.uiScale * 0.16)
                Layout.preferredWidth: implicitWidth
                Layout.preferredHeight: 16
                Layout.leftMargin: 12
            }
        }
        Chip {
            id: clockChip
            compact: true
            iconSize: 13
            anchors.centerIn: parent
            label: bar.shell.clock.date.toLocaleString(Qt.locale("en_US"), "ddd, d MMM  ·  HH:mm")
            ink: Theme.text
            selected: bar.shell.panel === "calendar"
            onClicked: bar.shell.openModule("calendar", bar.anchorX(clockChip), bar)
        }
        RowLayout {
            anchors { right: parent.right; rightMargin: 5; verticalCenter: parent.verticalCenter }
            spacing: 2
            Repeater {
                model: SystemTray.items
                Rectangle {
                    id: trayItem
                    required property var modelData
                    implicitWidth: 23
                    implicitHeight: 22
                    radius: 6
                    color: trayMouse.containsMouse ? Theme.elevated : "transparent"
                    scale: trayMouse.pressed ? 0.9 : 1
                    Behavior on color { ColorAnimation { duration: Theme.fast } }
                    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
                    opacity: 0
                    Component.onCompleted: opacity = 1
                    Behavior on opacity { NumberAnimation { duration: Theme.normal } }
                    Image {
                        id: trayIcon
                        anchors.centerIn: parent
                        width: 17
                        height: 17
                        sourceSize.width: 34
                        sourceSize.height: 34
                        source: trayItem.modelData.icon
                        visible: source.toString() !== "" && status !== Image.Error
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: !trayIcon.visible
                        text: "󰀻"
                        color: Theme.muted
                        font.family: Theme.icons
                        font.pixelSize: 16
                    }
                    MouseArea {
                        id: trayMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: event => {
                            const item = trayItem.modelData
                            if (event.button === Qt.RightButton || item.onlyMenu) bar.shell.openTray(item, event.button !== Qt.RightButton, bar.anchorX(trayItem), bar)
                            else item.activate()
                        }
                        onWheel: event => trayItem.modelData.scroll(event.angleDelta.y, false)
                    }
                }
            }
            Text {
                textFormat: Text.RichText
                text: '<span style="font-size: 12px">󰻠</span> ' + (bar.shell.resources.cpu === null ? "…" : bar.shell.resources.cpu + "%")
                color: bar.shell.resources.cpu >= 85 ? Theme.yellow : Theme.text
                Behavior on color { ColorAnimation { duration: Theme.slow } }
                font.family: Theme.icons
                font.pixelSize: 10
                Layout.preferredWidth: 53
                Layout.leftMargin: 6
            }
            Text {
                textFormat: Text.RichText
                text: '<span style="font-size: 12px">󰍛</span> ' + (bar.shell.resources.ramTotal > 0 ? bar.shell.resources.ramUsed.toFixed(1) + " GiB" : "…")
                color: Theme.text
                font.family: Theme.icons
                font.pixelSize: 10
                Layout.preferredWidth: 78
            }
            Rectangle {
                implicitWidth: 49
                implicitHeight: 22
                radius: 6
                color: keyboardHover.containsMouse ? Theme.elevated : "transparent"
                scale: keyboardHover.pressed ? 0.94 : 1
                Behavior on color { ColorAnimation { duration: 140 } }
                Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
                Row {
                    anchors.centerIn: parent
                    spacing: 5
                    Image {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16
                        height: 12
                        source: "file://" + Paths.riceScript("icons/keyboard-bar.svg")
                    }
                    SwapText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16
                        height: 14
                        text: bar.shell.keyboardLayout.label
                        family: Theme.icons
                        pixelSize: 10
                    }
                }
                MouseArea {
                    id: keyboardHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached(["python", Paths.riceScript("keyboard.py"), "next"])
                }
            }
            Chip { id: networkChip; compact: true; iconSize: 13; label: bar.networkIcon(); ink: bar.shell.networkConnected ? Theme.green : Theme.muted; selected: bar.shell.panel === "wifi"; onClicked: bar.shell.openModule("wifi", bar.anchorX(networkChip), bar) }
            Chip { id: bluetoothChip; compact: true; iconSize: 13; label: bar.shell.bluetooth.devices.some(device => device.connected) ? "󰂱" : bar.shell.bluetooth.powered ? "󰂯" : "󰂲"; ink: bar.shell.bluetooth.powered ? Theme.green : Theme.muted; selected: bar.shell.panel === "bluetooth"; onClicked: bar.shell.openModule("bluetooth", bar.anchorX(bluetoothChip), bar) }
            Chip { id: audioChip; compact: true; iconSize: 13; label: bar.shell.muted ? "󰖁" : bar.shell.volume > 66 ? "󰕾" : bar.shell.volume > 33 ? "󰖀" : "󰕿"; ink: bar.shell.muted ? Theme.muted : Theme.text; shortcut: "XF86AudioRaiseVolume / XF86AudioLowerVolume / XF86AudioMute"; selected: bar.shell.panel === "audio"; onClicked: bar.shell.openModule("audio", bar.anchorX(audioChip), bar); onRightClicked: bar.shell.toggleMute(); onScrolled: delta => bar.shell.changeVolume(delta > 0 ? 0.05 : -0.05) }
            Chip {
                id: batteryChip
                compact: true
                iconSize: 13
                visible: bar.shell.batteryPresent
                label: bar.batteryIcon(bar.shell.batteryLevel, bar.shell.batteryPlugged) + " " + bar.shell.batteryLevel + "%"
                ink: bar.shell.batteryPlugged ? Theme.green : bar.shell.batteryLevel < 20 ? Theme.red : Theme.text
                selected: bar.shell.panel === "battery"
                onClicked: bar.shell.openModule("battery", bar.anchorX(batteryChip), bar)
                property real pulse: 1
                transform: Scale { origin.x: batteryChip.width / 2; origin.y: batteryChip.height / 2; xScale: batteryChip.pulse; yScale: batteryChip.pulse }
                Connections { target: bar.shell; function onBatteryPluggedChanged() { plugPulse.restart() } }
                SequentialAnimation {
                    id: plugPulse
                    NumberAnimation { target: batteryChip; property: "pulse"; to: 1.18; duration: 120; easing.type: Easing.OutQuad }
                    SpringAnimation { target: batteryChip; property: "pulse"; to: 1; spring: 4; damping: 0.22 }
                }
            }
            Rectangle { width: 1; height: 12; color: Theme.line; Layout.leftMargin: 5; Layout.rightMargin: 5 }
            Chip { compact: true; iconSize: 13; visible: bar.shell.hotkeysPaused; label: "󰌐"; ink: Theme.yellow; shortcut: "hotkeys paused · Super + Escape" }
            Chip {
                id: bellChip
                compact: true
                iconSize: 13
                label: bar.shell.dnd ? "󰂛" : bar.shell.unreadNotifications > 0 ? "󱅫" : "󰂚"
                shortcut: "Super + N"
                ink: bar.shell.dnd ? Theme.muted : Theme.yellow
                selected: bar.shell.panel === "notifications"
                onClicked: bar.shell.openModule("notifications", bar.anchorX(bellChip), bar)
                onRightClicked: bar.shell.dnd = !bar.shell.dnd
                property real ring: 0
                transform: Rotation { origin.x: bellChip.width / 2; origin.y: 3; angle: bellChip.ring }
                Connections { target: bar.shell; function onNotificationArrived() { if (!bar.shell.dnd) ringAnimation.restart() } }
                SequentialAnimation {
                    id: ringAnimation
                    NumberAnimation { target: bellChip; property: "ring"; to: 16; duration: 70 }
                    NumberAnimation { target: bellChip; property: "ring"; to: -12; duration: 110 }
                    NumberAnimation { target: bellChip; property: "ring"; to: 7; duration: 100 }
                    NumberAnimation { target: bellChip; property: "ring"; to: -3; duration: 90 }
                    NumberAnimation { target: bellChip; property: "ring"; to: 0; duration: 80 }
                }
            }
            Chip { compact: true; iconSize: 13; label: "󰒓"; shortcut: "Super + Space"; ink: Theme.green; selected: bar.shell.panel === "control"; onClicked: bar.shell.openAt("control", bar) }
        }
    }
}
