import QtQuick
import QtQuick.Layouts
import Quickshell
ColumnLayout {
    id: view
    required property var shell
    required property date date
    spacing: 0
    PanelLabel { text: "desktop / control"; color: Theme.green; font.family: Theme.icons; font.pixelSize: 9; font.letterSpacing: 1 }
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 8
        PanelLabel { text: Qt.formatDateTime(view.date, "HH:mm"); font.pixelSize: 40; font.weight: Font.Light; Layout.fillWidth: true }
        Chip { label: "󰌾"; fontSize: 22; ink: Theme.yellow; shortcut: "Super + Ctrl + L"; onClicked: shell.run("lock") }
    }
    PanelLabel { text: view.date.toLocaleString(Qt.locale("en_US"), "dddd, d MMMM"); color: Theme.muted; Layout.topMargin: 4 }
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 17
        spacing: 10
        Repeater {
            model: ["wifi", "bluetooth"]
            Rectangle {
                required property string modelData
                readonly property bool wifi: modelData === "wifi"
                readonly property bool active: wifi ? shell.networkConnected : shell.bluetooth.powered
                Layout.fillWidth: true
                Layout.preferredHeight: 95
                radius: 16
                color: tileMouse.containsMouse ? Theme.elevated : Theme.surface
                border.color: active ? (wifi ? Theme.green : Theme.yellow) : Theme.line
                border.width: 0.7
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 15
                    spacing: 4
                    RowLayout {
                        Layout.fillWidth: true
                        PanelLabel { text: wifi ? "󰤨" : "󰂯"; font.family: Theme.icons; font.pixelSize: 22; color: wifi ? Theme.green : Theme.yellow; Layout.fillWidth: true }
                        PanelLabel { text: wifi ? "↗" : active ? "on" : "off"; color: Theme.muted }
                    }
                    Item { Layout.fillHeight: true }
                    PanelLabel { text: wifi ? shell.networkName : "bluetooth"; font.pixelSize: 14; Layout.fillWidth: true }
                    PanelLabel { text: wifi ? active ? "connected" : "disconnected" : shell.bluetooth.name || "no adapter found"; color: Theme.muted; font.pixelSize: 10; Layout.fillWidth: true }
                }
                MouseArea {
                    id: tileMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: event => {
                        if (!wifi && event.button === Qt.RightButton) shell.wifiCommand({action: "bt-power", enabled: !shell.bluetooth.powered})
                        else shell.toggle(modelData)
                    }
                }
            }
        }
    }
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 89
        Layout.topMargin: 18
        color: Theme.surface
        radius: 16
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            RowLayout {
                Layout.fillWidth: true
                PanelLabel { text: "󰕾"; font.family: Theme.icons; font.pixelSize: 18; color: Theme.green }
                PanelLabel { text: "volume"; Layout.fillWidth: true }
                Chip { label: shell.muted ? "mute" : shell.volume + "%"; ink: Theme.green; shortcut: "XF86AudioMute"; onClicked: shell.run("volume-mute"); onRightClicked: shell.toggle("audio") }
            }
            MaterialSlider { Layout.fillWidth: true; value: shell.volume; shortcut: "XF86AudioRaiseVolume / XF86AudioLowerVolume"; onMoved: if (shell.sink && shell.sink.audio) shell.sink.audio.volume = value / 100 }
        }
    }
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 89
        Layout.topMargin: 10
        color: Theme.surface
        radius: 16
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            RowLayout {
                Layout.fillWidth: true
                PanelLabel { text: "󰃟"; font.family: Theme.icons; font.pixelSize: 18; color: Theme.yellow }
                PanelLabel { text: "brightness"; Layout.fillWidth: true }
                PanelLabel { text: shell.stats.brightness + "%"; color: Theme.yellow; font.family: Theme.icons }
            }
            MaterialSlider { Layout.fillWidth: true; from: 5; value: shell.stats.brightness; accent: Theme.yellow; shortcut: "XF86MonBrightnessUp / XF86MonBrightnessDown"; onMoved: shell.setBrightness(value) }
        }
    }
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 44
        Layout.topMargin: 15
        radius: 13
        color: shell.keepAwake ? Theme.elevated : Theme.surface
        RowLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 10
            PanelLabel { text: "󰅶"; font.family: Theme.icons; font.pixelSize: 18; color: shell.keepAwake ? Theme.green : Theme.muted }
            PanelLabel { text: "keep awake"; Layout.fillWidth: true }
            Chip { label: shell.keepAwake ? "on" : "off"; ink: shell.keepAwake ? Theme.green : Theme.muted; selected: shell.keepAwake; shortcut: "prevent automatic locking and screen sleep"; onClicked: shell.keepAwake = !shell.keepAwake }
        }
    }
    Item { Layout.fillHeight: true }
    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.line; Layout.bottomMargin: 12 }
    RowLayout {
        Layout.fillWidth: true
        spacing: 7
        Chip { label: "󰂚"; fontSize: 18; shortcut: "Super + N"; onClicked: shell.run("notifications") }
        Chip { label: "󰅍"; fontSize: 18; shortcut: "Super + C"; onClicked: shell.run("clipboard") }
        Chip { label: "󰄀"; fontSize: 18; shortcut: "Print"; onClicked: shell.run("screenshot") }
        Chip { label: "󰸉"; fontSize: 18; shortcut: "Super + B"; ink: Theme.green; onClicked: shell.toggle("wallpapers") }
        Item { Layout.fillWidth: true }
        Chip { label: "󰒲"; fontSize: 18; onClicked: { shell.panel = ""; shell.run("suspend") } }
        Chip { label: "󰐥"; fontSize: 18; ink: Theme.red; onClicked: shell.run("power") }
    }
}
