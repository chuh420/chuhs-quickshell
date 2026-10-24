import QtQuick
import QtQuick.Layouts
import Quickshell
FocusScope {
    id: view
    required property var shell
    property int current: 0
    property int pending: -1
    property real countdown: 0
    readonly property var actions: [
        {label: "lock", icon: "󰌾", ink: Theme.yellow, confirm: false},
        {label: "sleep", icon: "󰒲", ink: Theme.green, confirm: false},
        {label: "restart", icon: "󰜉", ink: Theme.yellow, confirm: true},
        {label: "power off", icon: "󰐥", ink: Theme.red, confirm: true}
    ]
    focus: true
    Component.onCompleted: forceActiveFocus()
    function execute(index) {
        if (index === 0) view.shell.run("lock")
        else if (index === 1) { view.shell.panel = ""; Quickshell.execDetached(["systemctl", "suspend"]) }
        else if (index === 2) Quickshell.execDetached(["systemctl", "reboot"])
        else if (index === 3) Quickshell.execDetached(["systemctl", "poweroff"])
    }
    function activate(index) {
        current = index
        if (pending === index) { cancel(); return }
        if (!actions[index].confirm) { cancel(); execute(index); return }
        pending = index
        countdown = 0
        hold.restart()
    }
    function cancel() { hold.stop(); pending = -1; countdown = 0 }
    NumberAnimation {
        id: hold
        target: view
        property: "countdown"
        from: 0
        to: 1
        duration: 1800
        onFinished: { const index = view.pending; view.pending = -1; view.execute(index) }
    }
    Keys.onEscapePressed: event => { if (pending >= 0) cancel(); else shell.panel = ""; event.accepted = true }
    Keys.onLeftPressed: current = (current + 3) % 4
    Keys.onRightPressed: current = (current + 1) % 4
    Keys.onTabPressed: current = (current + 1) % 4
    Keys.onReturnPressed: activate(current)
    Keys.onEnterPressed: activate(current)
    Keys.onSpacePressed: activate(current)
    Keys.onPressed: event => { if (event.key >= Qt.Key_1 && event.key <= Qt.Key_4) { activate(event.key - Qt.Key_1); event.accepted = true } }
    ColumnLayout {
        anchors.fill: parent
        spacing: 14
        RowLayout {
            Layout.fillWidth: true
            ColumnLayout {
                spacing: 4
                Text { text: "session / power"; color: Theme.green; font.family: Theme.font; font.pixelSize: 9; font.letterSpacing: 1 }
                Text { text: view.pending >= 0 ? view.actions[view.pending].label + " in " + Math.ceil(1.8 * (1 - view.countdown)) + "s" : "power"; color: Theme.text; font.family: Theme.font; font.pixelSize: 22 }
            }
            Item { Layout.fillWidth: true }
            Chip { label: "×"; onClicked: view.shell.panel = "" }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10
            Repeater {
                model: view.actions
                Rectangle {
                    id: tile
                    required property var modelData
                    required property int index
                    readonly property bool active: view.current === index
                    readonly property bool armed: view.pending === index
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 16
                    color: active ? Theme.elevated : tileMouse.containsMouse ? Theme.surface : "transparent"
                    border.color: armed ? modelData.ink : active ? Theme.line : "transparent"
                    border.width: armed ? 1.5 : 1
                    scale: tileMouse.pressed ? 0.95 : active ? 1 : 0.97
                    clip: true
                    Behavior on color { ColorAnimation { duration: Theme.fast } }
                    Behavior on border.color { ColorAnimation { duration: Theme.normal } }
                    Behavior on scale { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutBack } }
                    Rectangle {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                        height: tile.armed ? parent.height * view.countdown : 0
                        color: tile.modelData.ink
                        opacity: 0.16
                    }
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 8
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: tile.modelData.icon
                            color: tile.modelData.ink
                            font.family: Theme.icons
                            font.pixelSize: 30
                            scale: tile.active ? 1.1 : 1
                            Behavior on scale { NumberAnimation { duration: Theme.slow; easing.type: Easing.OutBack } }
                        }
                        Text { Layout.alignment: Qt.AlignHCenter; text: tile.armed ? "cancel" : tile.modelData.label; color: Theme.text; font.family: Theme.font; font.pixelSize: 12 }
                        Text { Layout.alignment: Qt.AlignHCenter; text: String(tile.index + 1); color: Theme.muted; font.family: Theme.icons; font.pixelSize: 9 }
                    }
                    MouseArea {
                        id: tileMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: view.current = tile.index
                        onClicked: view.activate(tile.index)
                    }
                }
            }
        }
        Text { text: "← →  select    ↵  confirm    1–4  quick pick    esc  " + (view.pending >= 0 ? "cancel" : "close"); color: Theme.muted; font.family: Theme.font; font.pixelSize: 10 }
    }
}
