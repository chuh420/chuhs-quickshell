import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import Quickshell.Services.Pipewire
import Quickshell.Services.Notifications
import Quickshell.Services.UPower

ShellRoot {
    id: root
    signal notificationArrived()
    signal popupRefresh(int nid)
    property string panel: ""
    property string displayedPanel: ""
    property string contentPanel: ""
    property string pendingContent: ""
    property real panelAnchor: 0
    property var panelScreen: Quickshell.screens[0]
    property bool keepAwake: false
    readonly property var anchoredPanels: ["wifi", "bluetooth", "audio", "battery", "tray", "calendar", "notifications"]
    readonly property var centeredPanels: ["launcher", "wallpapers", "clipboard", "power"]
    readonly property bool modulePanel: ["wifi", "bluetooth", "audio", "battery", "calendar", "notifications"].includes(contentPanel)
    readonly property var focusedScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) || Quickshell.screens[0]
    property SystemClock clock: SystemClock { precision: SystemClock.Minutes }

    function openAt(which, bar) { panelScreen = bar.screen; panelAnchor = 0; toggle(which, true) }
    function openModule(which, x, bar) { panelScreen = bar.screen; panelAnchor = x; toggle(which, true) }
    function openTray(item, onlyMenu, x, bar) {
        panelScreen = bar.screen
        panelAnchor = x
        trayOnlyMenu = onlyMenu
        trayExpanded = false
        trayTarget = item
        panel = "tray"
    }
    function toggle(which, preserveScreen = false) {
        if (!preserveScreen) { panelScreen = focusedScreen; panelAnchor = 0 }
        panel = panel === which ? "" : which
    }
    function run(action) { Quickshell.execDetached([Paths.chuhshell, action]) }

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
    function launchApplication(id) { Quickshell.execDetached(["python", Paths.helper("desktop.py"), "launch", id]) }
    Process {
        id: desktopWorker
        command: ["python", Paths.helper("desktop.py"), "watch"]
        running: true
        stdinEnabled: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    const value = JSON.parse(data)
                    if (value.error) { console.warn(value.error); return }
                    if (value.generation !== root.applicationGeneration || value.query !== root.applicationQuery) return
                    if (JSON.stringify(value.apps) !== JSON.stringify(root.applications)) root.applications = value.apps
                    if (JSON.stringify(value.hidden) !== JSON.stringify(root.hiddenApplications)) root.hiddenApplications = value.hidden
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
    function wifiCommand(data) { wifiWorker.write(JSON.stringify(data) + "\n") }
    Process {
        id: wifiWorker
        command: ["python", Paths.helper("wifi.py")]
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

    property var keyboardLayout: ({label: "…", name: "", device: ""})
    property bool keyboardInitialized: false
    Process {
        id: keyboardStatus
        command: ["python", Paths.riceScript("keyboard.py"), "status"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const next = JSON.parse(text)
                    const changed = root.keyboardInitialized && next.name !== root.keyboardLayout.name
                    root.keyboardLayout = next
                    root.keyboardInitialized = true
                    if (changed) root.showOsd("keyboard")
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
            if (event.name === "configreloaded") root.hotkeysPaused = false
        }
    }

    property var previews: ({})
    function requestPreviews(items) { galleryWorker.write(JSON.stringify(items) + "\n") }
    Process {
        id: galleryWorker
        command: ["python", Paths.helper("gallery.py"), "watch"]
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
    Timer { id: galleryRestart; interval: 2000; onTriggered: { galleryWorker.running = true; if (root.panel === "wallpapers") root.refreshWallpapers() } }

    property var wallpapers: []
    property string currentWallpaper: ""
    property string wallpaperError: ""
    property bool wallpaperBusy: wallpaperApply.running
    property var wallpaperOrigin: null
    function refreshWallpapers() { if (!wallpaperScan.running) { wallpaperError = ""; wallpaperScan.running = true } }
    function applyWallpaper(path, origin) {
        if (wallpaperApply.running) return
        wallpaperError = ""
        wallpaperOrigin = origin || null
        wallpaperApply.command = ["python", Paths.riceScript("wallpapers.py"), "apply", path]
        wallpaperApply.running = true
    }
    Process {
        id: wallpaperScan
        command: ["python", Paths.riceScript("wallpapers.py"), "list"]
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
    FileView {
        path: Paths.wallpaperState
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { const path = JSON.parse(text()).path; if (path) root.currentWallpaper = path } catch(e) {} }
        onLoadFailed: if (!root.currentWallpaper) root.currentWallpaper = Paths.riceScript("wallpaper.png")
    }

    property var resources: ({cpu: null, ramUsed: 0, ramTotal: 0})
    Process {
        id: resourceMonitor
        command: ["python", Paths.riceScript("resources.py")]
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

    property var stats: ({network: "Offline", connected: false, brightness: 50})
    Process {
        id: status
        command: ["python", Paths.riceScript("status.py"), "watch"]
        running: true
        stdinEnabled: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    const value = JSON.parse(data)
                    if (JSON.stringify(value) !== JSON.stringify(root.stats)) root.stats = value
                    if (root.wantedBrightness < 0 && typeof value.brightness === "number") root.brightness = value.brightness
                } catch(e) { console.warn("Could not read system status:", e) }
            }
        }
    }

    property int brightness: 50
    property int wantedBrightness: -1
    function setBrightness(value) {
        wantedBrightness = Math.max(5, Math.min(100, Math.round(value)))
        brightness = wantedBrightness
        if (!brightnessThrottle.running) brightnessThrottle.start()
    }
    function stepBrightness(step) { setBrightness(brightness + step); showOsd("brightness") }
    Timer {
        id: brightnessThrottle
        interval: 50
        onTriggered: {
            if (brightnessProcess.running) { restart(); return }
            brightnessProcess.command = ["brightnessctl", "-m", "set", root.wantedBrightness + "%"]
            brightnessProcess.running = true
        }
    }
    Process {
        id: brightnessProcess
        onExited: {
            if (brightnessThrottle.running) return
            root.wantedBrightness = -1
            if (status.running) status.write("{}\n")
        }
    }

    property var sink: Pipewire.defaultAudioSink
    property var source: Pipewire.defaultAudioSource
    PwObjectTracker { objects: [root.sink, root.source] }
    readonly property int volume: sink && sink.audio ? Math.round(sink.audio.volume * 100) : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : true
    readonly property bool micMuted: source && source.audio ? source.audio.muted : true
    function changeVolume(step, osd = true) {
        if (!sink || !sink.audio) return
        if (step > 0 && sink.audio.muted) sink.audio.muted = false
        sink.audio.volume = Math.max(0, Math.min(1, Math.round((sink.audio.volume + step) * 100) / 100))
        if (osd) showOsd("volume")
    }
    function toggleMute(osd = true) {
        if (!sink || !sink.audio) return
        sink.audio.muted = !sink.audio.muted
        if (osd) showOsd("volume")
    }
    function toggleMic() {
        if (!source || !source.audio) return
        source.audio.muted = !source.audio.muted
        showOsd("mic")
    }

    readonly property var batteryDevice: UPower.devices.values.find(device => device.isLaptopBattery) || null
    readonly property bool batteryPresent: Boolean(batteryDevice && batteryDevice.isPresent)
    readonly property int batteryLevel: batteryDevice ? Math.round(batteryDevice.percentage * 100) : 0
    readonly property bool batteryPlugged: batteryPresent && !UPower.onBattery

    property string osdKind: ""
    property string osdText: ""
    property bool hotkeysPaused: false
    function showOsdText(kind, text) {
        if (kind === "hotkeys") hotkeysPaused = text === "paused"
        osdText = text
        osdKind = kind
        osdSerial++
    }
    property int osdSerial: 0
    function showOsd(kind) {
        if (kind !== "keyboard" && ["control", "audio", "battery"].includes(panel)) return
        osdKind = kind
        osdSerial++
    }

    property bool dnd: false
    property var seenNotifications: []
    property var notificationTimes: ({})
    readonly property var historyNotifications: notificationServer.trackedNotifications.values.filter(n => !n.transient)
    readonly property int unreadNotifications: historyNotifications.filter(n => !seenNotifications.includes(n.id)).length
    function findNotification(id) { return notificationServer.trackedNotifications.values.find(n => n.id === id) || null }
    function notificationTag(n) { return n && n.hints ? (n.hints["x-canonical-private-synchronous"] || n.hints["synchronous"] || "") : "" }
    function markNotificationsSeen() { seenNotifications = historyNotifications.map(n => n.id) }
    function popupIndex(id) {
        for (let i = 0; i < popupModel.count; i++) if (popupModel.get(i).nid === id) return i
        return -1
    }
    function showPopup(n) {
        if (panel === "notifications" || (dnd && n.urgency !== NotificationUrgency.Critical)) {
            if (n.transient) n.expire()
            return
        }
        if (popupIndex(n.id) >= 0) { popupRefresh(n.id); return }
        popupModel.insert(0, {nid: n.id})
        while (popupModel.count > 4) dropPopup(popupModel.get(popupModel.count - 1).nid)
    }
    function dropPopup(id) {
        const index = popupIndex(id)
        if (index >= 0) popupModel.remove(index)
        const n = findNotification(id)
        if (n && n.transient) n.expire()
    }
    function clearNotifications() { historyNotifications.slice().forEach(n => n.dismiss()) }
    ListModel { id: popupModel }
    property alias popups: popupModel
    NotificationServer {
        id: notificationServer
        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        actionsSupported: true
        imageSupported: true
        onNotification: n => {
            n.tracked = true
            root.notificationTimes[n.id] = Date.now()
            const tag = root.notificationTag(n)
            if (tag) notificationServer.trackedNotifications.values.filter(other => other !== n && root.notificationTag(other) === tag).forEach(other => {
                const index = root.popupIndex(other.id)
                if (index >= 0) popupModel.remove(index)
                other.expire()
            })
            if (!n.transient) root.notificationArrived()
            root.showPopup(n)
        }
    }
    Instantiator {
        model: notificationServer.trackedNotifications
        delegate: Connections {
            required property var modelData
            target: modelData
            function onSummaryChanged() { root.notificationTimes[modelData.id] = Date.now(); root.showPopup(modelData) }
            function onBodyChanged() { root.notificationTimes[modelData.id] = Date.now(); root.showPopup(modelData) }
        }
    }

    onPanelChanged: {
        if (panel) {
            closeAnimation.stop()
            const switching = displayedPanel !== ""
            card.morph = switching
            if (!switching) morphArm.restart()
            if (switching && contentPanel !== panel) { pendingContent = panel; contentSwap.restart() }
            else if (!switching) { contentSwap.stop(); content.opacity = 1; contentShift.y = 0; contentPanel = panel }
            displayedPanel = panel
            openAnimation.restart()
        } else {
            openAnimation.stop()
            closeAnimation.restart()
        }
        if (panel !== "wallpapers") galleryWorker.write("[]\n")
        if (panel !== "bluetooth" && bluetooth.discovering) wifiCommand({action: "bt-scan", enabled: false})
        if (panel === "launcher") searchApplications("")
        if (panel === "notifications") markNotificationsSeen()
        if (panel === "notifications") for (let i = popupModel.count - 1; i >= 0; i--) dropPopup(popupModel.get(i).nid)
        wifiCommand({action: "panel", visible: panel === "wifi"})
        if (status.running) status.write(JSON.stringify({detailed: panel === "battery"}) + "\n")
        if (panel === "wallpapers") refreshWallpapers()
        if (panel === "wifi" && wifi.powered && !wifi.scanning && !wifi.busy) wifiCommand({action: "scan"})
        if (panel !== "bluetooth" && bluetoothPrompt.name) wifiCommand({action: "bluetooth-reply", accepted: false})
        if (panel !== "wifi" && wifiPrompt) wifiCommand({action: "cancel"})
    }
    Timer { id: morphArm; interval: 40; onTriggered: if (root.displayedPanel) card.morph = true }
    Component.onCompleted: refreshWallpapers()

    IpcHandler {
        target: "shell"
        function launcher(): void { root.toggle("launcher") }
        function menu(): void { root.toggle("control") }
        function calendar(): void { root.toggle("calendar") }
        function awake(): void { root.keepAwake = !root.keepAwake }
        function wallpapers(): void { root.toggle("wallpapers") }
        function wifi(): void { root.toggle("wifi") }
        function bluetooth(): void { root.toggle("bluetooth") }
        function audio(): void { root.toggle("audio") }
        function battery(): void { root.toggle("battery") }
        function notifications(): void { root.toggle("notifications") }
        function clipboard(): void { root.toggle("clipboard") }
        function power(): void { root.toggle("power") }
        function dnd(): void { root.dnd = !root.dnd }
        function volumeUp(): void { root.changeVolume(0.05) }
        function volumeDown(): void { root.changeVolume(-0.05) }
        function volumeMute(): void { root.toggleMute() }
        function micMute(): void { root.toggleMic() }
        function osd(kind: string, text: string): void { root.showOsdText(kind, text) }
        function brightnessUp(): void { root.stepBrightness(5) }
        function brightnessDown(): void { root.stepBrightness(-5) }
        function tray(itemId: string): void {
            const item = SystemTray.items.values.find(value => value.id === itemId)
            if (!item) return
            root.trayOnlyMenu = item.onlyMenu
            root.trayExpanded = false
            root.trayTarget = item
            root.toggle("tray")
        }
        function close(): void { root.panel = "" }
        function inspect(): string {
            return JSON.stringify({panel: root.panel, applications: root.applications.length, hidden: root.hiddenApplications, wifi: root.wifi.state, bluetooth: root.bluetooth.powered, wallpapers: root.wallpapers.length, wallpaper: root.currentWallpaper, previews: Object.keys(root.previews).length, keepAwake: root.keepAwake, screen: root.panelScreen ? root.panelScreen.name : "", battery: {present: root.batteryPresent, raw: root.batteryDevice ? root.batteryDevice.percentage : null, level: root.batteryLevel, plugged: root.batteryPlugged}, brightness: root.brightness, notifications: notificationServer.trackedNotifications.values.map(n => ({id: n.id, app: n.appName, summary: n.summary, transient: n.transient, timeout: n.expireTimeout, urgency: n.urgency})), popups: root.popups.count, dnd: root.dnd})
        }
    }

    Variants {
        model: Quickshell.screens
        Wallpaper { shell: root }
    }
    Variants {
        model: Quickshell.screens
        Bar { shell: root }
    }
    NotificationPopups { shell: root }
    Osd { shell: root }

    function panelWidth(p, available) {
        return p === "tray" ? 293 : p === "wallpapers" ? Math.min(1000, available - 40) : p === "launcher" || p === "clipboard" ? 720 : p === "control" ? 520 : p === "power" ? 640 : 468
    }
    function panelHeight(p, available) {
        const value = p === "battery" ? 460 : p === "audio" ? 492 : p === "wifi" ? (wifiPrompt ? 653 : 512) : p === "bluetooth" ? 512 : p === "tray" ? (trayOnlyMenu || trayExpanded ? 460 : 220) : p === "wallpapers" ? 700 : p === "launcher" || p === "clipboard" ? 650 : p === "calendar" ? 500 : p === "notifications" ? 640 : p === "power" ? 290 : 704
        return Math.min(available - 70, value)
    }
    function panelX(p, w, available) {
        if (centeredPanels.includes(p)) return (available - w) / 2
        if (anchoredPanels.includes(p) && panelAnchor) return Math.min(Math.max(14, panelAnchor - w / 2), available - w - 14)
        return available - w - 14
    }
    function panelY(p, h, available) {
        if (p === "power") return (available - h) / 2 - 20
        if (centeredPanels.includes(p)) return Math.min(130, (available - h) / 2)
        return 58
    }
    function componentFor(p) {
        switch (p) {
        case "wifi": return wifiView
        case "bluetooth": return bluetoothView
        case "audio": return audioView
        case "battery": return batteryView
        case "tray": return trayView
        case "wallpapers": return wallpaperView
        case "launcher": return launcherView
        case "calendar": return calendarView
        case "notifications": return notificationsView
        case "clipboard": return clipboardView
        case "power": return powerView
        default: return controlView
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
                function onContentPanelChanged() {
                    if (root.contentPanel && !["launcher", "wallpapers", "tray", "clipboard", "power", "calendar"].includes(root.contentPanel) && !root.wifiPrompt && !root.bluetoothPrompt.name)
                        Qt.callLater(() => popupKeys.forceActiveFocus())
                }
            }
            Rectangle {
                anchors.fill: parent
                opacity: Math.max(0, Math.min(1, card.reveal))
                color: root.anchoredPanels.includes(root.displayedPanel) ? "#181d2021" : "#601d2021"
                Behavior on color { ColorAnimation { duration: Theme.normal } }
                MouseArea { anchors.fill: parent; onClicked: root.panel = "" }
            }
            Rectangle {
                id: card
                property real reveal: 0
                property bool morph: false
                readonly property string kind: root.displayedPanel
                readonly property bool anchored: root.anchoredPanels.includes(kind) && root.panelAnchor > 0
                readonly property bool centered: root.centeredPanels.includes(kind)
                readonly property real visualWidth: root.panelWidth(kind, popup.width)
                readonly property real visualHeight: root.panelHeight(kind, popup.height)
                scale: Theme.uiScale
                transformOrigin: Item.TopLeft
                width: visualWidth / Theme.uiScale
                height: visualHeight / Theme.uiScale
                x: root.panelX(kind, visualWidth, popup.width)
                y: root.panelY(kind, visualHeight, popup.height)
                radius: root.anchoredPanels.includes(kind) ? 14 : 22
                color: Theme.bg
                border.color: Theme.line
                opacity: Math.max(0, Math.min(1, reveal * 2))
                Behavior on x { enabled: card.morph; NumberAnimation { duration: Theme.slow; easing.type: Easing.OutQuint } }
                Behavior on y { enabled: card.morph; NumberAnimation { duration: Theme.slow; easing.type: Easing.OutQuint } }
                Behavior on width { enabled: card.morph; NumberAnimation { duration: Theme.slow; easing.type: Easing.OutQuint } }
                Behavior on height { enabled: card.morph; NumberAnimation { duration: Theme.slow; easing.type: Easing.OutQuint } }
                Behavior on radius { enabled: card.morph; NumberAnimation { duration: Theme.slow } }
                transform: [
                    Translate { y: (card.anchored ? -10 : 24) * (1 - card.reveal) },
                    Scale {
                        origin.x: card.anchored ? Math.max(0, Math.min(card.width, (root.panelAnchor - card.x) / Theme.uiScale)) : card.centered ? card.width / 2 : card.width
                        origin.y: card.kind === "power" ? card.height / 2 : 0
                        xScale: card.anchored ? 0.86 + 0.14 * card.reveal : card.centered ? 0.95 + 0.05 * card.reveal : 0.985 + 0.015 * card.reveal
                        yScale: card.anchored ? 0.8 + 0.2 * card.reveal : card.centered ? 0.95 + 0.05 * card.reveal : 0.9 + 0.1 * card.reveal
                    },
                    Rotation { origin.x: card.width - 30; angle: card.anchored ? 0 : -1.6 * (1 - card.reveal) }
                ]
                SpringAnimation { id: openAnimation; target: card; property: "reveal"; to: 1; spring: 4.2; damping: 0.3; epsilon: 0.002 }
                NumberAnimation {
                    id: closeAnimation
                    target: card
                    property: "reveal"
                    to: 0
                    duration: 170
                    easing.type: Easing.InCubic
                    onFinished: { card.morph = false; root.displayedPanel = ""; root.contentPanel = "" }
                }
                MouseArea { anchors.fill: parent }
                Item {
                    id: content
                    anchors.fill: parent
                    anchors.margins: (root.modulePanel ? 24 : root.contentPanel === "launcher" || root.contentPanel === "clipboard" ? 32 : 28) / Theme.uiScale
                    transform: Translate { id: contentShift }
                    Loader {
                        anchors.fill: parent
                        active: root.contentPanel !== ""
                        sourceComponent: root.componentFor(root.contentPanel)
                    }
                }
                SequentialAnimation {
                    id: contentSwap
                    NumberAnimation { target: content; property: "opacity"; to: 0; duration: 90; easing.type: Easing.InQuad }
                    ScriptAction { script: root.contentPanel = root.pendingContent }
                    ParallelAnimation {
                        NumberAnimation { target: content; property: "opacity"; to: 1; duration: Theme.normal; easing.type: Easing.OutCubic }
                        NumberAnimation { target: contentShift; property: "y"; from: 8; to: 0; duration: Theme.slow; easing.type: Easing.OutCubic }
                    }
                }
            }
        }
    }
    Component { id: wifiView; WifiPanel { shell: root } }
    Component { id: bluetoothView; BluetoothPanel { shell: root } }
    Component { id: audioView; AudioPanel { shell: root } }
    Component { id: batteryView; BatteryPanel { shell: root } }
    Component { id: trayView; TrayPanel { shell: root } }
    Component { id: launcherView; Launcher { shell: root } }
    Component { id: wallpaperView; WallpaperPicker { shell: root } }
    Component { id: controlView; ControlPanel { shell: root; date: root.clock.date } }
    Component { id: calendarView; CalendarPanel { date: root.clock.date } }
    Component { id: notificationsView; NotificationsPanel { shell: root } }
    Component { id: clipboardView; ClipboardPanel { shell: root } }
    Component { id: powerView; PowerPanel { shell: root } }
}
