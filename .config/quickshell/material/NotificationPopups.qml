import QtQuick
import Quickshell
import Quickshell.Wayland
PanelWindow {
    id: window
    required property var shell
    screen: shell.focusedScreen
    visible: shell.popups.count > 0
    anchors { top: true; right: true }
    margins { top: 50; right: 14 }
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 380 * Theme.uiScale
    implicitHeight: Math.max(1, Math.min(list.contentHeight * Theme.uiScale + 20, (screen ? screen.height : 1080) - 80))
    color: "transparent"
    mask: Region { item: list }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "material-notifications"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    ListView {
        id: list
        width: 380
        height: Math.max(1, contentHeight + 10)
        scale: Theme.uiScale
        transformOrigin: Item.TopLeft
        interactive: false
        spacing: 8
        model: window.shell.popups
        add: Transition {
            ParallelAnimation {
                NumberAnimation { property: "x"; from: 420; to: 0; duration: 460; easing.type: Easing.OutBack; easing.overshoot: 0.9 }
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.normal }
            }
        }
        displaced: Transition { NumberAnimation { properties: "x,y"; duration: Theme.slow; easing.type: Easing.OutCubic } }
        remove: Transition { NumberAnimation { property: "opacity"; to: 0; duration: 80 } }
        delegate: NotificationCard {
            id: card
            required property int nid
            required property int index
            width: 380
            shell: window.shell
            popup: true
            notification: window.shell.findNotification(nid)
            onNotificationChanged: if (!notification) window.shell.dropPopup(nid)
            onFinished: window.shell.dropPopup(nid)
        }
    }
}
