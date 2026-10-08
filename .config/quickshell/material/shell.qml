import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import Quickshell.Bluetooth

ShellRoot {
    id: root
    property string panel: ""
    property var hiddenApplications: []
    FileView {
        id: hiddenApplicationsFile
        path: Quickshell.env("HOME") + "/.config/quickshell/material/hidden-applications.json"
        blockLoading: true
        printErrors: false
    }
    Component.onCompleted: {
        try {
            const saved = JSON.parse(hiddenApplicationsFile.text() || "[]")
            if (Array.isArray(saved)) root.hiddenApplications = saved.filter(id => typeof id === "string")
        } catch(e) { console.warn("Could not read hidden applications:", e) }
    }
    function toggleApplicationHidden(id) {
        hiddenApplications = hiddenApplications.includes(id)
            ? hiddenApplications.filter(value => value !== id)
            : hiddenApplications.concat([id])
        hiddenApplicationsFile.setText(JSON.stringify(hiddenApplications) + "\n")
    }
    property var wifi: ({powered: false, networks: [], state: "", scanning: false, busy: false, message: ""})
    property string wifiPrompt: ""
    property var bluetoothPrompt: ({name: "", mode: "", value: ""})
    property real moduleX: 0
    readonly property bool modulePanel: ["wifi", "bluetooth", "audio", "battery"].includes(panel)
    function openModule(which, item) { moduleX = item.mapToItem(null, item.width / 2, 0).x; toggle(which) }
    function wifiCommand(data) { wifiWorker.write(JSON.stringify(data) + "\n") }
    Process {
        id: wifiWorker
        command: ["python", "/home/chuh/.config/rice/wifi.py"]
        running: true
        stdinEnabled: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    const value = JSON.parse(data)
                    if (value.kind === "state") root.wifi = value
                    else if (value.kind === "bluetooth-prompt") { root.bluetoothPrompt = value; if (value.name) root.panel = "bluetooth" }
                    else if (value.kind === "prompt") { root.wifiPrompt = value.name; if (value.name) root.panel = "wifi" }
                } catch(e) {}
            }
        }
    }
    property var trayTarget: null
    property var trayBar: null
    property real trayX: 0
    property var keyboardLayout: ({label: "…", name: "", device: ""})
    property bool keyboardInitialized: false
    Process {
        id: keyboardStatus
        command: ["python", "/home/chuh/.config/rice/keyboard.py", "status"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const next = JSON.parse(text)
                    if (root.keyboardInitialized && next.name !== root.keyboardLayout.name)
                        Quickshell.execDetached(["python", "/home/chuh/.config/rice/keyboard.py", "notify", next.name])
                    root.keyboardLayout = next
                    root.keyboardInitialized = true
                } catch(e) {}
            }
        }
    }
    Timer {
        id: keyboardRefresh
        interval: 60
        onTriggered: { if (!keyboardStatus.running) keyboardStatus.running = true; else restart() }
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activelayout" || event.name === "configreloaded") keyboardRefresh.restart()
        }
    }
    property var wallpapers: []
    property string currentWallpaper: ""
    property string wallpaperError: ""
    onPanelChanged: {
        if (panel === "wallpapers" && !wallpaperScan.running) { wallpaperError = ""; wallpaperScan.running = true }
        if (panel === "wifi" && wifi.powered && !wifi.scanning && !wifi.busy) wifiCommand({action: "scan"})
        if (panel !== "bluetooth" && bluetoothPrompt.name) wifiCommand({action: "bluetooth-reply", accepted: false})
        if (panel !== "wifi" && wifiPrompt) wifiCommand({action: "cancel"})
    }
    function applyWallpaper(path) {
        if (wallpaperApply.running) return
        wallpaperError = ""
        wallpaperApply.command = ["python", "/home/chuh/.config/rice/wallpapers.py", "apply", path]
        wallpaperApply.running = true
    }
    Process {
        id: wallpaperScan
        command: ["python", "/home/chuh/.config/rice/wallpapers.py", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { const data = JSON.parse(text); root.wallpapers = data.items; root.currentWallpaper = data.current }
                catch(e) { root.wallpaperError = "Could not read wallpaper folder" }
            }
        }
    }
    Process {
        id: wallpaperApply
        stderr: StdioCollector { onStreamFinished: if (text.trim()) root.wallpaperError = text.trim() }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) wallpaperScan.running = true
            else if (!root.wallpaperError) root.wallpaperError = "Could not apply wallpaper"
        }
    }
    property var stats: ({battery: 0, present: false, charging: false, network: "Offline", connected: false, brightness: 50})
    property var sink: Pipewire.defaultAudioSink
    property var adapter: Bluetooth.defaultAdapter
    property var player: Mpris.players.values.length ? Mpris.players.values[0] : null
    property int volume: sink && sink.audio ? Math.round(sink.audio.volume * 100) : 0
    property bool muted: sink && sink.audio ? sink.audio.muted : true
    function run(action) { Quickshell.execDetached(["/home/chuh/.local/bin/chuhshell", action]) }
    function toggle(which) { panel = panel === which ? "" : which }
    PwObjectTracker { objects: [root.sink] }
    SystemClock { id: clock; precision: SystemClock.Minutes }
    Process {
        id: status
        command: ["python", "/home/chuh/.config/rice/status.py"]
        running: true
        stdout: StdioCollector { onStreamFinished: { try { root.stats = JSON.parse(text) } catch(e) {} } }
    }
    Timer { interval: 5000; running: true; repeat: true; onTriggered: if (!status.running) status.running = true }
    IpcHandler {
        target: "shell"
        function launcher(): void { root.toggle("launcher") }
        function menu(): void { root.toggle("control") }
        function calendar(): void { root.toggle("calendar") }
        function wallpapers(): void { root.toggle("wallpapers") }
        function wifi(): void { root.toggle("wifi") }
        function bluetooth(): void { root.toggle("bluetooth") }
        function audio(): void { root.toggle("audio") }
        function battery(): void { root.toggle("battery") }
        function close(): void { root.panel = "" }
    }
    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: bar
            required property var modelData
            screen: modelData
            anchors { top: true; left: true; right: true }
            margins { top: Math.round(6 * Theme.uiScale); left: Math.round(10 * Theme.uiScale); right: Math.round(10 * Theme.uiScale) }
            implicitHeight: Math.ceil(28 * Theme.uiScale)
            exclusiveZone: Math.ceil(28 * Theme.uiScale)
            color: "transparent"
            WlrLayershell.namespace: "material-bar"
            Rectangle {
                width: parent.width / Theme.uiScale
                height: parent.height / Theme.uiScale
                scale: Theme.uiScale
                transformOrigin: Item.TopLeft
                radius: 9
                color: Theme.bg
                border.color: Theme.line
                RowLayout {
                    anchors { left: parent.left; leftMargin: 5; verticalCenter: parent.verticalCenter }
                    spacing: 3
                    Chip { compact: true; label: "󰣇"; ink: Theme.green; onClicked: root.toggle("launcher") }
                    Rectangle { width: 1; height: 12; color: Theme.line; Layout.leftMargin: 4; Layout.rightMargin: 6 }
                    Repeater {
                        model: [1, 2, 3, 4, 5].concat(Hyprland.workspaces.values.filter(w => w.id > 5).map(w => w.id).sort((a,b) => a-b))
                        Chip { compact: true;
                            required property int modelData
                            property int workspaceId: modelData
                            property bool active: Hyprland.focusedMonitor && Hyprland.focusedMonitor.activeWorkspace && Hyprland.focusedMonitor.activeWorkspace.id === workspaceId
                            property bool occupied: Hyprland.workspaces.values.some(w => w.id === workspaceId)
                            shortcut: "Super + " + workspaceId
                            label: active ? "0" + (workspaceId) : occupied ? "●" : "○"
                            implicitWidth: active ? 32 : 23
                            selected: active
                            ink: active ? Theme.green : occupied ? Theme.text : Theme.muted
                            Behavior on implicitWidth { NumberAnimation { duration: 180 } }
                            onClicked: Quickshell.execDetached(["hyprctl", "eval", "hl.dispatch(hl.dsp.focus({workspace=" + (workspaceId) + "}))"])
                        }
                    }
                    Text {
                        text: Hyprland.activeToplevel ? Hyprland.activeToplevel.title : "still / material"
                        color: Theme.muted
                        font.family: Theme.font
                        font.pixelSize: 10
                        elide: Text.ElideRight
                        Layout.maximumWidth: Math.max(70, bar.width / Theme.uiScale * 0.16)
                        Layout.leftMargin: 12
                    }
                }
                Chip { compact: true;
                    anchors.centerIn: parent
                    label: clock.date.toLocaleString(Qt.locale("en_US"), "ddd, d MMM  ·  HH:mm")
                    ink: Theme.text
                    onClicked: root.toggle("calendar")
                }
                RowLayout {
                    anchors { right: parent.right; rightMargin: 5; verticalCenter: parent.verticalCenter }
                    spacing: 2
                    Repeater {
                        model: SystemTray.items
                        Item {
                            required property var modelData
                            implicitWidth: 23; implicitHeight: 22
                            Image {
                                id: trayIcon
                                anchors.centerIn: parent
                                width: 15; height: 15
                                source: modelData.icon
                                visible: source.toString() !== "" && status !== Image.Error
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: !trayIcon.visible
                                text: "󰀻"
                                color: Theme.muted
                                font.family: Theme.icons
                                font.pixelSize: 14
                            }
                            MouseArea {
                                anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: event => {
                                    if (event.button === Qt.RightButton) {
                                        root.trayTarget = modelData
                                        root.trayBar = bar
                                        root.trayX = mapToItem(null, 0, 0).x
                                        root.panel = "tray"
                                    } else if (modelData.onlyMenu) modelData.display(bar, bar.width - 100, 28)
                                    else modelData.activate()
                                }
                                onWheel: event => modelData.scroll(event.angleDelta.y, false)
                            }
                        }
                    }
                    Rectangle {
                        implicitWidth: 47
                        implicitHeight: 22
                        radius: 6
                        color: keyboardHover.containsMouse ? Theme.elevated : "transparent"
                        Behavior on color { ColorAnimation { duration: 140 } }
                        Row {
                            anchors.centerIn: parent
                            spacing: 5
                            Image {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 14
                                height: 10
                                source: "file:///home/chuh/.config/rice/icons/keyboard-bar.svg"
                            }
                            Text {
                                text: root.keyboardLayout.label
                                color: Theme.text
                                font.family: Theme.icons
                                font.pixelSize: 10
                            }
                        }
                        MouseArea {
                            id: keyboardHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached(["python", "/home/chuh/.config/rice/keyboard.py", "next"])
                        }
                    }
                    Chip { id: networkChip; compact: true; label: root.stats.connected ? "󰤨" : "󰤭"; ink: root.stats.connected ? Theme.green : Theme.muted; onClicked: root.openModule("wifi", networkChip) }
                    Chip { id: bluetoothChip; compact: true; label: "󰂯"; ink: root.adapter && root.adapter.enabled ? Theme.green : Theme.muted; onClicked: root.openModule("bluetooth", bluetoothChip) }
                    Chip { id: audioChip; compact: true; label: root.muted ? "󰖁" : "󰕾"; shortcut: "XF86AudioRaiseVolume / XF86AudioLowerVolume / XF86AudioMute"; onClicked: root.openModule("audio", audioChip); onRightClicked: root.run("volume-mute"); onScrolled: delta => root.run(delta > 0 ? "volume-up" : "volume-down") }
                    Chip { id: batteryChip; compact: true; visible: root.stats.present; label: (root.stats.charging ? "󰂄 " : "󰁹 ") + root.stats.battery + "%"; ink: root.stats.battery < 20 ? Theme.red : Theme.text; onClicked: root.openModule("battery", batteryChip) }
                    Rectangle { width: 1; height: 12; color: Theme.line; Layout.leftMargin: 5; Layout.rightMargin: 5 }
                    Chip { compact: true; label: "󰂚"; shortcut: "Super + N"; ink: Theme.yellow; onClicked: root.run("notifications") }
                    Chip { compact: true; label: "󰒓"; shortcut: "Super + Space"; ink: Theme.green; onClicked: root.toggle("control") }
                }
            }
        }
    }
    PanelWindow {
        id: popup
        visible: root.panel !== ""
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "material-overlay"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        FocusScope {
            id: popupKeys
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: event => { root.panel = ""; event.accepted = true }
            Connections {
                target: root
                function onPanelChanged() {
                    if (root.panel && root.panel !== "launcher" && root.panel !== "wallpapers" && !root.wifiPrompt && !root.bluetoothPrompt.name)
                        Qt.callLater(() => popupKeys.forceActiveFocus())
                }
            }
        Rectangle { anchors.fill: parent; color: root.modulePanel ? "#181d2021" : "#601d2021"; MouseArea { anchors.fill: parent; onClicked: root.panel = "" } }
        Rectangle {
            id: card
            scale: Theme.uiScale
            transformOrigin: Item.TopLeft
            width: root.modulePanel ? 350 : root.panel === "tray" ? 240 : root.panel === "wallpapers" ? Math.min(720, (parent.width - 28) / Theme.uiScale) : root.panel === "launcher" ? 560 : 370
            height: root.modulePanel ? Math.min((parent.height - 70) / Theme.uiScale, root.panel === "battery" ? 350 : root.panel === "audio" ? 370 : root.panel === "wifi" && root.wifiPrompt ? 535 : 420) : root.panel === "tray" ? 180 : root.panel === "wallpapers" ? Math.min(480, (parent.height - 88) / Theme.uiScale) : root.panel === "launcher" ? 478 : root.panel === "calendar" ? 410 : 610
            x: root.modulePanel ? Math.min(Math.max(14, root.moduleX ? root.moduleX - width * scale / 2 : parent.width - width * scale - 14), parent.width - width * scale - 14) : root.panel === "tray" ? Math.min(Math.max(14, root.trayX - width * scale / 2), parent.width - width * scale - 14) : root.panel === "launcher" || root.panel === "wallpapers" ? (parent.width - width * scale) / 2 : parent.width - width * scale - 14
            y: root.panel === "launcher" || root.panel === "wallpapers" ? Math.min(130, (parent.height - height * scale) / 2) : Math.ceil(44 * Theme.uiScale)
            color: Theme.bg; radius: root.modulePanel ? 14 : 22; border.color: Theme.line
            MouseArea { anchors.fill: parent }
            Loader { anchors.fill: parent; anchors.margins: root.modulePanel ? 18 : 24; sourceComponent: root.panel === "wifi" ? wifiView : root.panel === "bluetooth" ? bluetoothView : root.panel === "audio" ? audioView : root.panel === "battery" ? batteryView : root.panel === "tray" ? trayMenu : root.panel === "wallpapers" ? wallpaperPicker : root.panel === "launcher" ? launcher : root.panel === "calendar" ? calendar : control }
        }
        
        }

    }
    Component { id: wifiView; WifiPanel { shell: root } }
    Component { id: bluetoothView; BluetoothPanel { shell: root } }
    Component { id: audioView; AudioPanel { shell: root } }
    Component { id: batteryView; BatteryPanel { shell: root } }
    Component {
        id: trayMenu
        ColumnLayout {
            spacing: 8
            Text {
                Layout.fillWidth: true
                text: root.trayTarget ? (root.trayTarget.title || root.trayTarget.id) : "Application"
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 13
                elide: Text.ElideRight
            }
            Repeater {
                model: ["Open application", "Application menu", "Quit application"]
                Rectangle {
                    required property string modelData
                    required property int index
                    Layout.fillWidth: true
                    implicitHeight: 30
                    radius: 7
                    color: trayMenuMouse.containsMouse ? Theme.elevated : "transparent"
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData
                        color: index === 2 ? Theme.red : Theme.text
                        font.family: Theme.font
                        font.pixelSize: 12
                    }
                    MouseArea {
                        id: trayMenuMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const target = root.trayTarget
                            root.panel = ""
                            if (!target) return
                            if (index === 0) target.activate()
                            else if (index === 1) target.display(root.trayBar, root.trayX, 28)
                            else Quickshell.execDetached(["python", "/home/chuh/.config/rice/tray.py", "quit", target.id, target.title])
                        }
                    }
                }
            }
        }
    }
    Component {
        id: launcher
        ColumnLayout {
            id: launcherView
            property bool showHidden: false
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
                root.toggleApplicationHidden(id)
                restoreSelection(id, index)
            }
            function toggleShowHidden() {
                const id = apps.currentItem ? apps.currentItem.modelData.id : ""
                const index = Math.max(0, apps.currentIndex)
                showHidden = !showHidden
                restoreSelection(id, index)
            }
            spacing: 14
            Text { text: "APPLICATIONS"; color: Theme.green; font.family: Theme.font; font.pixelSize: 11; font.letterSpacing: 3 }
            Rectangle {
                Layout.fillWidth: true; height: 52; radius: 12; color: Theme.surface; border.color: search.activeFocus ? Theme.green : Theme.line
                TextInput {
                    id: search
                    anchors.fill: parent; anchors.margins: 16
                    color: Theme.text; font.family: Theme.font; font.pixelSize: 16
                    focus: true; clip: true; selectByMouse: true
                    Component.onCompleted: forceActiveFocus()
                    Text { visible: !search.text; text: "Search applications…"; color: Theme.muted; font: search.font }
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_H && (event.modifiers === Qt.ControlModifier || event.modifiers === (Qt.ControlModifier | Qt.ShiftModifier))) {
                            if (!event.isAutoRepeat) {
                                if (event.modifiers & Qt.ShiftModifier) launcherView.toggleShowHidden()
                                else launcherView.toggleHidden()
                            }
                            event.accepted = true
                        }
                    }
                    Keys.onEscapePressed: root.panel = ""
                    Keys.onDownPressed: apps.currentIndex = Math.min(apps.count - 1, apps.currentIndex + 1)
                    Keys.onUpPressed: apps.currentIndex = Math.max(0, apps.currentIndex - 1)
                    Keys.onReturnPressed: if (apps.currentItem) { apps.currentItem.launch(); root.panel = "" }
                    onTextChanged: apps.currentIndex = 0
                }
            }
            ListView {
                id: apps
                Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 5
                model: DesktopEntries.applications.values.filter(a => !a.noDisplay && (launcherView.showHidden || !root.hiddenApplications.includes(a.id)) && (a.name + " " + a.genericName + " " + a.comment).toLowerCase().includes(search.text.toLowerCase())).sort((a,b) => { const favorite = a => /kitty|zen|dolphin|pavucontrol/i.test(a.id) ? 0 : 1; return favorite(a) - favorite(b) || a.name.localeCompare(b.name) })
                currentIndex: 0
                delegate: Rectangle {
                    id: entry
                    required property var modelData
                    required property int index
                    readonly property bool hidden: root.hiddenApplications.includes(modelData.id)
                    function launch() { modelData.execute() }
                    width: apps.width; height: 56; radius: 11
                    color: ListView.isCurrentItem ? Theme.elevated : hover.containsMouse ? Theme.surface : "transparent"
                    RowLayout {
                        anchors.fill: parent; anchors.margins: 10; spacing: 13
                        opacity: entry.hidden ? 0.55 : 1
                        Rectangle {
                            Layout.preferredWidth: 28; Layout.preferredHeight: 28; radius: 7; color: Theme.elevated
                            property bool hasIcon: Quickshell.hasThemeIcon(modelData.icon)
                            Image { anchors.fill: parent; source: parent.hasIcon ? Quickshell.iconPath(modelData.icon) : "" }
                            Text { anchors.centerIn: parent; visible: !parent.hasIcon; text: modelData.name.charAt(0); color: Theme.green; font.family: Theme.font; font.pixelSize: 16 }
                        }
                        ColumnLayout {
                            spacing: 2
                            Text { text: modelData.name; color: Theme.text; font.family: Theme.font; font.pixelSize: 14 }
                            Text { text: modelData.genericName || modelData.comment || "Application"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 10; elide: Text.ElideRight; Layout.maximumWidth: 390 }
                        }
                        Item { Layout.fillWidth: true }
                        Text { visible: entry.hidden; text: "󰈈"; color: Theme.muted; font.family: Theme.icons; font.pixelSize: 18 }
                        Text { visible: entry.ListView.isCurrentItem; text: "↵"; color: Theme.green }
                    }
                    MouseArea { id: hover; anchors.fill: parent; hoverEnabled: true; onClicked: { entry.launch(); root.panel = "" } }
                }
                Text { anchors.centerIn: parent; visible: apps.count === 0; text: "No results found"; color: Theme.muted; font.family: Theme.font }
            }
            Text {
                text: "↑ ↓  select       ↵  launch       󰈉  ctrl+h  " + (apps.currentItem && apps.currentItem.hidden ? "unhide" : "hide") + "       󰈈  ctrl+shift+h  " + (launcherView.showHidden ? "hide hidden" : "show hidden") + "       esc  close"
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: 10
            }
        }
    }
    Component {
        id: control
        ColumnLayout {
            spacing: 16
            RowLayout {
                Text { text: "Control center"; font.family: Theme.font; font.pixelSize: 21; color: Theme.text; Layout.fillWidth: true }
                Chip { fontSize: 18; label: "󰒲"; shortcut: "Super + Ctrl + L"; ink: Theme.yellow; onClicked: root.run("lock") }
            }
            Text { text: clock.date.toLocaleString(Qt.locale("en_US"), "dddd, d MMMM"); color: Theme.muted; font.family: Theme.font; font.pixelSize: 12 }
            Rectangle {
                Layout.fillWidth: true; height: 68; radius: 14; color: Theme.surface
                RowLayout {
                    anchors.fill: parent; anchors.margins: 12; spacing: 12
                    Text { text: "󰤨"; color: Theme.green; font.family: Theme.icons; font.pixelSize: 22; Layout.preferredWidth: 28; horizontalAlignment: Text.AlignHCenter }
                    ColumnLayout {
                        Layout.fillWidth: true; Layout.minimumWidth: 0; spacing: 4
                        Text { text: root.stats.network; color: Theme.text; font.family: Theme.font; font.pixelSize: 13; elide: Text.ElideRight; Layout.fillWidth: true }
                        Text { text: root.stats.connected ? "Connected" : "Disconnected"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 10; Layout.fillWidth: true }
                    }
                    Chip { fontSize: 18; label: "↗"; ink: Theme.green; onClicked: root.toggle("wifi") }
                }
            }
            Rectangle {
                Layout.fillWidth: true; height: 60; radius: 14; color: Theme.surface
                RowLayout {
                    anchors.fill: parent; anchors.margins: 12
                    Text { text: "󰂯"; color: root.adapter && root.adapter.enabled ? Theme.green : Theme.muted; font.family: Theme.icons; font.pixelSize: 22 }
                    Text { text: root.adapter ? (root.adapter.enabled ? "Bluetooth enabled" : "Bluetooth disabled") : "Bluetooth unavailable"; color: Theme.text; font.family: Theme.font; Layout.fillWidth: true; font.pixelSize: 12 }
                    Chip { label: root.adapter && root.adapter.enabled ? "ON" : "OFF"; onClicked: if (root.adapter) root.adapter.enabled = !root.adapter.enabled; onRightClicked: root.toggle("bluetooth") }
                }
            }
            RowLayout { spacing: 10; Text { text: "󰕾"; color: Theme.text; font.family: Theme.icons; font.pixelSize: 20 } Text { text: "Volume"; color: Theme.text; font.family: Theme.font; font.pixelSize: 12; Layout.fillWidth: true } Chip { label: root.muted ? "MUTE" : root.volume + "%"; shortcut: "XF86AudioMute"; onClicked: root.run("volume-mute"); onRightClicked: root.run("audio") } }
            MaterialSlider {
                Layout.fillWidth: true; from: 0; to: 100; value: root.volume
                shortcut: "XF86AudioRaiseVolume / XF86AudioLowerVolume"
                onMoved: if (root.sink && root.sink.audio) root.sink.audio.volume = value / 100
            }
            RowLayout { spacing: 10; Text { text: "󰃟"; color: Theme.text; font.family: Theme.icons; font.pixelSize: 20 } Text { text: "Brightness · " + root.stats.brightness + "%"; color: Theme.text; font.family: Theme.font; font.pixelSize: 12 } }
            MaterialSlider {
                Layout.fillWidth: true; from: 5; to: 100; value: root.stats.brightness
                accent: Theme.yellow
                shortcut: "XF86MonBrightnessUp / XF86MonBrightnessDown"
                onMoved: Quickshell.execDetached(["brightnessctl", "set", Math.round(value) + "%"])
            }
            Rectangle {
                Layout.fillWidth: true; height: 72; radius: 14; color: Theme.surface
                RowLayout {
                    anchors.fill: parent; anchors.margins: 12
                    ColumnLayout { Layout.fillWidth: true; spacing: 5
                        Text { text: root.player ? root.player.trackTitle || "Media player" : "A quiet moment"; color: Theme.text; font.family: Theme.font; elide: Text.ElideRight; Layout.maximumWidth: 220 }
                        Text { text: root.player ? root.player.trackArtist || root.player.identity : "Your music will appear here"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 10 }
                    }
                    Chip { fontSize: 20; label: root.player && root.player.isPlaying ? "󰏤" : "󰐊"; shortcut: "XF86AudioPlay"; ink: Theme.green; onClicked: if(root.player) root.player.togglePlaying() }
                }
            }
            Item { Layout.fillHeight: true }
            RowLayout {
                spacing: 7
                Chip { fontSize: 18; label: "󰂚"; shortcut: "Super + N"; onClicked: root.run("notifications") }
                Chip { fontSize: 18; label: "󰅍"; shortcut: "Super + C"; onClicked: root.run("clipboard") }
                Chip { fontSize: 18; label: "󰄀"; shortcut: "Print"; onClicked: root.run("screenshot") }
                Chip { fontSize: 18; label: "󰸉"; shortcut: "Super + B"; ink: Theme.green; onClicked: root.toggle("wallpapers") }
                Item { Layout.fillWidth: true }
                Chip { fontSize: 18; label: "󰒲"; onClicked: { root.panel = ""; root.run("suspend") } }
                Chip { fontSize: 18; label: "󰐥"; ink: Theme.red; onClicked: root.run("power") }
            }
        }
    }
    Component {
        id: wallpaperPicker
        ColumnLayout {
            spacing: 14
            RowLayout {
                Layout.fillWidth: true
                ColumnLayout {
                    spacing: 6
                    Text { text: "Wallpapers"; font.family: Theme.font; font.pixelSize: 22; color: Theme.text }
                    Text { text: "Pictures / Wallpapers"; font.family: Theme.font; font.pixelSize: 11; color: Theme.muted }
                }
                Item { Layout.fillWidth: true }
                Chip { label: "Refresh"; onClicked: if (!wallpaperScan.running) wallpaperScan.running = true }
                Chip { label: "×"; onClicked: root.panel = "" }
            }
            GridView {
                id: gallery
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                cellWidth: width / 2
                cellHeight: cellWidth * 9 / 16 + 54
                model: root.wallpapers
                focus: true
                Component.onCompleted: forceActiveFocus()
                Keys.onEscapePressed: root.panel = ""
                Keys.onReturnPressed: if (currentItem) root.applyWallpaper(currentItem.modelData.path)
                ScrollBar.vertical: ScrollBar { }
                delegate: Rectangle {
                    id: tile
                    required property var modelData
                    required property int index
                    property bool selected: root.currentWallpaper === modelData.path
                    width: gallery.cellWidth - 10
                    height: gallery.cellHeight - 10
                    radius: 14
                    color: hover.containsMouse ? Theme.elevated : Theme.surface
                    border.width: 1
                    border.color: selected || tile.GridView.isCurrentItem ? Theme.green : Theme.line
                    Image {
                        id: preview
                        anchors { top: parent.top; left: parent.left; right: parent.right; margins: 7 }
                        height: width * 9 / 16
                        source: modelData.url
                        sourceSize.width: 640
                        sourceSize.height: 360
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        clip: true
                    }
                    RowLayout {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 13; rightMargin: 13; bottomMargin: 12 }
                        spacing: 8
                        Text { text: modelData.name; Layout.fillWidth: true; elide: Text.ElideRight; font.family: Theme.font; font.pixelSize: 12; color: Theme.text }
                        Text { visible: tile.selected; text: "✓ Applied"; font.family: Theme.font; font.pixelSize: 10; color: Theme.green }
                    }
                    MouseArea {
                        id: hover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { gallery.currentIndex = index; root.applyWallpaper(modelData.path) }
                    }
                }
                Text { anchors.centerIn: parent; visible: gallery.count === 0 && !wallpaperScan.running; text: "Add images to Pictures/Wallpapers"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 12 }
            }
            Text { visible: root.wallpaperError !== ""; text: root.wallpaperError; Layout.fillWidth: true; wrapMode: Text.WordWrap; color: Theme.red; font.family: Theme.font; font.pixelSize: 11 }
            Text { text: wallpaperApply.running ? "Applying…" : "Click a preview to apply  ·  ↑ ↓ ← → navigate  ·  Esc close"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 11 }
        }
    }
    Component {
        id: calendar
        ColumnLayout {
            spacing: 18
            Text { text: Qt.formatDateTime(clock.date, "HH:mm"); color: Theme.text; font.family: Theme.font; font.pixelSize: 48; font.weight: Font.Light }
            Text { text: clock.date.toLocaleString(Qt.locale("en_US"), "MMMM yyyy"); color: Theme.green; font.family: Theme.font; font.pixelSize: 18 }
            GridLayout {
                columns: 7; rowSpacing: 8; columnSpacing: 8; Layout.fillWidth: true
                Repeater { model: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]; Text { required property string modelData; text: modelData; color: Theme.muted; font.family: Theme.font; font.pixelSize: 11; Layout.preferredWidth: 36; horizontalAlignment: Text.AlignHCenter } }
                Repeater {
                    model: 42
                    Rectangle {
                        required property int index
                        property int day: index - ((new Date(clock.date.getFullYear(), clock.date.getMonth(), 1).getDay() + 6) % 7) + 1
                        property bool valid: day > 0 && day <= new Date(clock.date.getFullYear(), clock.date.getMonth() + 1, 0).getDate()
                        width: 36; height: 28; radius: 8; color: valid && day === clock.date.getDate() ? Theme.green : "transparent"
                        Text { anchors.centerIn: parent; text: parent.valid ? parent.day : ""; color: parent.day === clock.date.getDate() ? Theme.bg : Theme.text; font.family: Theme.font; font.pixelSize: 12 }
                    }
                }
            }
        }
    }
}
