import QtQuick
Item {
    required property date date
    PanelLabel { text: "time / calendar"; font.family: Theme.icons; font.pixelSize: 11 / Theme.uiScale; font.letterSpacing: 1; color: Theme.green }
    PanelLabel { y: 22 / Theme.uiScale; text: Qt.formatDateTime(date, "HH:mm"); font.pixelSize: 52 / Theme.uiScale; font.weight: Font.Light }
    PanelLabel { y: 99 / Theme.uiScale; text: date.toLocaleString(Qt.locale("en_US"), "MMMM yyyy"); color: Theme.green; font.pixelSize: 18 }
    Repeater {
        model: ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]
        PanelLabel {
            required property string modelData
            required property int index
            x: index * (parent.width - 36) / 6
            y: 156 / Theme.uiScale
            width: 36
            text: modelData
            horizontalAlignment: Text.AlignHCenter
            color: Theme.muted
            font.pixelSize: 11
        }
    }
    Repeater {
        model: 42
        Rectangle {
            required property int index
            readonly property int day: index - ((new Date(date.getFullYear(), date.getMonth(), 1).getDay() + 6) % 7) + 1
            readonly property bool valid: day > 0 && day <= new Date(date.getFullYear(), date.getMonth() + 1, 0).getDate()
            x: (index % 7) * (parent.width - 36) / 6
            y: (191.54 + Math.floor(index / 7) * 43.92) / Theme.uiScale
            width: 36
            height: 28
            radius: 8
            color: valid && day === date.getDate() ? Theme.green : "transparent"
            PanelLabel { anchors.centerIn: parent; text: parent.valid ? parent.day : ""; color: parent.day === date.getDate() ? Theme.bg : Theme.text }
        }
    }
}
