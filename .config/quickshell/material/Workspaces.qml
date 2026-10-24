import QtQuick
import Quickshell
import Quickshell.Hyprland
Item {
    id: root
    readonly property int slot: 25
    readonly property int gap: 3
    readonly property var computedIds: [1, 2, 3, 4, 5].concat(Hyprland.workspaces.values.filter(w => w.id > 5).map(w => w.id).sort((a, b) => a - b))
    property var ids: [1, 2, 3, 4, 5]
    readonly property int activeId: Hyprland.focusedMonitor && Hyprland.focusedMonitor.activeWorkspace ? Hyprland.focusedMonitor.activeWorkspace.id : 1
    readonly property int activeIndex: ids.indexOf(activeId)
    property real edgeLeft: 0
    property real edgeRight: slot
    property bool ready: false
    implicitWidth: ids.length * slot + (ids.length - 1) * gap
    implicitHeight: 22
    Behavior on implicitWidth { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
    onComputedIdsChanged: if (JSON.stringify(computedIds) !== JSON.stringify(ids)) ids = computedIds
    function place() {
        if (activeIndex < 0) return
        const target = activeIndex * (slot + gap)
        const forward = target > edgeLeft
        leftMove.duration = forward ? 360 : 190
        rightMove.duration = forward ? 190 : 360
        edgeLeft = target
        edgeRight = target + slot
    }
    onActiveIndexChanged: place()
    Component.onCompleted: { place(); ready = true }
    Rectangle {
        x: root.edgeLeft
        width: root.edgeRight - root.edgeLeft
        height: root.implicitHeight
        radius: 6
        color: Theme.elevated
        opacity: root.activeIndex < 0 ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: Theme.fast } }
        Rectangle {
            anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
            width: Math.max(10 / Theme.uiScale, 14 / Theme.uiScale - (parent.width - root.slot) * 0.15)
            height: 2 / Theme.uiScale
            radius: 1
            color: Theme.green
        }
    }
    Behavior on edgeLeft { enabled: root.ready; NumberAnimation { id: leftMove; easing.type: Easing.OutCubic } }
    Behavior on edgeRight { enabled: root.ready; NumberAnimation { id: rightMove; easing.type: Easing.OutCubic } }
    Row {
        spacing: root.gap
        Repeater {
            model: root.ids
            Chip {
                id: chip
                required property int modelData
                readonly property bool active: root.activeId === modelData
                readonly property bool occupied: Hyprland.workspaces.values.some(w => w.id === modelData)
                compact: true
                iconSize: 13
                implicitWidth: root.slot
                fontSize: active ? 11 : 13
                shortcut: "Super + " + modelData
                label: active ? (modelData < 10 ? "0" + modelData : String(modelData)) : occupied ? "●" : "○"
                ink: active ? Theme.green : occupied ? Theme.text : Theme.muted
                color: mouseOver && !active ? Theme.surface : "transparent"
                readonly property bool mouseOver: hover.hovered
                HoverHandler { id: hover }
                property real pulse: 1
                transform: Scale { origin.x: chip.width / 2; origin.y: chip.height / 2; xScale: chip.pulse; yScale: chip.pulse }
                onActiveChanged: if (active && root.ready) pop.restart()
                SequentialAnimation {
                    id: pop
                    NumberAnimation { target: chip; property: "pulse"; to: 0.8; duration: 70; easing.type: Easing.OutQuad }
                    SpringAnimation { target: chip; property: "pulse"; to: 1; spring: 5; damping: 0.28 }
                }
                onClicked: Quickshell.execDetached(["hyprctl", "eval", "hl.dispatch(hl.dsp.focus({workspace=" + modelData + "}))"])
            }
        }
    }
}
