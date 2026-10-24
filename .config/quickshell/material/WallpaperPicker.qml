import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
ColumnLayout {
    id: view
    required property var shell
    spacing: 14
    RowLayout {
        Layout.fillWidth: true
        ColumnLayout {
            spacing: 6
            Text { text: "wallpapers"; font.family: Theme.font; font.pixelSize: 26; color: Theme.text }
            Text { text: view.shell.wallpapers.length + " images · Pictures/Wallpapers"; font.family: Theme.font; font.pixelSize: 11; color: Theme.muted }
        }
        Item { Layout.fillWidth: true }
        Chip { label: "refresh"; onClicked: view.shell.refreshWallpapers() }
        Chip { label: "×"; onClicked: view.shell.panel = "" }
    }
    GridView {
        id: gallery
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        cellWidth: width / 2
        cellHeight: cellWidth * 9 / 16 + 54
        model: view.shell.wallpapers
        focus: true
        highlightMoveDuration: 0
        Component.onCompleted: { forceActiveFocus(); requestPreviews() }
        function requestPreviews() {
            if (view.shell.panel !== "wallpapers") return
            const first = Math.max(0, Math.floor(contentY / cellHeight) * 2)
            view.shell.requestPreviews(view.shell.wallpapers.slice(first, first + 8))
        }
        function apply(item, tile, x, y) {
            const point = tile.mapToItem(null, x, y)
            view.shell.applyWallpaper(item.path, {x: point.x, y: point.y, screen: view.shell.panelScreen ? view.shell.panelScreen.name : ""})
        }
        onContentYChanged: requestPreviews()
        onModelChanged: Qt.callLater(requestPreviews)
        Keys.onEscapePressed: view.shell.panel = ""
        Keys.onReturnPressed: if (currentItem) apply(currentItem.modelData, currentItem, currentItem.width / 2, currentItem.height / 2)
        ScrollBar.vertical: ScrollBar { }
        delegate: Rectangle {
            id: tile
            required property var modelData
            required property int index
            readonly property bool selected: view.shell.currentWallpaper === modelData.path
            readonly property bool current: GridView.isCurrentItem
            readonly property string picture: view.shell.previews[modelData.path + "\n" + modelData.revision] || ""
            width: gallery.cellWidth - 10
            height: gallery.cellHeight - 10
            radius: 14
            color: hover.containsMouse ? Theme.elevated : Theme.surface
            border.width: selected ? 2 : 1
            border.color: selected ? Theme.green : current ? Theme.muted : Theme.line
            scale: hover.pressed ? 0.98 : hover.containsMouse ? 1.012 : 1
            Behavior on scale { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: Theme.fast } }
            Behavior on border.color { ColorAnimation { duration: Theme.normal } }
            opacity: 0
            Component.onCompleted: opacity = 1
            Behavior on opacity { NumberAnimation { duration: Theme.slow } }
            Rectangle {
                id: frame
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 7 }
                height: width * 9 / 16
                radius: 9
                color: Theme.elevated
                clip: true
                Text {
                    anchors.centerIn: parent
                    text: "󰸉"
                    color: Theme.line
                    font.family: Theme.icons
                    font.pixelSize: 28
                    opacity: preview.status === Image.Ready ? 0 : 1
                    Behavior on opacity { NumberAnimation { duration: Theme.normal } }
                }
                Image {
                    id: preview
                    anchors.fill: parent
                    source: tile.picture ? "file://" + tile.picture : ""
                    sourceSize.width: 640
                    sourceSize.height: 360
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    opacity: status === Image.Ready ? 1 : 0
                    scale: status === Image.Ready ? 1 : 1.06
                    Behavior on opacity { NumberAnimation { duration: Theme.slow; easing.type: Easing.OutCubic } }
                    Behavior on scale { NumberAnimation { duration: 520; easing.type: Easing.OutCubic } }
                }
            }
            RowLayout {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 13; rightMargin: 13; bottomMargin: 12 }
                spacing: 8
                Text { text: tile.modelData.name; Layout.fillWidth: true; elide: Text.ElideRight; font.family: Theme.font; font.pixelSize: 12; color: Theme.text }
                Text {
                    text: "✓ applied"
                    font.family: Theme.font
                    font.pixelSize: 10
                    color: Theme.green
                    opacity: tile.selected ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.normal } }
                }
            }
            MouseArea {
                id: hover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => { gallery.currentIndex = tile.index; gallery.apply(tile.modelData, tile, mouse.x, mouse.y) }
            }
        }
        Text { anchors.centerIn: parent; visible: gallery.count === 0 && !view.shell.wallpaperBusy; text: "Add images to Pictures/Wallpapers"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 12 }
    }
    Text { visible: view.shell.wallpaperError !== ""; text: view.shell.wallpaperError; Layout.fillWidth: true; wrapMode: Text.WordWrap; color: Theme.red; font.family: Theme.font; font.pixelSize: 11 }
    Text { text: view.shell.wallpaperBusy ? "Applying…" : "Click a preview to apply  ·  ↑ ↓ ← → navigate  ·  Esc close"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 11 }
}
