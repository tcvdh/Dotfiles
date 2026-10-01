import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick

PanelWindow {
    id: win
    required property var modelData
    required property var shell
    readonly property var c: shell.c

    screen: modelData
    // only on the monitor that has focus
    visible: shell.launcherOpen && Hyprland.focusedMonitor?.name === modelData.name
    anchors { top: true; bottom: true; left: true; right: true }
    color: "#66000000"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "qs-launcher"

    // prefix modes: ">" actions, ";" clipboard history (cliphist), ":" emoji
    onVisibleChanged: if (visible) {
        field.text = shell.prefill; shell.prefill = "";
        field.cursorPosition = field.text.length;
        list.currentIndex = 0; field.forceActiveFocus();
    }

    property var clipItems: []
    Process {
        id: clipProc
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: win.clipItems = text.split("\n").filter(l => l).map(l => {
                const i = l.indexOf("\t");
                return { id: l.slice(0, i), text: l.slice(i + 1) };
            })
        }
    }
    // toggle so a process that failed earlier (running stays true) is restarted instead of ignored
    function refreshClip() { clipProc.running = false; clipProc.running = true }
    Process { id: delProc; onExited: win.refreshClip() }
    onClipItemsChanged: list.currentIndex = Math.min(list.currentIndex, Math.max(0, results.length - 1))

    function clipResults(f) {
        if (!clipItems.length) return [{ glyph: "\uf0ea", name: "Clipboard history is empty", comment: "Needs cliphist and the wl-paste watchers from hyprland.lua", execute: () => {} }];
        return clipItems.filter(c => c.text.toLowerCase().includes(f)).slice(0, 60).map(c => ({
            glyph: c.text.startsWith("[[ binary data") ? "\uf03e" : "\uf0ea",
            name: c.text, comment: "Enter: copy  ·  Shift+Del: delete from history", clipId: c.id,
            execute: () => Quickshell.execDetached(["sh", "-c", "cliphist decode " + c.id + " | wl-copy"])
        }));
    }
    function emojiResults(f) {
        return shell.emojis.filter(x => x.name.includes(f)).slice(0, 80).map(x => ({
            glyph: x.e, name: x.name, comment: "Enter: copy " + x.e,
            execute: () => Quickshell.execDetached(["wl-copy", x.e])
        }));
    }
    function deleteClip() {
        const id = results[list.currentIndex]?.clipId;
        if (!id) return;
        delProc.command = ["sh", "-c", "cliphist list | grep -P '^" + id + "\\t' | cliphist delete"];
        delProc.running = true;
    }

    readonly property var results: {
        const raw = field.text.trim();
        if (raw.startsWith(";")) return clipResults(raw.slice(1).trim().toLowerCase());
        if (raw.startsWith(":")) return emojiResults(raw.slice(1).trim().toLowerCase());
        if (raw.startsWith(">")) {  // actions: ">" lists them, ">dark" filters, anything unmatched can run as a shell command
            const cmd = raw.slice(1).trim(), f = cmd.toLowerCase();
            const sh = c => () => Quickshell.execDetached(["sh", "-c", c]);
            const A = (glyph, name, comment, execute) => ({ glyph, name, comment, execute });
            const cap = k => k[0].toUpperCase() + k.slice(1);
            const acts = [
                A("\uf03e", "Wallpaper", "Pick a wallpaper (waypaper)", sh("waypaper")),
                ...Object.keys(shell.schemes).map(k => A("\uf1fc", "Scheme " + cap(k), "Switch colour scheme", () => shell.setTheme(k))),
                ...[100, 87, 60, 35].map(p => A("\uf042", "Transparency " + p + "%", "Bar and popup opacity", () => shell.setTheme("", p / 100))),
                A("\uf185", "Light", "Light mode", () => { shell.setTheme("latte"); sh("gsettings set org.gnome.desktop.interface color-scheme prefer-light")() }),
                A("\uf186", "Dark", "Dark mode", () => { shell.setTheme(shell.dark); sh("gsettings set org.gnome.desktop.interface color-scheme prefer-dark")() }),
                ...(Bluetooth.defaultAdapter ? [
                    A("\uf293", "Bluetooth " + (Bluetooth.defaultAdapter.enabled ? "off" : "on"), "Toggle the adapter", () => { Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled }),
                    ...Bluetooth.devices.values.filter(d => d.paired).map(d => A("\uf293", "Bluetooth " + d.name,
                        d.connected ? "Connected  ·  Enter to disconnect" : "Enter to connect", () => { d.connected = !d.connected }))
                ] : []),
                A("\uf1f8", "Clear clipboard history", "Wipe everything cliphist has stored", sh("cliphist wipe")),
                A("\uf023", "Lock", "Lock the screen", sh("hyprlock")),
                A("\uf236", "Sleep", "Suspend", sh("systemctl suspend")),
                A("\uf08b", "Logout", "Exit Hyprland", sh("hyprctl dispatch 'hl.dsp.exit()'")),
                A("\uf021", "Restart", "Reboot", sh("systemctl reboot")),
                A("\uf011", "Shutdown", "Power off", sh("systemctl poweroff"))
            ].filter(a => a.name.toLowerCase().includes(f));
            if (cmd) acts.push(A("\uf120", "Run: " + cmd, "Run in a shell (no terminal window)", sh(cmd)));
            return acts;
        }
        const q = raw.toLowerCase();
        const apps = DesktopEntries.applications.values;
        const byName = (a, b) => a.name.localeCompare(b.name);
        if (!q) return [...apps].sort(byName);
        const score = a => {
            const n = a.name.toLowerCase();
            if (n.startsWith(q)) return 3;
            if (n.includes(q)) return 2;
            const rest = ((a.genericName ?? "") + " " + (a.comment ?? "") + " " + (a.keywords ?? []).join(" ")).toLowerCase();
            return rest.includes(q) ? 1 : 0;
        };
        return apps.map(a => ({ a, s: score(a) })).filter(x => x.s)
                   .sort((x, y) => y.s - x.s || byName(x.a, y.a)).map(x => x.a);
    }

    function launch() {
        const e = results[list.currentIndex];
        if (e) { shell.launcherOpen = false; e.execute() }
    }

    MouseArea { anchors.fill: parent; onClicked: shell.launcherOpen = false }

    Rectangle {
        width: 600
        height: 92 + Math.min(win.results.length, 8) * 52
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: parent.height * 0.18 }
        radius: 20
        color: win.c.bg
        border { color: win.c.accent2; width: 1 }
        MouseArea { anchors.fill: parent }  // swallow clicks

        Rectangle {
            id: box
            x: 16; y: 16; width: parent.width - 32; height: 44
            radius: 12; color: win.c.surface
            Text {
                x: 14; anchors.verticalCenter: parent.verticalCenter
                text: ""; color: win.c.accent; font { family: win.c.font; pixelSize: 16 }
            }
            TextInput {
                id: field
                x: 42; width: parent.width - 56; anchors.verticalCenter: parent.verticalCenter
                color: win.c.text; selectionColor: win.c.accent2
                font { family: win.c.font; pixelSize: 16 }
                onTextChanged: { list.currentIndex = 0; if (text === ";") win.refreshClip() }
                Keys.onPressed: e => {
                    if (e.key === Qt.Key_Escape) shell.launcherOpen = false;
                    else if (e.key === Qt.Key_Down) list.currentIndex = Math.min(list.currentIndex + 1, win.results.length - 1);
                    else if (e.key === Qt.Key_Up) list.currentIndex = Math.max(list.currentIndex - 1, 0);
                    else if (e.key === Qt.Key_Delete && (e.modifiers & Qt.ShiftModifier)) win.deleteClip();
                    else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) win.launch();
                    else return;
                    e.accepted = true;
                }
                Text {
                    visible: !field.text; text: "Search apps…"; color: win.c.muted
                    font: field.font
                }
            }
        }

        ListView {
            id: list
            anchors { top: box.bottom; topMargin: 8; left: parent.left; right: parent.right; bottom: parent.bottom; margins: 16 }
            clip: true
            model: win.results
            highlightMoveDuration: 80
            delegate: Rectangle {
                required property var modelData
                required property int index
                width: list.width; height: 52; radius: 12
                color: ListView.isCurrentItem ? win.c.surface2 : "transparent"
                Row {
                    anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 12 }
                    spacing: 12
                    Item {
                        id: ico
                        width: 32; height: 32
                        anchors.verticalCenter: parent.verticalCenter
                        property bool broken: false
                        // theme icon, absolute path, or (when missing/broken) a glyph instead of Qt's checkerboard
                        readonly property string src: {
                            const i = modelData.icon ?? "";
                            return i.startsWith("/") ? "file://" + i : i && Quickshell.hasThemeIcon(i) ? Quickshell.iconPath(i) : "";
                        }
                        IconImage {
                            anchors.fill: parent
                            visible: ico.src !== "" && !ico.broken
                            source: ico.src
                            onStatusChanged: if (status === Image.Error) ico.broken = true
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: ico.src === "" || ico.broken
                            text: modelData.glyph ?? "\uf2d0"
                            color: win.c.accent
                            font { family: win.c.font; pixelSize: 22 }
                        }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            width: 480; elide: Text.ElideRight
                            text: modelData.name; color: win.c.text
                            font { family: win.c.font; pixelSize: 14 }
                        }
                        Text {
                            width: 480; elide: Text.ElideRight
                            text: modelData.comment || modelData.genericName || ""; color: win.c.muted
                            visible: text !== ""
                            font { family: win.c.font; pixelSize: 11 }
                        }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: list.currentIndex = index
                    onClicked: { list.currentIndex = index; win.launch() }
                }
            }
        }
    }
}
