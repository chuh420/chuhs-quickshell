import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Bluetooth
ColumnLayout {
    id: view
    required property var shell
    spacing: 12
    RowLayout {
        PanelLabel { text: "Bluetooth"; font.pixelSize: 18; Layout.fillWidth: true }
        Chip { label: shell.adapter && shell.adapter.enabled ? "ON" : "OFF"; ink: shell.adapter && shell.adapter.enabled ? Theme.green : Theme.muted; onClicked: if (shell.adapter) shell.adapter.enabled = !shell.adapter.enabled }
    }
    RowLayout {
        PanelLabel { text: shell.adapter ? shell.adapter.name : "No adapter found"; color: Theme.muted; Layout.fillWidth: true }
        Chip { label: shell.adapter && shell.adapter.discovering ? "Stop scan" : "Scan"; ink: Theme.green; onClicked: if (shell.adapter && shell.adapter.enabled) shell.adapter.discovering = !shell.adapter.discovering }
    }
    ListView {
        id: devices
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: 6
        model: shell.adapter ? shell.adapter.devices : null
        delegate: Rectangle {
            required property var modelData
            property bool pairRequested: false
            Connections {
                target: modelData
                function onPairedChanged() {
                    if (modelData.paired && pairRequested) {
                        pairRequested = false
                        modelData.trusted = true
                        modelData.connect()
                        if (shell.bluetoothPrompt.mode === "display") shell.wifiCommand({action: "bluetooth-reply", accepted: true})
                    }
                }
            }
            width: devices.width
            height: 68
            radius: 10
            color: modelData.connected ? Theme.elevated : Theme.surface
            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    PanelLabel { text: modelData.name || modelData.address; Layout.fillWidth: true }
                    PanelLabel { text: BluetoothDeviceState.toString(modelData.state) + (modelData.batteryAvailable ? " · " + Math.round(modelData.battery * 100) + "%" : ""); color: modelData.connected ? Theme.green : Theme.muted; font.pixelSize: 10 }
                }
                Chip { label: modelData.pairing ? "Cancel" : modelData.connected ? "Disconnect" : modelData.paired ? "Connect" : "Pair"; onClicked: { if (modelData.pairing) modelData.cancelPair(); else if (modelData.connected) modelData.disconnect(); else if (modelData.paired) modelData.connect(); else { pairRequested = true; modelData.pair() } } }
                Chip { visible: modelData.paired; label: "󰆴"; ink: Theme.red; onClicked: modelData.forget() }
            }
        }
        PanelLabel { anchors.centerIn: parent; visible: devices.count === 0; text: shell.adapter && shell.adapter.enabled ? "Scan to discover devices" : "Bluetooth is turned off"; color: Theme.muted }
    }
    ColumnLayout {
        visible: shell.bluetoothPrompt.name !== ""
        Layout.fillWidth: true
        PanelLabel { text: "Pair with " + shell.bluetoothPrompt.name; Layout.fillWidth: true }
        PanelLabel { text: shell.bluetoothPrompt.mode === "display" ? "Enter on device: " + shell.bluetoothPrompt.value : shell.bluetoothPrompt.mode === "confirm" ? "Confirm code: " + shell.bluetoothPrompt.value : "Allow pairing / enter PIN"; color: Theme.green; Layout.fillWidth: true }
        TextField {
            id: pin
            visible: ["pin", "passkey"].includes(shell.bluetoothPrompt.mode)
            Layout.fillWidth: true
            color: Theme.text
            background: Rectangle { color: Theme.surface; radius: 8; border.color: Theme.line }
            placeholderText: "PIN"
        }
        RowLayout {
            Chip { label: "Cancel"; onClicked: shell.wifiCommand({action: "bluetooth-reply", accepted: false}) }
            Chip { label: "Confirm"; ink: Theme.green; onClicked: { shell.wifiCommand({action: "bluetooth-reply", accepted: true, value: pin.text}); pin.text = "" } }
        }
    }
    PanelLabel { text: "󰒓  Control center"; color: Theme.muted; MouseArea { anchors.fill: parent; onClicked: shell.toggle("control") } }
    Component.onDestruction: if (shell.adapter && shell.adapter.discovering) shell.adapter.discovering = false
}
