import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import Quickshell.Services.Pipewire
import Quickshell.Bluetooth

ShellRoot {
    id: root
    property string panel: ""
    property bool keepAwake: false
    property var hiddenApplications: []
    property var applications: []
    property string applicationQuery: ""
    property int applicationGeneration: 0
    function searchApplications(query) {
        applicationQuery = query
        applicationGeneration++
        desktopWorker.write(JSON.stringify({query: query, generation: applicationGeneration}) + "\n")
    }
    function toggleApplicationHidden(id) {
        hiddenApplications = hiddenApplications.includes(id) ? hiddenApplications.filter(value => value !== id) : hiddenApplications.concat([id])
        applicationGeneration++
        desktopWorker.write(JSON.stringify({query: applicationQuery, generation: applicationGeneration, hidden: hiddenApplications}) + "\n")
    }
    Process {
        id: desktopWorker
        command: ["python", "/home/chuh/.config/quickshell/material/helpers/desktop.py", "watch"]
        running: true
        stdinEnabled: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    const value = JSON.parse(data)
                    if (value.error) { console.warn(value.error); return }
                    if (value.generation !== root.applicationGeneration || value.query !== root.applicationQuery) return
                    root.applications = value.apps
                    root.hiddenApplications = value.hidden
                } catch(e) { console.warn(e) }
            }
        }
        onExited: desktopRestart.restart()
        onStarted: root.searchApplications(root.applicationQuery)
    }
    Timer { id: desktopRestart; interval: 2000; onTriggered: desktopWorker.running = true }
    property var bluetooth: ({powered: false, name: "", devices: [], discovering: false})
    property string bluetoothError: ""
    property var wifi: ({powered: false, networks: [], state: "", scanning: false, busy: false, message: ""})
    readonly property bool networkConnected: Boolean(wifi.connected || stats.connected)
    readonly property string networkName: wifi.connected ? wifi.network : stats.network
    property string wifiPrompt: ""
    property var bluetoothPrompt: ({name: "", mode: "", value: ""})
    property var panelScreen: Quickshell.screens[0]
    property real moduleX: 0
    property string displayedPanel: ""
    readonly property bool modulePanel: ["wifi", "bluetooth", "audio", "battery"].includes(displayedPanel)
    function openAt(which, bar) { panelScreen = bar.screen; moduleX = 0; toggle(which, true) }
    function openModule(which, item, bar) { panelScreen = bar.screen; moduleX = item.mapToItem(null, item.width / 2, 0).x; toggle(which, true) }
    function wifiCommand(data) { wifiWorker.write(JSON.stringify(data) + "\n") }
    Process {
        id: wifiWorker
        command: ["python", "/home/chuh/.config/quickshell/material/helpers/wifi.py"]
        running: true
        stdinEnabled: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    const value = JSON.parse(data)
                    if (value.kind === "state" && JSON.stringify(value) !== JSON.stringify(root.wifi)) root.wifi = value
                    else if (value.kind === "bluetooth-state") root.bluetooth = value
                    else if (value.kind === "bluetooth-error") root.bluetoothError = value.message
                    else if (value.kind === "bluetooth-prompt") { root.bluetoothPrompt = value; if (value.name) root.panel = "bluetooth" }
                    else if (value.kind === "prompt") { root.wifiPrompt = value.name; if (value.name) root.panel = "wifi" }
                } catch(e) {}
            }
        }
            onExited: wifiRestart.restart()
    }
    Timer { id: wifiRestart; interval: 2000; onTriggered: wifiWorker.running = true }
    property bool trayOnlyMenu: false
    property bool trayExpanded: false
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
    property var previews: ({})
    Process {
        id: galleryWorker
        command: ["python", "/home/chuh/.config/quickshell/material/helpers/gallery.py", "watch"]
        running: true
        stdinEnabled: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    const value = JSON.parse(data)
                    if (value.path && value.picture) root.previews = Object.assign({}, root.previews, {[value.path + "\n" + value.revision]: value.picture})
                } catch(e) { console.warn(e) }
            }
        }
        onExited: galleryRestart.restart()
    }
    Timer { id: galleryRestart; interval: 2000; onTriggered: { galleryWorker.running = true; if (root.panel === "wallpapers") wallpaperScan.running = true } }
    property var wallpapers: []
    property string currentWallpaper: ""
    property string wallpaperError: ""
    onPanelChanged: {
        if (panel) { closeDelay.stop(); displayedPanel = panel } else closeDelay.restart()
        if (panel !== "wallpapers") galleryWorker.write("[]\n")
        if (panel !== "bluetooth" && bluetooth.discovering) wifiCommand({action: "bt-scan", enabled: false})
        if (panel === "launcher") searchApplications("")
        wifiCommand({action: "panel", visible: panel === "wifi"})
        if (status.running) status.write(JSON.stringify({detailed: panel === "battery"}) + "\n")
        if (panel === "wallpapers" && !wallpaperScan.running) { wallpaperError = ""; wallpaperScan.running = true }
        if (panel === "wifi" && wifi.powered && !wifi.scanning && !wifi.busy) wifiCommand({action: "scan"})
        if (panel !== "bluetooth" && bluetoothPrompt.name) wifiCommand({action: "bluetooth-reply", accepted: false})
        if (panel !== "wifi" && wifiPrompt) wifiCommand({action: "cancel"})
    }
    Timer { id: closeDelay; interval: 260; onTriggered: root.displayedPanel = "" }
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
    property var resources: ({cpu: null, ramUsed: 0, ramTotal: 0})
    Process {
        id: resourceMonitor
        command: ["python", "/home/chuh/.config/rice/resources.py"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    const value = JSON.parse(data)
                    if (value.cpu !== root.resources.cpu || value.ramUsed.toFixed(1) !== root.resources.ramUsed.toFixed(1) || value.ramTotal !== root.resources.ramTotal) root.resources = value
                }
                catch(e) { console.warn("Could not read resource usage:", e) }
            }
        }
    }
    property var stats: ({battery: 0, present: false, charging: false, network: "Offline", connected: false, brightness: 50})
    property var sink: Pipewire.defaultAudioSink
    readonly property var adapter: ({enabled: bluetooth.powered, name: bluetooth.name, discovering: bluetooth.discovering})
    property int volume: sink && sink.audio ? Math.round(sink.audio.volume * 100) : 0
    property bool muted: sink && sink.audio ? sink.audio.muted : true
    property int wantedBrightness: 50
    function setBrightness(value) { wantedBrightness = Math.round(value); if (!brightnessUpdate.running) brightnessUpdate.start() }
    Timer { id: brightnessUpdate; interval: 80; onTriggered: Quickshell.execDetached(["brightnessctl", "set", root.wantedBrightness + "%"]) }
    function run(action) { Quickshell.execDetached(["/home/chuh/.local/bin/chuhshell", action]) }
    function toggle(which, preserveScreen = false) { if (!preserveScreen) { panelScreen = Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) || Quickshell.screens[0]; moduleX = 0 }; panel = panel === which ? "" : which }
    PwObjectTracker { objects: [root.sink] }
    SystemClock { id: clock; precision: SystemClock.Minutes }
    Process {
        id: status
        command: ["python", "/home/chuh/.config/rice/status.py", "watch"]
        running: true
        stdinEnabled: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    const value = JSON.parse(data)
                    if (JSON.stringify(value) !== JSON.stringify(root.stats)) root.stats = value
                } catch(e) { console.warn("Could not read system status:", e) }
            }
        }
    }
    IpcHandler {
        target: "shell"
        function launcher(): void { root.toggle("launcher") }
        function menu(): void { root.toggle("control") }
        function calendar(): void { root.toggle("calendar") }
        function awake(): void { root.keepAwake = !root.keepAwake }
        function inspect(): string { return JSON.stringify({panel: root.panel, applications: root.applications.length, hidden: root.hiddenApplications, wifi: root.wifi.state, bluetooth: root.bluetooth.powered, wallpapers: root.wallpapers.length, previews: Object.keys(root.previews).length, keepAwake: root.keepAwake, screen: root.panelScreen ? root.panelScreen.name : ""}) }
        function wallpapers(): void { root.toggle("wallpapers") }
        function wifi(): void { root.toggle("wifi") }
        function bluetooth(): void { root.toggle("bluetooth") }
        function audio(): void { root.toggle("audio") }
        function battery(): void { root.toggle("battery") }
        function tray(itemId: string): void {
            const item = SystemTray.items.values.find(value => value.id === itemId)
            if (!item) return
            root.trayTarget = item
            root.trayOnlyMenu = item.onlyMenu
            root.trayExpanded = false
            root.trayX = 0
            root.toggle("tray")
        }
        function close(): void { root.panel = "" }
    }
    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: bar
            IdleInhibitor { window: bar; enabled: root.keepAwake }
            required property var modelData
            screen: modelData
            anchors { top: true; left: true; right: true }
            margins { top: Math.round(6 * Theme.uiScale); left: Math.round(10 * Theme.uiScale); right: Math.round(10 * Theme.uiScale) }
            implicitHeight: Math.ceil(28 * Theme.uiScale)
            exclusiveZone: 42 - Math.round(6 * Theme.uiScale)
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
                    Chip { compact: true; iconSize: 13; label: "󰣇"; shortcut: "Super"; ink: Theme.green; onClicked: root.openAt("launcher", bar) }
                    Rectangle { width: 1; height: 12; color: Theme.line; Layout.leftMargin: 4; Layout.rightMargin: 6 }
                    Repeater {
                        model: [1, 2, 3, 4, 5].concat(Hyprland.workspaces.values.filter(w => w.id > 5).map(w => w.id).sort((a,b) => a-b))
                        Chip { compact: true; iconSize: 13;
                            required property int modelData
                            property int workspaceId: modelData
                            property bool active: Hyprland.focusedMonitor && Hyprland.focusedMonitor.activeWorkspace && Hyprland.focusedMonitor.activeWorkspace.id === workspaceId
                            fontSize: active ? 11 : 13
                            property bool occupied: Hyprland.workspaces.values.some(w => w.id === workspaceId)
                            shortcut: "Super + " + workspaceId
                            label: active ? "0" + (workspaceId) : occupied ? "●" : "○"
                            implicitWidth: active ? 32 : 23
                            selected: active
                            ink: active ? Theme.green : occupied ? Theme.text : Theme.muted
                            Behavior on implicitWidth { SpringAnimation { spring: 5.8; damping: 0.3; mass: 1 } }
                            Rectangle { anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter } width: parent.active ? 14 / Theme.uiScale : 0; height: 2 / Theme.uiScale; radius: 1; color: Theme.green }
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
                Chip { compact: true; iconSize: 13;
                    anchors.centerIn: parent
                    label: clock.date.toLocaleString(Qt.locale("en_US"), "ddd, d MMM  ·  HH:mm")
                    ink: Theme.text
                    onClicked: root.openAt("calendar", bar)
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
                                width: 17; height: 17
                                source: modelData.icon
                                visible: source.toString() !== "" && status !== Image.Error
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: !trayIcon.visible
                                text: "󰀻"
                                color: Theme.muted
                                font.family: Theme.icons
                                font.pixelSize: 16
                            }
                            MouseArea {
                                anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: event => {
                                    if (event.button === Qt.RightButton) {
                                        root.panelScreen = bar.screen
                                        root.trayOnlyMenu = false
                                        root.trayExpanded = false
                                        root.trayTarget = modelData
                                        root.trayBar = bar
                                        root.trayX = mapToItem(null, 0, 0).x
                                        root.panel = "tray"
                                    } else if (modelData.onlyMenu) { root.panelScreen = bar.screen; root.trayOnlyMenu = true; root.trayTarget = modelData; root.trayX = mapToItem(null, 0, 0).x; root.panel = "tray" }
                                    else modelData.activate()
                                }
                                onWheel: event => modelData.scroll(event.angleDelta.y, false)
                            }
                        }
                    }
                    Text {
                        textFormat: Text.RichText
                        text: '<span style="font-size: 12px">󰻠</span> ' + (root.resources.cpu === null ? "…" : root.resources.cpu + "%")
                        color: Theme.text
                        font.family: Theme.icons
                        font.pixelSize: 10
                        Layout.preferredWidth: 53
                        Layout.leftMargin: 6
                    }
                    Text {
                        textFormat: Text.RichText
                        text: '<span style="font-size: 12px">󰍛</span> ' + (root.resources.ramTotal > 0 ? root.resources.ramUsed.toFixed(1) + " GiB" : "…")
                        color: Theme.text
                        font.family: Theme.icons
                        font.pixelSize: 10
                        Layout.preferredWidth: 78
                    }
                    Rectangle {
                        implicitWidth: 49
                        implicitHeight: 22
                        radius: 6
                        color: keyboardHover.containsMouse ? Theme.elevated : "transparent"
                        Behavior on color { ColorAnimation { duration: 140 } }
                        Row {
                            anchors.centerIn: parent
                            spacing: 5
                            Image {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 16
                                height: 12
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
                    Chip { id: networkChip; compact: true; iconSize: 13; label: root.networkConnected ? "󰤨" : "󰤭"; ink: root.networkConnected ? Theme.green : Theme.muted; onClicked: root.openModule("wifi", networkChip, bar) }
                    Chip { id: bluetoothChip; compact: true; iconSize: 13; label: "󰂯"; ink: root.adapter && root.adapter.enabled ? Theme.green : Theme.muted; onClicked: root.openModule("bluetooth", bluetoothChip, bar) }
                    Chip { id: audioChip; compact: true; iconSize: 13; label: root.muted ? "󰖁" : "󰕾"; shortcut: "XF86AudioRaiseVolume / XF86AudioLowerVolume / XF86AudioMute"; onClicked: root.openModule("audio", audioChip, bar); onRightClicked: root.run("volume-mute"); onScrolled: delta => root.run(delta > 0 ? "volume-up" : "volume-down") }
                    Chip { id: batteryChip; compact: true; iconSize: 13; visible: root.stats.present; label: (root.stats.charging ? "󰂄 " : "󰁹 ") + root.stats.battery + "%"; ink: root.stats.battery < 20 ? Theme.red : Theme.text; onClicked: root.openModule("battery", batteryChip, bar) }
                    Rectangle { width: 1; height: 12; color: Theme.line; Layout.leftMargin: 5; Layout.rightMargin: 5 }
                    Chip { compact: true; iconSize: 13; label: "󰂚"; shortcut: "Super + N"; ink: Theme.yellow; onClicked: root.run("notifications") }
                    Chip { compact: true; iconSize: 13; label: "󰒓"; shortcut: "Super + Space"; ink: Theme.green; onClicked: root.openAt("control", bar) }
                }
            }
        }
    }
    PanelWindow {
        id: popup
        visible: root.displayedPanel !== ""
        screen: root.panelScreen
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "material-overlay"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.panel ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        FocusScope {
            id: popupKeys
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: event => { root.panel = ""; event.accepted = true }
            Connections {
                target: root
                function onPanelChanged() {
                    if (root.panel && root.panel !== "launcher" && root.panel !== "wallpapers" && root.panel !== "tray" && !root.wifiPrompt && !root.bluetoothPrompt.name)
                        Qt.callLater(() => popupKeys.forceActiveFocus())
                }
            }
        Rectangle { anchors.fill: parent; opacity: root.panel ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 200 } } color: root.modulePanel ? "#181d2021" : "#601d2021"; MouseArea { anchors.fill: parent; onClicked: root.panel = "" } }
        Rectangle {
            id: card
            property real reveal: root.panel ? 1 : 0
            Behavior on reveal { SpringAnimation { spring: 4.2; damping: 0.27; mass: 1; epsilon: 0.002 } }
            scale: Theme.uiScale
            transformOrigin: Item.TopLeft
            width: (root.modulePanel ? 468 : root.displayedPanel === "tray" ? 293 : root.displayedPanel === "wallpapers" ? Math.min(1000, parent.width - 40) : root.displayedPanel === "launcher" ? 720 : root.displayedPanel === "control" ? 520 : 468) / Theme.uiScale
            height: Math.min(parent.height - 70, root.modulePanel ? (root.displayedPanel === "battery" ? 460 : root.displayedPanel === "audio" ? 492 : root.displayedPanel === "wifi" && root.wifiPrompt ? 653 : 512) : root.displayedPanel === "tray" ? (root.trayOnlyMenu || root.trayExpanded ? 460 : 220) : root.displayedPanel === "wallpapers" ? 700 : root.displayedPanel === "launcher" ? 650 : root.displayedPanel === "calendar" ? 512 : 704) / Theme.uiScale
            x: root.modulePanel || root.displayedPanel === "tray" ? Math.min(Math.max(14, (root.displayedPanel === "tray" ? root.trayX : root.moduleX) ? (root.displayedPanel === "tray" ? root.trayX : root.moduleX) - width * scale / 2 : parent.width - width * scale - 14), parent.width - width * scale - 14) : root.displayedPanel === "launcher" || root.displayedPanel === "wallpapers" ? (parent.width - width * scale) / 2 : parent.width - width * scale - 14
            y: (root.displayedPanel === "launcher" || root.displayedPanel === "wallpapers" ? Math.min(130, (parent.height - height * scale) / 2) : 58) + (root.modulePanel ? -14 : 24) * (1 - reveal)
            opacity: Math.max(0, Math.min(1, reveal * 2))
            transform: [Scale { origin.x: card.width / 2; xScale: 0.985 + 0.015 * card.reveal; yScale: 0.90 + 0.10 * card.reveal }, Rotation { origin.x: card.width - 30; angle: (root.modulePanel ? 2 : -2.6) * (1 - card.reveal) }]
            color: Theme.bg; radius: root.modulePanel ? 14 : 22; border.color: Theme.line
            MouseArea { anchors.fill: parent }
            Loader { active: root.displayedPanel !== ""; anchors.fill: parent; anchors.margins: root.modulePanel ? 24 / Theme.uiScale : root.displayedPanel === "launcher" ? 32 / Theme.uiScale : 28 / Theme.uiScale; opacity: root.panel ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 170 } } sourceComponent: root.displayedPanel === "wifi" ? wifiView : root.displayedPanel === "bluetooth" ? bluetoothView : root.displayedPanel === "audio" ? audioView : root.displayedPanel === "battery" ? batteryView : root.displayedPanel === "tray" ? trayMenu : root.displayedPanel === "wallpapers" ? wallpaperPicker : root.displayedPanel === "launcher" ? launcher : root.displayedPanel === "calendar" ? calendar : control }
        }
        
        }

    }
    Component { id: wifiView; WifiPanel { shell: root } }
    Component { id: bluetoothView; BluetoothPanel { shell: root } }
    Component { id: audioView; AudioPanel { shell: root } }
    Component { id: batteryView; BatteryPanel { shell: root } }
    Component { id: trayMenu; TrayPanel { shell: root } }
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
            Text { text: "workspace / launch"; color: Theme.green; font.family: Theme.font; font.pixelSize: 9; font.letterSpacing: 1 }
            RowLayout {
                Layout.fillWidth: true
                Text { text: "applications"; color: Theme.text; font.family: Theme.font; font.pixelSize: 26; Layout.fillWidth: true }
                Chip { label: "×"; onClicked: root.panel = "" }
            }
            Rectangle {
                Layout.fillWidth: true; height: 52; radius: 12; color: Theme.surface; border.color: search.activeFocus ? Theme.green : Theme.line
                TextInput {
                    id: search
                    anchors.fill: parent; anchors.margins: 16
                    color: Theme.text; font.family: Theme.font; font.pixelSize: 16
                    focus: true; clip: true; selectByMouse: true
                    Component.onCompleted: forceActiveFocus()
                    Text { visible: !search.text; text: "find an application…"; color: Theme.muted; font: search.font }
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
                    onTextChanged: { apps.currentIndex = 0; root.searchApplications(text) }
                }
            }
            ListView {
                id: apps
                Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 5
                model: root.applications.filter(a => launcherView.showHidden || !root.hiddenApplications.includes(a.id))
                currentIndex: 0
                onModelChanged: Qt.callLater(() => { if (count > 0 && currentIndex < 0) currentIndex = 0 })
                delegate: Rectangle {
                    id: entry
                    required property var modelData
                    required property int index
                    readonly property bool hidden: root.hiddenApplications.includes(modelData.id)
                    function launch() { Quickshell.execDetached(["python", "/home/chuh/.config/quickshell/material/helpers/desktop.py", "launch", modelData.id]) }
                    width: apps.width; height: 56;
                    opacity: 0
                    x: 12
                    ParallelAnimation { running: true; NumberAnimation { target: entry; property: "opacity"; to: 1; duration: 220 } NumberAnimation { target: entry; property: "x"; to: 0; duration: 280; easing.type: Easing.OutCubic } } radius: 11
                    color: ListView.isCurrentItem ? Theme.elevated : hover.containsMouse ? Theme.surface : "transparent"
                    RowLayout {
                        anchors.fill: parent; anchors.margins: 10; spacing: 13
                        opacity: entry.hidden ? 0.55 : 1
                        Rectangle {
                            Layout.preferredWidth: 28; Layout.preferredHeight: 28; radius: 7; color: Theme.elevated
                            property bool hasIcon: modelData.icon.startsWith("/") || Quickshell.hasThemeIcon(modelData.icon)
                            Image { anchors.fill: parent; source: parent.hasIcon ? modelData.icon.startsWith("/") ? "file://" + modelData.icon : Quickshell.iconPath(modelData.icon) : "" }
                            Text { anchors.centerIn: parent; visible: !parent.hasIcon; text: modelData.name.charAt(0); color: Theme.green; font.family: Theme.font; font.pixelSize: 16 }
                        }
                        ColumnLayout {
                            spacing: 2
                            Text { text: modelData.name; color: Theme.text; font.family: Theme.font; font.pixelSize: 14 }
                            Text { text: modelData.generic || modelData.comment || "Application"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 10; elide: Text.ElideRight; Layout.maximumWidth: 390 }
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
    Component { id: control; ControlPanel { shell: root; date: clock.date } }
    Component {
        id: wallpaperPicker
        ColumnLayout {
            spacing: 14
            RowLayout {
                Layout.fillWidth: true
                ColumnLayout {
                    spacing: 6
                    Text { text: "wallpapers"; font.family: Theme.font; font.pixelSize: 26; color: Theme.text }
                    Text { text: root.wallpapers.length + " images · Pictures/Wallpapers"; font.family: Theme.font; font.pixelSize: 11; color: Theme.muted }
                }
                Item { Layout.fillWidth: true }
                Chip { label: "refresh"; onClicked: if (!wallpaperScan.running) wallpaperScan.running = true }
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
                Component.onCompleted: { forceActiveFocus(); requestPreviews() }
                function requestPreviews() {
                    if (root.panel !== "wallpapers") return
                    const first = Math.max(0, Math.floor(contentY / cellHeight) * 2)
                    galleryWorker.write(JSON.stringify(root.wallpapers.slice(first, first + 8)) + "\n")
                }
                onContentYChanged: requestPreviews()
                onModelChanged: Qt.callLater(requestPreviews)
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
                        source: root.previews[modelData.path + "\n" + modelData.revision] ? "file://" + root.previews[modelData.path + "\n" + modelData.revision] : ""
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
                        Text { visible: tile.selected; text: "✓ applied"; font.family: Theme.font; font.pixelSize: 10; color: Theme.green }
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
    Component { id: calendar; CalendarPanel { date: clock.date } }
}
