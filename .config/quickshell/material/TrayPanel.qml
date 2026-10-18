import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
ColumnLayout {
    id: view
    required property var shell
    onShowMenuChanged: shell.trayExpanded = showMenu
    property bool showMenu: shell.trayOnlyMenu
    property var stack: []
    readonly property bool rootMenu: !showMenu
    function clearStack() { const previous = stack; stack = []; for (let i = previous.length - 1; i >= 0; i--) previous[i].destroy() }
    function back() { if (stack.length) { const last = stack[stack.length - 1]; stack = stack.slice(0, -1); last.destroy() } else showMenu = false }
    function activate(item) {
        if (!shell.trayTarget || !item || item.isSeparator || (!rootMenu && !item.enabled)) return
        if (rootMenu) {
            if (item.action === 0) { shell.trayTarget.activate(); shell.panel = "" }
            else if (item.action === 1) showMenu = true
            else { Quickshell.execDetached(["python", "/home/chuh/.config/quickshell/material/helpers/tray.py", "quit", shell.trayTarget.id, shell.trayTarget.title || shell.trayTarget.id]); shell.panel = "" }
        } else if (item.hasChildren) stack = stack.concat([menuLevel.createObject(view, {menu: item})])
        else { item.triggered(); shell.panel = "" }
    }
    readonly property var rows: rootMenu ? [{text: "open application", action: 0}, {text: "application menu", action: 1}, {text: "quit application", action: 2}] : stack.length ? stack[stack.length - 1].children.values : opener.children.values
    QsMenuOpener { id: opener; menu: view.showMenu && shell.trayTarget ? shell.trayTarget.menu : null }
    Component { id: menuLevel; QsMenuOpener {} }
    Connections { target: shell; function onPanelChanged() { if (shell.panel === "tray") { view.clearStack(); view.showMenu = shell.trayOnlyMenu } } }
    spacing: 8
    RowLayout {
        Layout.fillWidth: true
        Chip { visible: view.showMenu && (!shell.trayOnlyMenu || view.stack.length > 0); label: "←"; onClicked: { view.back() } }
        PanelLabel { text: shell.trayTarget ? shell.trayTarget.title || shell.trayTarget.id : "application"; font.pixelSize: 14; Layout.fillWidth: true }
    }
    ListView {
        id: entries
        Layout.fillWidth: true
        Layout.fillHeight: true
        focus: true
        Component.onCompleted: forceActiveFocus()
        currentIndex: 0
        onModelChanged: currentIndex = 0
        Keys.onReturnPressed: view.activate(view.rows[currentIndex])
        Keys.onRightPressed: { const item = view.rows[currentIndex]; if (item && item.hasChildren) view.activate(item) }
        Keys.onLeftPressed: view.back()
        Keys.onEscapePressed: shell.panel = ""
        spacing: 4
        clip: true
        model: view.rows
        ScrollBar.vertical: ScrollBar {}
        delegate: Rectangle {
            required property int index
            required property var modelData
            width: entries.width
            height: modelData.isSeparator ? 9 : 30
            radius: 7
            color: (ListView.isCurrentItem || menuMouse.containsMouse) && menuMouse.enabled ? Theme.elevated : "transparent"
            Rectangle { visible: Boolean(modelData.isSeparator); anchors.centerIn: parent; width: parent.width - 12; height: 1; color: Theme.line }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                visible: !modelData.isSeparator
                opacity: !view.rootMenu && !modelData.enabled ? 0.45 : 1
                PanelLabel { text: modelData.text.replace(/&(.)/g, "$1"); color: view.rootMenu && modelData.action === 2 ? Theme.red : Theme.text; Layout.fillWidth: true }
                PanelLabel { text: modelData.hasChildren ? "›" : !view.rootMenu && modelData.checkState === Qt.Checked ? "✓" : ""; color: Theme.green }
            }
            MouseArea {
                id: menuMouse
                anchors.fill: parent
                hoverEnabled: true
                enabled: !modelData.isSeparator && (view.rootMenu || modelData.enabled)
                cursorShape: Qt.PointingHandCursor
                onClicked: { entries.currentIndex = index; view.activate(modelData) }

            }
        }
        PanelLabel { anchors.centerIn: parent; visible: entries.count === 0; text: "no menu entries"; color: Theme.muted }
    }
}
