import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick

// Replaces swaync: owns org.freedesktop.Notifications and shows popups top-right on the focused monitor.
PanelWindow {
    id: win
    required property var shell
    readonly property var c: shell.c

    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: true
        bodyMarkupSupported: true
        imageSupported: true
        onNotification: n => n.tracked = true
    }

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    visible: server.trackedNotifications.values.length > 0
    anchors { top: true; right: true }
    margins { top: 52; right: 8 }
    implicitWidth: 380
    implicitHeight: col.height
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "qs-notifs"
    mask: Region { item: col }

    Column {
        id: col
        width: parent.width
        spacing: 8

        Repeater {
            model: server.trackedNotifications
            Rectangle {
                id: card
                required property var modelData
                readonly property bool critical: modelData.urgency === NotificationUrgency.Critical
                width: col.width
                height: content.height + 28
                radius: 16
                color: win.c.bg
                border { color: critical ? win.c.red : win.c.accent2; width: 1 }

                // critical ones stay until dismissed; others use their own timeout, default 6s
                Timer {
                    running: !critical && !hover.hovered
                    interval: modelData.expireTimeout > 0 ? modelData.expireTimeout * 1000 : 6000
                    onTriggered: modelData.expire()
                }
                HoverHandler { id: hover }
                TapHandler { onTapped: modelData.dismiss() }

                Row {
                    id: content
                    x: 14; y: 14
                    width: parent.width - 28
                    spacing: 12

                    IconImage {
                        width: 40; height: 40
                        visible: source != ""
                        source: modelData.image || (modelData.appIcon ? Quickshell.iconPath(modelData.appIcon, true) : "")
                    }
                    Column {
                        width: parent.width - (parent.children[0].visible ? 52 : 0)
                        spacing: 4
                        Text {
                            width: parent.width; elide: Text.ElideRight
                            text: modelData.appName; color: win.c.muted
                            font { family: win.c.font; pixelSize: 11 }
                        }
                        Text {
                            width: parent.width; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
                            text: modelData.summary; color: win.c.text
                            font { family: win.c.font; pixelSize: 14; bold: true }
                        }
                        Text {
                            width: parent.width; wrapMode: Text.Wrap; maximumLineCount: 4; elide: Text.ElideRight
                            visible: text !== ""
                            text: modelData.body; textFormat: Text.StyledText; color: win.c.text
                            font { family: win.c.font; pixelSize: 12 }
                        }
                        Row {
                            spacing: 6
                            visible: modelData.actions.length > 0
                            Repeater {
                                model: modelData.actions
                                Rectangle {
                                    required property var modelData
                                    width: label.width + 20; height: 26; radius: 13
                                    color: win.c.surface2
                                    Text {
                                        id: label; anchors.centerIn: parent
                                        text: parent.modelData.text; color: win.c.accent
                                        font { family: win.c.font; pixelSize: 11 }
                                    }
                                    TapHandler { onTapped: parent.modelData.invoke() }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
