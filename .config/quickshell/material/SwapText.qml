import QtQuick
Item {
    id: root
    property string text
    property string key: ""
    property string shownKey: ""
    property color color: Theme.text
    property string family: Theme.font
    property int pixelSize: 10
    property real maxWidth: 100000
    property int distance: 7
    property bool ready: false
    property string shown: ""
    implicitWidth: Math.min(maxWidth, current.implicitWidth)
    implicitHeight: current.implicitHeight
    clip: true
    Behavior on implicitWidth { enabled: root.ready; NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
    Component.onCompleted: { current.text = text; shown = text; shownKey = key; ready = true }
    onTextChanged: Qt.callLater(update)
    onKeyChanged: Qt.callLater(update)
    function update() {
        if (!ready || text === shown) return
        if (key !== "" && key === shownKey) { current.text = text; shown = text; return }
        shownKey = key
        previous.text = shown
        current.text = text
        shown = text
        swap.restart()
    }
    Text {
        id: previous
        width: root.width
        anchors.verticalCenter: parent.verticalCenter
        opacity: 0
        color: root.color
        font.family: root.family
        font.pixelSize: root.pixelSize
        elide: Text.ElideRight
    }
    Text {
        id: current
        width: root.width
        anchors.verticalCenter: parent.verticalCenter
        color: root.color
        font.family: root.family
        font.pixelSize: root.pixelSize
        elide: Text.ElideRight
    }
    ParallelAnimation {
        id: swap
        NumberAnimation { target: previous; property: "opacity"; from: 1; to: 0; duration: Theme.fast; easing.type: Easing.InQuad }
        NumberAnimation { target: previous; property: "anchors.verticalCenterOffset"; from: 0; to: -root.distance; duration: Theme.fast; easing.type: Easing.InQuad }
        NumberAnimation { target: current; property: "opacity"; from: 0; to: 1; duration: Theme.normal; easing.type: Easing.OutCubic }
        NumberAnimation { target: current; property: "anchors.verticalCenterOffset"; from: root.distance; to: 0; duration: Theme.slow; easing.type: Easing.OutCubic }
    }
}
