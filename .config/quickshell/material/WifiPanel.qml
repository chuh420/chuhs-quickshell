import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
ColumnLayout {
    id: view
    required property var shell
    spacing: 12
    property string section: "Available"
    RowLayout {
        PanelLabel { text: "Wi-Fi"; font.pixelSize: 18; Layout.fillWidth: true }
        Chip { label: shell.wifi.powered ? "ON" : "OFF"; ink: shell.wifi.powered ? Theme.green : Theme.muted; onClicked: shell.wifiCommand({action: "power", enabled: !shell.wifi.powered}) }
    }
    PanelLabel { text: shell.wifi.state === "connected" ? shell.stats.network : shell.wifi.busy ? "Connecting…" : shell.wifi.powered ? "Select a network" : "Wi-Fi is turned off"; color: Theme.muted; Layout.fillWidth: true }
    RowLayout {
        Chip { label: "Available"; selected: view.section === "Available"; onClicked: view.section = "Available" }
        Chip { label: "Saved"; selected: view.section === "Saved"; onClicked: view.section = "Saved" }
        Item { Layout.fillWidth: true }
        Chip { label: shell.wifi.scanning ? "Scanning…" : "󰑐"; ink: Theme.green; onClicked: if (shell.wifi.powered) shell.wifiCommand({action: "scan"}) }
    }
    ListView {
        id: networks
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: 6
        model: shell.wifi.networks.filter(n => view.section === "Saved" ? n.saved : n.available)
        delegate: Rectangle {
            required property var modelData
            width: networks.width
            height: 58
            radius: 10
            color: modelData.connected ? Theme.elevated : netMouse.containsMouse ? Theme.surface : "transparent"
            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 10
                PanelLabel { text: modelData.strength > 65 ? "󰤨" : modelData.strength > 35 ? "󰤥" : "󰤟"; font.family: Theme.icons; font.pixelSize: 18; color: modelData.connected ? Theme.green : Theme.muted }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3
                    PanelLabel { text: modelData.name; Layout.fillWidth: true }
                    PanelLabel { text: modelData.connected ? "Connected · click to disconnect" : !modelData.available ? "Out of range" : modelData.security === "open" ? "Open network" : (modelData.saved ? "Saved · " : "") + modelData.security.toUpperCase(); color: Theme.muted; font.pixelSize: 10; Layout.fillWidth: true }
                }
                Chip { visible: view.section === "Saved"; label: "󰆴"; ink: Theme.red; onClicked: shell.wifiCommand({action: "forget", path: modelData.known}) }
            }
            MouseArea {
                id: netMouse
                anchors.fill: parent
                anchors.rightMargin: view.section === "Saved" ? 44 : 0
                hoverEnabled: true
                enabled: !shell.wifi.busy && modelData.available
                cursorShape: Qt.PointingHandCursor
                onClicked: shell.wifiCommand(modelData.connected ? {action: "disconnect"} : {action: "connect", path: modelData.path})
            }
        }
        PanelLabel { anchors.centerIn: parent; visible: networks.count === 0; text: shell.wifi.powered ? "No networks · try scanning" : "Wireless disabled"; color: Theme.muted }
    }
    ColumnLayout {
        visible: shell.wifiPrompt !== ""
        Layout.fillWidth: true
        PanelLabel { text: "Password for " + shell.wifiPrompt; Layout.fillWidth: true }
        Rectangle {
            Layout.fillWidth: true
            height: 38
            radius: 8
            color: Theme.surface
            border.color: Theme.green
            TextInput {
                id: password
                anchors.fill: parent
                anchors.margins: 10
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 12
                echoMode: TextInput.Password
                selectByMouse: true
                clip: true
                onVisibleChanged: if (visible) forceActiveFocus()
                function submit() { shell.wifiCommand({action: "password", password: text}); text = "" }
                Keys.onReturnPressed: submit()
                Connections { target: shell; function onWifiPromptChanged() { password.text = ""; if (shell.wifiPrompt) password.forceActiveFocus() } }
            }
        }
        RowLayout {
            Item { Layout.fillWidth: true }
            Chip { label: "Cancel"; onClicked: { password.text = ""; shell.wifiCommand({action: "cancel"}) } }
            Chip { label: "Connect"; ink: Theme.green; onClicked: password.submit() }
        }
    }
    PanelLabel { visible: shell.wifi.message !== ""; text: shell.wifi.message; color: Theme.red; wrapMode: Text.WordWrap; elide: Text.ElideNone; Layout.fillWidth: true; font.pixelSize: 11 }
    PanelLabel { text: "󰒓  Control center"; color: Theme.muted; MouseArea { anchors.fill: parent; onClicked: shell.toggle("control") } }
}
