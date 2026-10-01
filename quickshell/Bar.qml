import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick

PanelWindow {
    id: win
    required property var modelData
    required property var shell
    readonly property var c: shell.c

    screen: modelData
    anchors { top: true; left: true; right: true }
    margins { top: 6; left: 8; right: 8 }
    implicitHeight: 36
    color: "transparent"
    WlrLayershell.namespace: "qs-bar"  // matched by the blur layer_rule in hyprland.lua

    SystemClock { id: clock; precision: SystemClock.Minutes }
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

    readonly property var monitor: Hyprland.monitorFor(modelData)
    readonly property var sink: Pipewire.defaultAudioSink?.audio
    // prefer a playing player, else the first one
    readonly property var player: Mpris.players.values.find(p => p.isPlaying) ?? Mpris.players.values[0] ?? null

    readonly property var btConnected: Bluetooth.devices.values.filter(d => d.connected)

    function dispatch(expr) { Quickshell.execDetached(["hyprctl", "dispatch", expr]) }
    function left(iso) {
        const m = Math.max(0, Math.round((new Date(iso) - clock.date) / 60000));
        return m >= 1440 ? Math.floor(m / 1440) + "d " + Math.floor(m % 1440 / 60) + "h"
                         : Math.floor(m / 60) + "h " + m % 60 + "m";
    }
    function level(pct) { return pct >= 90 ? c.red : pct >= 70 ? c.yellow : c.accent }

    component Pill: Rectangle {
        default property alias content: row.data
        property alias area: pa
        implicitWidth: row.implicitWidth + 24
        height: 36
        radius: 18
        color: win.c.bg
        border { color: "#22ffffff"; width: 1 }
        MouseArea {
            id: pa
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        }
        Row { id: row; anchors.centerIn: parent; spacing: 10 }
    }
    component Glyph: Text {
        color: win.c.text
        font { family: win.c.font; pixelSize: 15 }
        anchors.verticalCenter: parent?.verticalCenter
    }
    component Btn: Glyph {
        property alias area: ma
        MouseArea { id: ma; anchors { fill: parent; margins: -4 } cursorShape: Qt.PointingHandCursor }
    }

    // ── left: workspaces + media ────────────────────────────────────────
    Row {
        anchors.left: parent.left
        spacing: 8

        Pill {
            implicitWidth: 44
            area.cursorShape: Qt.PointingHandCursor
            area.onClicked: { shell.powerOpen = false; shell.launcherOpen = !shell.launcherOpen }
            Glyph { text: "\uf303"; color: win.c.accent; font.pixelSize: 20 }
        }

        Pill {
            Repeater {
                model: {
                    const s = new Set([1, 2, 3, 4, 5]);
                    for (const w of Hyprland.workspaces.values) if (w.id > 0) s.add(w.id);
                    return [...s].sort((a, b) => a - b);
                }
                Rectangle {
                    required property int modelData
                    readonly property bool active: win.monitor?.activeWorkspace?.id === modelData
                    readonly property bool used: Hyprland.workspaces.values.some(w => w.id === modelData)
                    width: active ? 30 : 22
                    height: 22
                    radius: 11
                    anchors.verticalCenter: parent.verticalCenter
                    color: active ? win.c.accent : used ? win.c.surface2 : "transparent"
                    Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    Text {
                        anchors.centerIn: parent
                        text: parent.modelData
                        color: parent.active ? win.c.bg : parent.used ? win.c.text : win.c.muted
                        font { family: win.c.font; pixelSize: 12; bold: true }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.dispatch("hl.dsp.focus({workspace=" + parent.modelData + "})")
                    }
                }
            }
        }

        Pill {
            visible: win.player !== null
            area.cursorShape: Qt.PointingHandCursor
            area.onClicked: e => { if (e.button === Qt.RightButton) win.player?.next(); else win.player?.togglePlaying() }
            Glyph { text: win.player?.isPlaying ? "\uf04c" : "\uf04b"; color: win.c.accent; font.pixelSize: 13 }
            ClippingRectangle {
                width: 24; height: 24; radius: 6
                anchors.verticalCenter: parent.verticalCenter
                color: win.c.surface2
                Image { anchors.fill: parent; source: win.player?.trackArtUrl ?? ""; fillMode: Image.PreserveAspectCrop }
            }
            Text {
                width: Math.min(implicitWidth, 260)
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                color: win.c.text
                font { family: win.c.font; pixelSize: 12 }
                text: (win.player?.trackArtist ? win.player.trackArtist + " – " : "") + (win.player?.trackTitle ?? "")
            }
        }
    }

    // ── centre: clock ───────────────────────────────────────────────────
    Pill {
        anchors.centerIn: parent
        Glyph { text: Qt.formatDateTime(clock.date, "ddd d MMM"); color: win.c.muted; font.pixelSize: 13 }
        Glyph { text: Qt.formatDateTime(clock.date, "HH:mm"); font { pixelSize: 14; bold: true } }
    }

    // ── right: claude, volume, tray, power ──────────────────────────────
    Row {
        anchors.right: parent.right
        spacing: 8

        Pill {
            Glyph { text: "\uf2db"; color: win.c.accent2 }
            Glyph { width: 30; horizontalAlignment: Text.AlignRight; text: Math.round(shell.cpu) + "%"; font.pixelSize: 12; color: win.level(shell.cpu) }
            Glyph { text: "\udb80\udf5b"; color: win.c.accent2 }
            Glyph { text: shell.memUsedGb.toFixed(1) + "G"; font.pixelSize: 12; color: win.level(shell.mem) }
        }

        Pill {
            visible: Bluetooth.defaultAdapter !== null
            area.cursorShape: Qt.PointingHandCursor
            area.onClicked: { shell.powerOpen = false; shell.prefill = ">bluetooth"; shell.launcherOpen = true }
            Glyph { text: "\uf293"; color: win.btConnected.length > 0 ? win.c.accent : win.c.muted }
            Glyph {
                visible: win.btConnected.length > 0
                font.pixelSize: 12
                text: win.btConnected[0]?.name + (win.btConnected[0]?.batteryAvailable ? "  " + Math.round(win.btConnected[0].battery * 100) + "%" : "")
                      + (win.btConnected.length > 1 ? "  +" + (win.btConnected.length - 1) : "")
            }
        }

        Pill {
            visible: shell.usage !== null
            Glyph { text: "✻"; color: "#d97757"; font.pixelSize: 16 }
            Repeater {
                model: [
                    { label: "5h", d: shell.usage?.five_hour },
                    { label: "7d", d: shell.usage?.seven_day }
                ]
                Row {
                    required property var modelData
                    readonly property real pct: modelData.d?.utilization ?? 0
                    spacing: 6
                    anchors.verticalCenter: parent.verticalCenter
                    Glyph { text: modelData.label; color: win.c.muted; font.pixelSize: 12 }
                    Rectangle {
                        width: 44; height: 6; radius: 3
                        anchors.verticalCenter: parent.verticalCenter
                        color: win.c.surface2
                        Rectangle {
                            width: parent.width * Math.min(1, parent.parent.pct / 100)
                            height: parent.height; radius: 3
                            color: win.level(parent.parent.pct)
                            Behavior on width { NumberAnimation { duration: 300 } }
                        }
                    }
                    Glyph {
                        text: Math.round(parent.pct) + "%" + (modelData.d ? "  " + win.left(modelData.d.resets_at) : "")
                        font.pixelSize: 12
                    }
                }
            }
        }

        Pill {
            area.cursorShape: Qt.PointingHandCursor
            // click opens the mixer, middle mutes, wheel changes volume (same wpctl calls as your keybinds)
            area.onClicked: e => {
                if (e.button === Qt.MiddleButton) Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]);
                else Quickshell.execDetached(["pavucontrol"]);
            }
            area.onWheel: e => Quickshell.execDetached(["wpctl", "set-volume", "-l", "1", "@DEFAULT_AUDIO_SINK@", e.angleDelta.y > 0 ? "5%+" : "5%-"])
            Glyph {
                text: win.sink?.muted ? "\uf026" : "\uf028"
                color: win.sink?.muted ? win.c.red : win.c.text
            }
            Glyph { text: Math.round((win.sink?.volume ?? 0) * 100) + "%"; font.pixelSize: 12 }
        }

        Pill {
            visible: SystemTray.items.values.length > 0
            Repeater {
                model: SystemTray.items
                Item {
                    id: ti
                    required property var modelData
                    width: 20; height: 20
                    anchors.verticalCenter: parent.verticalCenter
                    IconImage { anchors.fill: parent; source: ti.modelData.icon }
                    QsMenuAnchor {
                        id: menu
                        menu: ti.modelData.menu
                        anchor { item: ti; edges: Edges.Bottom | Edges.Left; gravity: Edges.Bottom | Edges.Right }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                        onClicked: e => {
                            if (e.button === Qt.MiddleButton) ti.modelData.secondaryActivate();
                            else if (e.button === Qt.RightButton || ti.modelData.onlyMenu) { if (ti.modelData.hasMenu) menu.open() }
                            else ti.modelData.activate();
                        }
                    }
                }
            }
        }

        Pill {
            implicitWidth: 40
            Btn { text: ""; color: win.c.red; area.onClicked: { shell.launcherOpen = false; shell.powerOpen = true } }
        }
    }
}
