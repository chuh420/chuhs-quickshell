import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
ColumnLayout {
    id: view
    required property var shell
    readonly property var device: shell.batteryDevice
    readonly property int level: shell.batteryLevel
    spacing: 14
    function duration(seconds) {
        if (!seconds || seconds <= 0) return ""
        const minutes = Math.round(seconds / 60)
        return Math.floor(minutes / 60) + "h " + String(minutes % 60).padStart(2, "0") + "m"
    }
    function state() {
        if (!device) return "no battery"
        switch (device.state) {
        case UPowerDeviceState.Charging: return "charging"
        case UPowerDeviceState.Discharging: return "on battery"
        case UPowerDeviceState.FullyCharged: return "fully charged"
        case UPowerDeviceState.PendingCharge: return "not charging"
        case UPowerDeviceState.Empty: return "empty"
        default: return shell.batteryPlugged ? "plugged in" : "on battery"
        }
    }
    function remaining() {
        if (!device) return "—"
        if (device.state === UPowerDeviceState.FullyCharged) return "Fully charged"
        if (device.state === UPowerDeviceState.Charging) return duration(device.timeToFull) ? duration(device.timeToFull) + " until full" : "Calculating…"
        if (device.state === UPowerDeviceState.Discharging) return duration(device.timeToEmpty) ? duration(device.timeToEmpty) + " left" : "Calculating…"
        return "—"
    }
    RowLayout {
        PanelLabel { text: "battery"; font.pixelSize: 18; Layout.fillWidth: true }
        PanelLabel { text: view.state(); color: Theme.green }
    }
    PanelLabel { text: view.level + "%"; font.pixelSize: 42; font.weight: Font.Light }
    Rectangle {
        Layout.fillWidth: true
        height: 8
        radius: 4
        color: Theme.elevated
        Rectangle {
            id: fill
            width: 0
            height: 8
            radius: 4
            color: view.level < 20 ? Theme.red : Theme.green
            Component.onCompleted: width = Qt.binding(() => parent.width * view.level / 100)
            Behavior on width { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
            Rectangle {
                visible: view.device && view.device.state === UPowerDeviceState.Charging
                anchors.verticalCenter: parent.verticalCenter
                width: 28
                height: parent.height
                radius: 4
                color: Theme.text
                opacity: 0.25
                NumberAnimation on x { running: parent.visible; loops: Animation.Infinite; from: -28; to: fill.width; duration: 1600; easing.type: Easing.InOutSine }
            }
        }
    }
    Repeater {
        model: [["remaining", view.remaining()], ["power draw", view.device && view.device.changeRate ? Math.abs(view.device.changeRate).toFixed(1) + " W" : "—"], ["battery health", view.device && view.device.healthSupported ? Math.round(view.device.healthPercentage) + "%" : "—"]]
        RowLayout {
            required property var modelData
            Layout.fillWidth: true
            PanelLabel { text: modelData[0]; color: Theme.muted; Layout.fillWidth: true }
            PanelLabel { text: modelData[1] }
        }
    }
    PanelLabel { text: "Brightness · " + view.shell.brightness + "%"; color: Theme.muted }
    MaterialSlider { Layout.fillWidth: true; from: 5; value: view.shell.brightness; accent: Theme.yellow; shortcut: "XF86MonBrightnessUp / XF86MonBrightnessDown"; onMoved: view.shell.setBrightness(value) }
    Item { Layout.fillHeight: true }
    Chip { label: "󰒓  control center"; onClicked: view.shell.toggle("control") }
}
