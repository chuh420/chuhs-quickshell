import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
ColumnLayout {
    id: view
    required property var shell
    spacing: 12
    RowLayout {
        PanelLabel { text: "Bluetooth"; font.pixelSize: 18; Layout.fillWidth: true }
        Chip { label: shell.bluetooth.powered ? "on" : "off"; ink: shell.bluetooth.powered ? Theme.green : Theme.muted; onClicked: shell.wifiCommand({action: "bt-power", enabled: !shell.bluetooth.powered}) }
    }
    RowLayout {
        PanelLabel { text: shell.bluetooth.name || "no adapter found"; color: Theme.muted; Layout.fillWidth: true }
        Chip { label: shell.bluetooth.discovering ? "stop scan" : "scan"; ink: Theme.green; onClicked: shell.wifiCommand({action: "bt-scan", enabled: !shell.bluetooth.discovering}) }
    }
    ListView {
        id: devices
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: 6
        model: shell.bluetooth.devices
        delegate: Rectangle {
            required property var modelData
            width: devices.width
            height: 68
            radius: 10
            color: modelData.connected ? Theme.elevated : Theme.surface
            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: 4
                    PanelLabel { text: modelData.name; Layout.fillWidth: true }
                    PanelLabel { text: (modelData.pairing ? "pairing" : modelData.connected ? "connected" : modelData.paired ? "paired" : "available") + (modelData.battery >= 0 ? " · " + modelData.battery + "%" : ""); color: modelData.connected ? Theme.green : Theme.muted; font.pixelSize: 10; Layout.fillWidth: true }
                }
                Chip { label: modelData.pairing ? "cancel" : modelData.connected ? "disconnect" : modelData.paired ? "connect" : "pair"; onClicked: shell.wifiCommand({action: modelData.pairing ? "bt-cancel" : modelData.connected ? "bt-disconnect" : modelData.paired ? "bt-connect" : "bt-pair", path: modelData.path}) }
                Chip { visible: modelData.paired; label: "󰆴"; ink: Theme.red; onClicked: shell.wifiCommand({action: "bt-forget", path: modelData.path}) }
            }
        }
        PanelLabel { anchors.centerIn: parent; visible: devices.count === 0; text: shell.bluetooth.powered ? "scan to discover devices" : "bluetooth is turned off"; color: Theme.muted }
    }
    ColumnLayout {
        visible: shell.bluetoothPrompt.name !== ""
        Layout.fillWidth: true
        PanelLabel { text: "pair with " + shell.bluetoothPrompt.name; Layout.fillWidth: true }
        PanelLabel { text: shell.bluetoothPrompt.mode === "display" ? "enter on device: " + shell.bluetoothPrompt.value : shell.bluetoothPrompt.mode === "confirm" ? "confirm code: " + shell.bluetoothPrompt.value : "allow pairing / enter PIN"; color: Theme.green; Layout.fillWidth: true }
        TextField {
            id: pin
            visible: ["pin", "passkey"].includes(shell.bluetoothPrompt.mode)
            Layout.fillWidth: true
            color: Theme.text
            background: Rectangle { color: Theme.surface; radius: 8; border.color: Theme.line }
            placeholderText: "PIN"
            function submit() { shell.wifiCommand({action: "bluetooth-reply", accepted: true, value: text}); text = "" }
            onAccepted: submit()
            Connections { target: shell; function onBluetoothPromptChanged() { pin.text = ""; if (pin.visible) pin.forceActiveFocus() } }
        }
        RowLayout {
            Chip { label: "cancel"; onClicked: shell.wifiCommand({action: "bluetooth-reply", accepted: false}) }
            Chip { label: "confirm"; ink: Theme.green; onClicked: pin.submit() }
        }
    }
    PanelLabel { text: shell.bluetoothError; visible: text !== ""; color: Theme.red; wrapMode: Text.WordWrap; elide: Text.ElideNone; Layout.fillWidth: true }
    PanelLabel { text: "󰒓  control center"; color: Theme.muted; MouseArea { anchors.fill: parent; onClicked: shell.toggle("control") } }
}
