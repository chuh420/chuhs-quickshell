import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
ColumnLayout {
    id: view
    required property var shell
    spacing: 12
    property string section: "available"
    RowLayout {
        PanelLabel { text: "Wi-Fi"; font.pixelSize: 18; Layout.fillWidth: true }
        Chip { label: shell.wifi.powered ? "on" : "off"; ink: shell.wifi.powered ? Theme.green : Theme.muted; onClicked: shell.wifiCommand({action: "power", enabled: !shell.wifi.powered}) }
    }
    PanelLabel { text: shell.wifi.state === "connected" ? shell.wifi.network : shell.wifi.busy ? "Connecting…" : shell.wifi.powered ? "select a network" : "wi-fi is turned off"; color: Theme.muted; Layout.fillWidth: true }
    RowLayout {
        Chip { label: "available"; selected: view.section === "available"; onClicked: view.section = "available" }
        Chip { label: "saved"; selected: view.section === "saved"; onClicked: view.section = "saved" }
        Item { Layout.fillWidth: true }
        Chip { label: shell.wifi.scanning ? "scanning…" : "󰑐"; ink: Theme.green; onClicked: if (shell.wifi.powered) shell.wifiCommand({action: "scan"}) }
    }
    ListView {
        id: networks
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: 6
        model: shell.wifi.networks.filter(n => view.section === "saved" ? n.saved : n.available)
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
                    PanelLabel { text: modelData.connected ? "connected · click to disconnect" : !modelData.available ? "out of range" : modelData.security === "open" ? "open network" : (modelData.saved ? "saved · " : "") + modelData.security.toUpperCase(); color: Theme.muted; font.pixelSize: 10; Layout.fillWidth: true }
                }
                Chip { visible: view.section === "saved"; label: "󰆴"; ink: Theme.red; onClicked: shell.wifiCommand({action: "forget", path: modelData.known}) }
            }
            MouseArea {
                id: netMouse
                anchors.fill: parent
                anchors.rightMargin: view.section === "saved" ? 44 : 0
                hoverEnabled: true
                enabled: !shell.wifi.busy && modelData.available
                cursorShape: Qt.PointingHandCursor
                onClicked: shell.wifiCommand(modelData.connected ? {action: "disconnect"} : {action: "connect", path: modelData.path})
            }
        }
        PanelLabel { anchors.centerIn: parent; visible: networks.count === 0; text: shell.wifi.powered ? "no networks · try scanning" : "wireless disabled"; color: Theme.muted }
    }
    ColumnLayout {
        visible: shell.wifiPrompt !== ""
        Layout.fillWidth: true
        PanelLabel { text: "password for " + shell.wifiPrompt; Layout.fillWidth: true }
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
            Chip { label: "cancel"; onClicked: { password.text = ""; shell.wifiCommand({action: "cancel"}) } }
            Chip { label: "connect"; ink: Theme.green; onClicked: password.submit() }
        }
    }
    PanelLabel { visible: shell.wifi.message !== ""; text: shell.wifi.message; color: Theme.red; wrapMode: Text.WordWrap; elide: Text.ElideNone; Layout.fillWidth: true; font.pixelSize: 11 }
    PanelLabel { text: "󰒓  control center"; color: Theme.muted; MouseArea { anchors.fill: parent; onClicked: shell.toggle("control") } }
}
