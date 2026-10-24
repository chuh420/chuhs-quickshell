import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
ColumnLayout {
    id: view
    required property var shell
    spacing: 12
    RowLayout {
        Layout.fillWidth: true
        PanelLabel { text: "notifications"; font.pixelSize: 18; Layout.fillWidth: true }
        Chip { label: view.shell.dnd ? "󰂛  silent" : "󰂚  alerts"; ink: view.shell.dnd ? Theme.muted : Theme.yellow; selected: view.shell.dnd; shortcut: "do not disturb · right click the bell"; onClicked: view.shell.dnd = !view.shell.dnd }
        Chip { label: "clear all"; visible: list.count > 0; ink: Theme.red; onClicked: view.shell.clearNotifications() }
    }
    PanelLabel { text: list.count === 0 ? "nothing new" : list.count + (list.count === 1 ? " notification" : " notifications"); color: Theme.muted }
    ListView {
        id: list
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: 8
        model: view.shell.historyNotifications.slice().reverse()
        ScrollBar.vertical: ScrollBar {}
        delegate: NotificationCard {
            required property var modelData
            required property int index
            width: list.width
            shell: view.shell
            notification: modelData
            opacity: 0
            Component.onCompleted: opacity = 1
            Behavior on opacity { NumberAnimation { duration: Theme.normal } }
        }
        Column {
            anchors.centerIn: parent
            spacing: 10
            opacity: list.count === 0 ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.slow } }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: view.shell.dnd ? "󰂛" : "󰂚"; color: Theme.line; font.family: Theme.icons; font.pixelSize: 46 }
            PanelLabel { anchors.horizontalCenter: parent.horizontalCenter; text: "all caught up"; color: Theme.muted }
        }
    }
    PanelLabel { text: "click to open  ·  swipe or right click to dismiss"; color: Theme.muted; font.pixelSize: 10 }
}
