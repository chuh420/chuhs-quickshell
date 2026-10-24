import QtQuick
import QtQuick.Layouts
import Quickshell
ColumnLayout {
    id: view
    required property var shell
    property bool showHidden: false
    property bool intro: true
    Timer { running: true; interval: 420; onTriggered: view.intro = false }
    function restoreSelection(id, index) {
        Qt.callLater(() => {
            const found = apps.model.findIndex(app => app.id === id)
            apps.currentIndex = found >= 0 ? found : Math.min(index, apps.count - 1)
        })
    }
    function toggleHidden() {
        if (!apps.currentItem) return
        const id = apps.currentItem.modelData.id
        const index = apps.currentIndex
        shell.toggleApplicationHidden(id)
        restoreSelection(id, index)
    }
    function toggleShowHidden() {
        const id = apps.currentItem ? apps.currentItem.modelData.id : ""
        const index = Math.max(0, apps.currentIndex)
        showHidden = !showHidden
        restoreSelection(id, index)
    }
    function move(step) { if (apps.count) apps.currentIndex = Math.max(0, Math.min(apps.count - 1, apps.currentIndex + step)) }
    spacing: 14
    Text { text: "workspace / launch"; color: Theme.green; font.family: Theme.font; font.pixelSize: 9; font.letterSpacing: 1 }
    RowLayout {
        Layout.fillWidth: true
        Text { text: "applications"; color: Theme.text; font.family: Theme.font; font.pixelSize: 26; Layout.fillWidth: true }
        Chip { label: "×"; onClicked: view.shell.panel = "" }
    }
    Rectangle {
        Layout.fillWidth: true
        height: 52
        radius: 12
        color: Theme.surface
        border.color: search.activeFocus ? Theme.green : Theme.line
        Behavior on border.color { ColorAnimation { duration: Theme.normal } }
        Text {
            id: searchIcon
            anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
            text: "󰍉"
            color: search.text ? Theme.green : Theme.muted
            Behavior on color { ColorAnimation { duration: Theme.normal } }
            font.family: Theme.icons
            font.pixelSize: 18
        }
        TextInput {
            id: search
            anchors { left: searchIcon.right; right: parent.right; top: parent.top; bottom: parent.bottom; leftMargin: 12; rightMargin: 16 }
            verticalAlignment: TextInput.AlignVCenter
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 16
            focus: true
            clip: true
            selectByMouse: true
            selectionColor: Theme.line
            Component.onCompleted: forceActiveFocus()
            Text { anchors.verticalCenter: parent.verticalCenter; visible: !search.text; text: "find an application…"; color: Theme.muted; font: search.font }
            Keys.onPressed: event => {
                if (event.key === Qt.Key_H && (event.modifiers === Qt.ControlModifier || event.modifiers === (Qt.ControlModifier | Qt.ShiftModifier))) {
                    if (!event.isAutoRepeat) {
                        if (event.modifiers & Qt.ShiftModifier) view.toggleShowHidden()
                        else view.toggleHidden()
                    }
                    event.accepted = true
                } else if (event.key === Qt.Key_PageDown) { view.move(6); event.accepted = true }
                else if (event.key === Qt.Key_PageUp) { view.move(-6); event.accepted = true }
                else if (event.key === Qt.Key_Tab) { view.move(1); event.accepted = true }
                else if (event.key === Qt.Key_Backtab) { view.move(-1); event.accepted = true }
            }
            Keys.onEscapePressed: view.shell.panel = ""
            Keys.onDownPressed: view.move(1)
            Keys.onUpPressed: view.move(-1)
            Keys.onReturnPressed: if (apps.currentItem) { apps.currentItem.launch(); view.shell.panel = "" }
            onTextChanged: { apps.currentIndex = 0; view.shell.searchApplications(text) }
        }
    }
    ListView {
        id: apps
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: 5
        model: view.shell.applications.filter(a => view.showHidden || !view.shell.hiddenApplications.includes(a.id))
        currentIndex: 0
        onModelChanged: Qt.callLater(() => { if (count > 0 && currentIndex < 0) currentIndex = 0 })
        highlightFollowsCurrentItem: true
        highlightMoveDuration: 170
        highlightMoveVelocity: -1
        highlightResizeDuration: 0
        highlight: Rectangle {
            radius: 11
            color: Theme.elevated
            opacity: apps.count > 0 ? 1 : 0
            Rectangle { anchors { left: parent.left; verticalCenter: parent.verticalCenter } width: 3; height: 20; radius: 2; color: Theme.green }
        }
        delegate: Item {
            id: entry
            required property var modelData
            required property int index
            readonly property bool hidden: view.shell.hiddenApplications.includes(modelData.id)
            readonly property bool current: ListView.isCurrentItem
            function launch() { view.shell.launchApplication(modelData.id) }
            width: apps.width
            height: 56
            property real lift: 0
            transform: Translate { y: entry.lift }
            Component.onCompleted: if (view.intro && index < 10) { opacity = 0; lift = 14; introAnimation.start() }
            SequentialAnimation {
                id: introAnimation
                PauseAnimation { duration: entry.index * 24 }
                ParallelAnimation {
                    NumberAnimation { target: entry; property: "opacity"; to: 1; duration: Theme.normal; easing.type: Easing.OutCubic }
                    NumberAnimation { target: entry; property: "lift"; to: 0; duration: Theme.slow; easing.type: Easing.OutCubic }
                }
            }
            Rectangle {
                anchors.fill: parent
                radius: 11
                color: Theme.surface
                opacity: hover.containsMouse && !entry.current ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.fast } }
            }
            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                anchors.leftMargin: entry.current ? 16 : 10
                Behavior on anchors.leftMargin { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
                spacing: 13
                opacity: entry.hidden ? 0.55 : 1
                Rectangle {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    radius: 7
                    color: Theme.elevated
                    property bool hasIcon: entry.modelData.icon.startsWith("/") || Quickshell.hasThemeIcon(entry.modelData.icon)
                    Image {
                        anchors.fill: parent
                        sourceSize.width: 56
                        sourceSize.height: 56
                        asynchronous: true
                        source: parent.hasIcon ? entry.modelData.icon.startsWith("/") ? "file://" + entry.modelData.icon : Quickshell.iconPath(entry.modelData.icon) : ""
                    }
                    Text { anchors.centerIn: parent; visible: !parent.hasIcon; text: entry.modelData.name.charAt(0); color: Theme.green; font.family: Theme.font; font.pixelSize: 16 }
                }
                ColumnLayout {
                    spacing: 2
                    Text { text: entry.modelData.name; color: Theme.text; font.family: Theme.font; font.pixelSize: 14 }
                    Text { text: entry.modelData.generic || entry.modelData.comment || "Application"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 10; elide: Text.ElideRight; Layout.maximumWidth: 390 }
                }
                Item { Layout.fillWidth: true }
                Text { visible: entry.hidden; text: "󰈈"; color: Theme.muted; font.family: Theme.icons; font.pixelSize: 18 }
                Text {
                    text: "↵"
                    color: Theme.green
                    opacity: entry.current ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.fast } }
                }
            }
            MouseArea { id: hover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { entry.launch(); view.shell.panel = "" } }
        }
        Text {
            anchors.centerIn: parent
            opacity: apps.count === 0 ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.normal } }
            text: "No results found"
            color: Theme.muted
            font.family: Theme.font
        }
    }
    Text {
        text: "↑ ↓  select       ↵  launch       󰈉  ctrl+h  " + (apps.currentItem && apps.currentItem.hidden ? "unhide" : "hide") + "       󰈈  ctrl+shift+h  " + (view.showHidden ? "hide hidden" : "show hidden") + "       esc  close"
        color: Theme.muted
        font.family: Theme.font
        font.pixelSize: 10
    }
}
