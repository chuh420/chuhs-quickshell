import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
ColumnLayout {
    id: view
    required property var shell
    property var mic: Pipewire.defaultAudioSource
    spacing: 12
    PwObjectTracker { objects: [view.mic].concat(Pipewire.nodes.values.filter(n => n.audio && !n.isStream)) }
    RowLayout {
        PanelLabel { text: "sound"; font.pixelSize: 18; Layout.fillWidth: true }
        Chip { label: shell.muted ? "󰖁" : "󰕾"; shortcut: "XF86AudioMute"; ink: shell.muted ? Theme.red : Theme.green; onClicked: if (shell.sink && shell.sink.audio) shell.sink.audio.muted = !shell.muted }
    }
    RowLayout {
        PanelLabel { text: "output"; color: Theme.muted; Layout.fillWidth: true }
        PanelLabel { text: shell.volume + "%" }
    }
    MaterialSlider { Layout.fillWidth: true; value: shell.volume; shortcut: "XF86AudioRaiseVolume / XF86AudioLowerVolume"; onMoved: if (shell.sink && shell.sink.audio) shell.sink.audio.volume = value / 100 }
    Repeater {
        model: Pipewire.nodes.values.filter(n => n.audio && n.isSink && !n.isStream)
        delegate: Chip {
            required property var modelData
            Layout.fillWidth: true
            label: (shell.sink === modelData ? "✓  " : "") + (modelData.description || modelData.name)
            ink: shell.sink === modelData ? Theme.green : Theme.text
            onClicked: Quickshell.execDetached(["wpctl", "set-default", String(modelData.id)])
        }
    }
    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.line }
    RowLayout {
        PanelLabel { text: "microphone"; color: Theme.muted; Layout.fillWidth: true }
        Chip { label: view.mic && view.mic.audio && !view.mic.audio.muted ? "on" : "muted"; shortcut: "XF86AudioMicMute"; ink: view.mic && view.mic.audio && view.mic.audio.muted ? Theme.red : Theme.green; onClicked: if (view.mic && view.mic.audio) view.mic.audio.muted = !view.mic.audio.muted }
    }
    MaterialSlider { Layout.fillWidth: true; value: view.mic && view.mic.audio ? view.mic.audio.volume * 100 : 0; onMoved: if (view.mic && view.mic.audio) view.mic.audio.volume = value / 100 }
    Repeater {
        model: Pipewire.nodes.values.filter(n => n.audio && !n.isSink && !n.isStream)
        delegate: Chip {
            required property var modelData
            Layout.fillWidth: true
            label: (view.mic === modelData ? "✓  " : "") + (modelData.description || modelData.name)
            ink: view.mic === modelData ? Theme.green : Theme.text
            onClicked: Quickshell.execDetached(["wpctl", "set-default", String(modelData.id)])
        }
    }
    Item { Layout.fillHeight: true }
    RowLayout {
        Chip { label: "mixer ↗"; onClicked: { shell.panel = ""; shell.run("audio") } }
        Item { Layout.fillWidth: true }
        Chip { label: "󰒓"; onClicked: shell.toggle("control") }
    }
}
