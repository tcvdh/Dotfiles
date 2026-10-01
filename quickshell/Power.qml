import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: win
    required property var modelData
    required property var shell
    readonly property var c: shell.c

    screen: modelData
    visible: shell.powerOpen && Hyprland.focusedMonitor?.name === modelData.name
    anchors { top: true; bottom: true; left: true; right: true }
    color: "#99000000"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "qs-power"

    onVisibleChanged: if (visible) keys.forceActiveFocus()

    readonly property var actions: [
        { icon: "", label: "Lock",     key: Qt.Key_L, cmd: ["hyprlock"],                                  color: c.accent },
        { icon: "", label: "Log out",  key: Qt.Key_E, cmd: ["hyprctl", "dispatch", "hl.dsp.exit()"],      color: c.accent2 },
        { icon: "", label: "Suspend",  key: Qt.Key_S, cmd: ["systemctl", "suspend"],                      color: c.green },
        { icon: "", label: "Restart",  key: Qt.Key_R, cmd: ["systemctl", "reboot"],                       color: c.yellow },
        { icon: "", label: "Shut down", key: Qt.Key_P, cmd: ["systemctl", "poweroff"],                    color: c.red }
    ]

    function run(a) { shell.powerOpen = false; Quickshell.execDetached(a.cmd) }

    MouseArea { anchors.fill: parent; onClicked: shell.powerOpen = false }

    Item {
        id: keys
        Keys.onPressed: e => {
            if (e.key === Qt.Key_Escape) shell.powerOpen = false;
            else { const a = win.actions.find(a => a.key === e.key); if (a) win.run(a) }
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: 20
        Repeater {
            model: win.actions
            Rectangle {
                id: card
                required property var modelData
                width: 130; height: 150; radius: 24
                color: ma.containsMouse ? win.c.surface2 : win.c.bg
                border { color: ma.containsMouse ? modelData.color : "#22ffffff"; width: 2 }
                scale: ma.containsMouse ? 1.06 : 1
                Behavior on scale { NumberAnimation { duration: 120 } }
                Column {
                    anchors.centerIn: parent
                    spacing: 14
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.icon; color: modelData.color
                        font { family: win.c.font; pixelSize: 40 }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.label; color: win.c.text
                        font { family: win.c.font; pixelSize: 14 }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: String.fromCharCode(modelData.key); color: win.c.muted
                        font { family: win.c.font; pixelSize: 11 }
                    }
                }
                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: win.run(modelData)
                }
            }
        }
    }
}
