import QtQuick
import QtQuick.Layouts
FocusScope {
    id: view
    required property date date
    readonly property int base: 600
    readonly property int offset: months.currentIndex - base
    readonly property date shown: new Date(date.getFullYear(), date.getMonth() + offset, 1)
    focus: true
    Component.onCompleted: forceActiveFocus()
    function shift(step) { months.currentIndex = Math.max(0, Math.min(months.count - 1, months.currentIndex + step)) }
    Keys.onLeftPressed: shift(-1)
    Keys.onRightPressed: shift(1)
    Keys.onUpPressed: shift(-12)
    Keys.onDownPressed: shift(12)
    Keys.onPressed: event => { if (event.key === Qt.Key_Home || event.key === Qt.Key_T) { months.currentIndex = base; event.accepted = true } }
    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        PanelLabel { text: "time / calendar"; font.family: Theme.icons; font.pixelSize: 9; font.letterSpacing: 1; color: Theme.green }
        PanelLabel { text: Qt.formatDateTime(view.date, "HH:mm"); font.pixelSize: 40; font.weight: Font.Light; Layout.topMargin: 2 }
        PanelLabel { text: view.date.toLocaleString(Qt.locale("en_US"), "dddd, d MMMM"); color: Theme.muted; Layout.topMargin: 2 }
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 16
            SwapText {
                Layout.fillWidth: true
                Layout.preferredHeight: 22
                text: view.shown.toLocaleString(Qt.locale("en_US"), "MMMM yyyy").toLowerCase()
                color: Theme.green
                pixelSize: 15
            }
            Chip { compact: true; label: "today"; visible: view.offset !== 0; ink: Theme.yellow; onClicked: months.currentIndex = view.base }
            Chip { compact: true; label: "‹"; onClicked: view.shift(-1) }
            Chip { compact: true; label: "›"; onClicked: view.shift(1) }
        }
        Row {
            Layout.fillWidth: true
            Layout.topMargin: 12
            Repeater {
                model: ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]
                PanelLabel {
                    required property string modelData
                    required property int index
                    width: months.width / 7
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: index > 4 ? Theme.yellow : Theme.muted
                    opacity: index > 4 ? 0.8 : 1
                    font.pixelSize: 10
                }
            }
        }
        ListView {
            id: months
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: 6
            orientation: ListView.Horizontal
            snapMode: ListView.SnapOneItem
            highlightRangeMode: ListView.StrictlyEnforceRange
            highlightMoveDuration: 320
            highlightMoveVelocity: -1
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            cacheBuffer: 0
            model: 1201
            currentIndex: view.base
            Component.onCompleted: positionViewAtIndex(view.base, ListView.Beginning)
            WheelHandler { onWheel: event => view.shift(event.angleDelta.y > 0 || event.angleDelta.x > 0 ? -1 : 1) }
            delegate: Grid {
                id: month
                required property int index
                readonly property date first: new Date(view.date.getFullYear(), view.date.getMonth() + index - view.base, 1)
                readonly property int lead: (first.getDay() + 6) % 7
                width: months.width
                height: months.height
                columns: 7
                Repeater {
                    model: 42
                    Item {
                        id: cell
                        required property int index
                        readonly property date day: new Date(month.first.getFullYear(), month.first.getMonth(), index - month.lead + 1)
                        readonly property bool inside: day.getMonth() === month.first.getMonth()
                        readonly property bool today: day.getFullYear() === view.date.getFullYear() && day.getMonth() === view.date.getMonth() && day.getDate() === view.date.getDate()
                        width: month.width / 7
                        height: month.height / 6
                        Rectangle {
                            anchors.centerIn: parent
                            width: Math.min(parent.width - 6, 38)
                            height: Math.min(parent.height - 4, 30)
                            radius: 9
                            color: cell.today ? Theme.green : dayHover.hovered ? Theme.elevated : "transparent"
                            Behavior on color { ColorAnimation { duration: Theme.fast } }
                            HoverHandler { id: dayHover }
                        }
                        PanelLabel {
                            anchors.centerIn: parent
                            text: cell.day.getDate()
                            color: cell.today ? Theme.bg : !cell.inside ? Theme.line : cell.index % 7 > 4 ? Theme.yellow : Theme.text
                            font.weight: cell.today ? Font.DemiBold : Font.Normal
                        }
                    }
                }
            }
        }
        PanelLabel { text: "← →  month    ↑ ↓  year    t  today"; color: Theme.muted; font.pixelSize: 9; Layout.topMargin: 6 }
    }
}
