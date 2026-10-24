import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
ColumnLayout {
    id: view
    required property var shell
    property var entries: []
    property bool loading: true
    property bool intro: true
    readonly property var filtered: search.text ? entries.filter(e => e.kind === "text" && e.text.toLowerCase().includes(search.text.toLowerCase())) : entries
    spacing: 14
    Timer { running: true; interval: 420; onTriggered: view.intro = false }
    function reload() { lister.running = true }
    function copy(entry) { if (!entry) return; Quickshell.execDetached(["python", Paths.helper("clipboard.py"), "copy", entry.id]); view.shell.panel = "" }
    function remove(entry) {
        if (!entry) return
        const index = list.currentIndex
        entries = entries.filter(e => e.id !== entry.id)
        Quickshell.execDetached(["python", Paths.helper("clipboard.py"), "delete", entry.id])
        Qt.callLater(() => list.currentIndex = Math.min(index, list.count - 1))
    }
    function move(step) { if (list.count) list.currentIndex = Math.max(0, Math.min(list.count - 1, list.currentIndex + step)) }
    Process {
        id: lister
        command: ["python", Paths.helper("clipboard.py"), "list"]
        running: true
        stdout: StdioCollector { onStreamFinished: { try { view.entries = JSON.parse(text) } catch(e) { view.entries = [] } view.loading = false } }
    }
    Text { text: "desktop / clipboard"; color: Theme.green; font.family: Theme.font; font.pixelSize: 9; font.letterSpacing: 1 }
    RowLayout {
        Layout.fillWidth: true
        Text { text: "clipboard"; color: Theme.text; font.family: Theme.font; font.pixelSize: 26; Layout.fillWidth: true }
        Chip { label: "clear all"; ink: Theme.red; visible: view.entries.length > 0; onClicked: { Quickshell.execDetached(["python", Paths.helper("clipboard.py"), "wipe"]); view.entries = [] } }
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
            text: "󰅍"
            color: search.text ? Theme.green : Theme.muted
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
            Text { anchors.verticalCenter: parent.verticalCenter; visible: !search.text; text: "search copied text…"; color: Theme.muted; font: search.font }
            Keys.onEscapePressed: view.shell.panel = ""
            Keys.onDownPressed: view.move(1)
            Keys.onUpPressed: view.move(-1)
            Keys.onReturnPressed: view.copy(list.currentItem ? list.currentItem.modelData : null)
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Delete) { view.remove(list.currentItem ? list.currentItem.modelData : null); event.accepted = true }
                else if (event.key === Qt.Key_PageDown) { view.move(6); event.accepted = true }
                else if (event.key === Qt.Key_PageUp) { view.move(-6); event.accepted = true }
                else if (event.key === Qt.Key_Tab) { view.move(1); event.accepted = true }
                else if (event.key === Qt.Key_Backtab) { view.move(-1); event.accepted = true }
            }
            onTextChanged: list.currentIndex = 0
        }
    }
    ListView {
        id: list
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: 5
        model: view.filtered
        currentIndex: 0
        highlightFollowsCurrentItem: true
        highlightMoveDuration: 170
        highlightMoveVelocity: -1
        highlightResizeDuration: 120
        highlight: Rectangle {
            radius: 11
            color: Theme.elevated
            Rectangle { anchors { left: parent.left; verticalCenter: parent.verticalCenter } width: 3; height: 20; radius: 2; color: Theme.green }
        }
        ScrollBar.vertical: ScrollBar {}
        remove: Transition { NumberAnimation { property: "opacity"; to: 0; duration: Theme.fast } }
        displaced: Transition { NumberAnimation { property: "y"; duration: Theme.normal; easing.type: Easing.OutCubic } }
        delegate: Item {
            id: entry
            required property var modelData
            required property int index
            readonly property bool image: modelData.kind === "image"
            readonly property bool current: ListView.isCurrentItem
            property string thumb: ""
            width: list.width
            height: image ? 84 : 48
            property real lift: 0
            transform: Translate { y: entry.lift }
            Component.onCompleted: if (view.intro && index < 10) { opacity = 0; lift = 14; intro.start() }
            SequentialAnimation {
                id: intro
                PauseAnimation { duration: entry.index * 24 }
                ParallelAnimation {
                    NumberAnimation { target: entry; property: "opacity"; to: 1; duration: Theme.normal }
                    NumberAnimation { target: entry; property: "lift"; to: 0; duration: Theme.slow; easing.type: Easing.OutCubic }
                }
            }
            Process {
                running: entry.image
                command: ["python", Paths.helper("clipboard.py"), "thumb", entry.modelData.id, entry.modelData.format || "png"]
                stdout: StdioCollector { onStreamFinished: entry.thumb = text.trim() }
            }
            Rectangle {
                anchors.fill: parent
                radius: 11
                color: Theme.surface
                opacity: rowMouse.containsMouse && !entry.current ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.fast } }
            }
            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                anchors.leftMargin: entry.current ? 16 : 10
                Behavior on anchors.leftMargin { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
                spacing: 12
                Rectangle {
                    visible: entry.image
                    Layout.preferredWidth: 112
                    Layout.preferredHeight: 64
                    radius: 8
                    color: Theme.elevated
                    clip: true
                    Image {
                        anchors.fill: parent
                        source: entry.thumb ? "file://" + entry.thumb : ""
                        sourceSize.width: 224
                        sourceSize.height: 128
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        opacity: status === Image.Ready ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Theme.slow } }
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        Layout.fillWidth: true
                        text: entry.image ? "image" : entry.modelData.text.replace(/\s+/g, " ").trim()
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: 13
                        elide: Text.ElideRight
                    }
                    Text {
                        visible: entry.image
                        text: entry.image ? entry.modelData.format + " · " + entry.modelData.width + "×" + entry.modelData.height + " · " + entry.modelData.size : ""
                        color: Theme.muted
                        font.family: Theme.font
                        font.pixelSize: 10
                    }
                }
                Text {
                    text: "󰆴"
                    color: deleteHover.hovered ? Theme.red : Theme.muted
                    font.family: Theme.icons
                    font.pixelSize: 15
                    opacity: entry.current || rowMouse.containsMouse ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.fast } }
                    HoverHandler { id: deleteHover }
                    TapHandler { onTapped: view.remove(entry.modelData) }
                }
                Text { text: "↵"; color: Theme.green; opacity: entry.current ? 1 : 0; Behavior on opacity { NumberAnimation { duration: Theme.fast } } }
            }
            MouseArea {
                id: rowMouse
                anchors.fill: parent
                anchors.rightMargin: 60
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: view.copy(entry.modelData)
            }
        }
        Text {
            anchors.centerIn: parent
            opacity: list.count === 0 && !view.loading ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.normal } }
            text: search.text ? "No matches" : "Clipboard is empty"
            color: Theme.muted
            font.family: Theme.font
        }
    }
    Text { text: "↑ ↓  select       ↵  copy       del  remove       esc  close"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 10 }
}
