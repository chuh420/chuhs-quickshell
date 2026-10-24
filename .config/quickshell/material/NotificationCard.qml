import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
Item {
    id: root
    required property var shell
    property var notification: null
    property bool popup: false
    property bool paused: hover.hovered || drag.active
    property real progress: 1
    property real slide: 0
    property bool leaving: false
    signal finished()
    readonly property bool critical: notification && notification.urgency === NotificationUrgency.Critical
    readonly property int timeout: {
        if (!notification) return 5000
        if (critical) return 0
        if (notification.expireTimeout > 0) return Math.max(1500, notification.expireTimeout)
        return notification.urgency === NotificationUrgency.Low ? 4000 : 6000
    }
    implicitHeight: body.implicitHeight
    function iconSource() {
        const n = notification
        if (!n) return ""
        if (n.image) return n.image
        const icon = n.appIcon || ""
        if (icon.startsWith("file://") || icon.startsWith("image://")) return icon
        if (icon.startsWith("/")) return "file://" + icon
        if (icon && Quickshell.hasThemeIcon(icon)) return Quickshell.iconPath(icon)
        const entry = (n.desktopEntry || "").toLowerCase()
        if (entry && Quickshell.hasThemeIcon(entry)) return Quickshell.iconPath(entry)
        return ""
    }
    function age() {
        const time = notification ? shell.notificationTimes[notification.id] : 0
        if (!time) return ""
        const minutes = Math.floor((shell.clock.date.getTime() - time) / 60000)
        return minutes < 1 ? "now" : minutes < 60 ? minutes + "m" : Math.floor(minutes / 60) + "h"
    }
    function close(dismiss) {
        if (leaving) return
        leaving = true
        leave.to = slide < 0 ? -width - 40 : width + 40
        leave.dismiss = dismiss
        leave.restart()
    }
    function activate() {
        const n = notification
        if (!n) return
        const action = n.actions.find(a => a.identifier === "default")
        if (action) { action.invoke(); close(!n.resident) }
        else if (popup) close(false)
    }
    function restartTimer() {
        if (!popup || timeout <= 0) return
        countdown.stop()
        progress = 1
        countdown.duration = timeout
        countdown.start()
    }
    Component.onCompleted: restartTimer()
    Connections {
        target: root.shell
        enabled: root.popup
        function onPopupRefresh(nid) { if (root.notification && nid === root.notification.id) root.restartTimer() }
    }
    NumberAnimation {
        id: countdown
        target: root
        property: "progress"
        to: 0
        paused: running && root.paused
        onFinished: root.close(false)
    }
    NumberAnimation {
        id: leave
        property bool dismiss: false
        target: root
        property: "slide"
        duration: Theme.normal
        easing.type: Easing.InCubic
        onFinished: {
            const n = root.notification
            if (dismiss && n) n.dismiss()
            root.finished()
        }
    }
    NumberAnimation { id: settle; target: root; property: "slide"; to: 0; duration: Theme.slow; easing.type: Easing.OutBack }
    Rectangle {
        id: body
        x: root.slide
        width: root.width
        implicitHeight: content.implicitHeight + 26
        opacity: Math.max(0, 1 - Math.abs(root.slide) / (root.width * 0.9))
        radius: 14
        color: hover.hovered ? Theme.surface : Theme.bg
        border.color: root.critical ? Theme.red : Theme.line
        Behavior on color { ColorAnimation { duration: Theme.fast } }
        HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
        DragHandler {
            id: drag
            target: null
            yAxis.enabled: false
            property real start: 0
            onActiveChanged: {
                if (active) { start = root.slide; settle.stop() }
                else if (Math.abs(root.slide) > root.width * 0.3) root.close(true)
                else settle.restart()
            }
            onTranslationChanged: if (active) root.slide = start + translation.x
        }
        TapHandler {
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onTapped: (point, button) => {
                if (button === Qt.LeftButton) root.activate()
                else root.close(button === Qt.RightButton || !root.popup)
            }
        }
        RowLayout {
            id: content
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 13 }
            spacing: 12
            Rectangle {
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38
                Layout.alignment: Qt.AlignTop
                radius: 10
                color: Theme.elevated
                clip: true
                Image {
                    id: icon
                    anchors.fill: parent
                    anchors.margins: root.notification && root.notification.image ? 0 : 6
                    source: root.iconSource()
                    sourceSize.width: 76
                    sourceSize.height: 76
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: status === Image.Ready
                }
                Text {
                    anchors.centerIn: parent
                    visible: !icon.visible
                    text: root.critical ? "󰀦" : "󰂚"
                    color: root.critical ? Theme.red : Theme.yellow
                    font.family: Theme.icons
                    font.pixelSize: 18
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: root.notification ? (root.notification.appName || "notification").toLowerCase() : ""; color: Theme.green; font.family: Theme.font; font.pixelSize: 9; font.letterSpacing: 0.6; elide: Text.ElideRight; Layout.fillWidth: true }
                    Text { text: root.age(); color: Theme.muted; font.family: Theme.font; font.pixelSize: 9 }
                    Text {
                        text: "×"
                        color: closeHover.hovered ? Theme.text : Theme.muted
                        font.family: Theme.font
                        font.pixelSize: 13
                        HoverHandler { id: closeHover }
                        TapHandler { onTapped: root.close(true) }
                    }
                }
                Text { text: root.notification ? root.notification.summary : ""; visible: text !== ""; color: Theme.text; font.family: Theme.font; font.pixelSize: 13; font.weight: Font.Medium; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight; Layout.fillWidth: true }
                Text {
                    text: root.notification ? root.notification.body.replace(/<img[^>]*>/g, "") : ""
                    visible: text !== ""
                    textFormat: Text.StyledText
                    color: Theme.muted
                    linkColor: Theme.green
                    font.family: Theme.font
                    font.pixelSize: 11
                    wrapMode: Text.Wrap
                    maximumLineCount: root.popup ? 3 : 6
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    onLinkActivated: link => Qt.openUrlExternally(link)
                }
                Flow {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    spacing: 6
                    visible: actions.count > 0
                    Repeater {
                        id: actions
                        model: root.notification ? root.notification.actions.filter(a => a.identifier !== "default" && a.text) : []
                        Chip {
                            required property var modelData
                            compact: true
                            label: modelData.text
                            color: Theme.elevated
                            onClicked: { modelData.invoke(); root.close(!(root.notification && root.notification.resident)) }
                        }
                    }
                }
            }
        }
        Rectangle {
            visible: root.popup && root.timeout > 0
            anchors { left: parent.left; bottom: parent.bottom; leftMargin: 14; bottomMargin: 1 }
            width: (parent.width - 28) * root.progress
            height: 2
            radius: 1
            color: root.critical ? Theme.red : Theme.green
            opacity: 0.7
        }
    }
}
