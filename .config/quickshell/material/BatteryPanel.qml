import QtQuick
import QtQuick.Layouts
import Quickshell
ColumnLayout {
    required property var shell
    spacing: 14
    RowLayout {
        PanelLabel { text: "battery"; font.pixelSize: 18; Layout.fillWidth: true }
        PanelLabel { text: shell.stats.batteryStatus || ""; color: Theme.green }
    }
    PanelLabel { text: shell.stats.battery + "%"; font.pixelSize: 42; font.weight: Font.Light }
    Rectangle {
        Layout.fillWidth: true
        height: 8
        radius: 4
        color: Theme.elevated
        Rectangle { width: parent.width * shell.stats.battery / 100; height: 8; radius: 4; color: shell.stats.battery < 20 ? Theme.red : Theme.green }
    }
    Repeater {
        model: [["remaining", shell.stats.batteryTime || "Calculating…"], ["power draw", shell.stats.batteryPower ? shell.stats.batteryPower + " W" : "—"], ["battery health", shell.stats.batteryHealth ? shell.stats.batteryHealth + "%" : "—"]]
        RowLayout {
            required property var modelData
            Layout.fillWidth: true
            PanelLabel { text: modelData[0]; color: Theme.muted; Layout.fillWidth: true }
            PanelLabel { text: modelData[1] }
        }
    }
    PanelLabel { text: "Brightness · " + shell.stats.brightness + "%"; color: Theme.muted }
    MaterialSlider { Layout.fillWidth: true; from: 5; value: shell.stats.brightness; shortcut: "XF86MonBrightnessUp / XF86MonBrightnessDown"; onMoved: Quickshell.execDetached(["brightnessctl", "set", Math.round(value) + "%"]) }
    Item { Layout.fillHeight: true }
    Chip { label: "󰒓  control center"; onClicked: shell.toggle("control") }
}
