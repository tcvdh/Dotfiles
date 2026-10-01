//@ pragma UseQApplication
import Quickshell
import Quickshell.Io
import QtQuick

ShellRoot {
    id: root

    // Theme: colour scheme + transparency, switched from the launcher (">scheme", ">transparency"), saved to state dir
    readonly property var schemes: ({
        nord:       { base: "#2e3440", surface: "#3b4252", surface2: "#434c5e", text: "#eceff4", muted: "#8892a8", accent: "#88c0d0", accent2: "#81a1c1", green: "#a3be8c", yellow: "#ebcb8b", red: "#bf616a" },
        catppuccin: { base: "#1e1e2e", surface: "#313244", surface2: "#45475a", text: "#cdd6f4", muted: "#7f849c", accent: "#cba6f7", accent2: "#89b4fa", green: "#a6e3a1", yellow: "#f9e2af", red: "#f38ba8" },
        tokyonight: { base: "#1a1b26", surface: "#24283b", surface2: "#343a55", text: "#c0caf5", muted: "#737aa2", accent: "#7aa2f7", accent2: "#bb9af7", green: "#9ece6a", yellow: "#e0af68", red: "#f7768e" },
        gruvbox:    { base: "#282828", surface: "#3c3836", surface2: "#504945", text: "#ebdbb2", muted: "#a89984", accent: "#8ec07c", accent2: "#83a598", green: "#b8bb26", yellow: "#fabd2f", red: "#fb4934" },
        rosepine:   { base: "#191724", surface: "#1f1d2e", surface2: "#26233a", text: "#e0def4", muted: "#6e6a86", accent: "#c4a7e7", accent2: "#ebbcba", green: "#9ccfd8", yellow: "#f6c177", red: "#eb6f92" },
        latte:      { base: "#eff1f5", surface: "#ccd0da", surface2: "#bcc0cc", text: "#4c4f69", muted: "#7c7f93", accent: "#8839ef", accent2: "#1e66f5", green: "#40a02b", yellow: "#df8e1d", red: "#d20f39" }
    })
    property string scheme: "nord"
    property string dark: "nord"   // what ">dark" returns to
    property real alpha: 0.87
    readonly property var s: schemes[scheme] ?? schemes.nord

    readonly property QtObject c: QtObject {
        readonly property color bg: Qt.alpha(root.s.base, root.alpha)
        readonly property color surface: root.s.surface
        readonly property color surface2: root.s.surface2
        readonly property color text: root.s.text
        readonly property color muted: root.s.muted
        readonly property color accent: root.s.accent
        readonly property color accent2: root.s.accent2
        readonly property color green: root.s.green
        readonly property color yellow: root.s.yellow
        readonly property color red: root.s.red
        readonly property string font: "JetBrainsMono Nerd Font"
    }

    FileView { id: store; path: Quickshell.statePath("settings.json"); blockLoading: true }
    Component.onCompleted: {
        emojis = emojiFile.text().split("\n").filter(l => l).map(l => { const i = l.indexOf("\t"); return { e: l.slice(0, i), name: l.slice(i + 1) } });
        try {
            const d = JSON.parse(store.text());
            if (schemes[d.scheme]) scheme = d.scheme;
            if (schemes[d.dark]) dark = d.dark;
            if (d.alpha > 0) alpha = d.alpha;
        } catch (e) {}
    }
    function setTheme(name, a) {
        if (name) { scheme = name; if (name !== "latte") dark = name }
        if (a) alpha = a;
        store.setText(JSON.stringify({ scheme, dark, alpha }));
    }

    property bool launcherOpen: false
    property bool powerOpen: false
    property var usage: null  // parsed Claude /usage response
    property real cpu: 0      // %
    property real mem: 0      // %
    property real memUsedGb: 0
    property var prevCpu: null
    property string prefill: ""   // text the launcher opens with (";" clipboard, ":" emoji, ">bluetooth")
    property var emojis: []

    IpcHandler {
        target: "app-launcher"
        function toggle(): void { root.powerOpen = false; root.prefill = ""; root.launcherOpen = !root.launcherOpen }
        function clipboard(): void { root.powerOpen = false; root.prefill = ";"; root.launcherOpen = true }
        function emoji(): void { root.powerOpen = false; root.prefill = ":"; root.launcherOpen = true }
    }
    IpcHandler {
        target: "power"
        function toggle(): void { root.launcherOpen = false; root.powerOpen = !root.powerOpen }
    }

    // Claude 5h / weekly limits (scripts/claude-usage.sh). 1 min poll.
    Process {
        id: usageProc
        running: true
        command: [Quickshell.shellPath("scripts/claude-usage.sh")]
        stdout: StdioCollector {
            onStreamFinished: { try { root.usage = JSON.parse(text) } catch (e) {} }
        }
    }
    Timer { interval: 60000; running: true; repeat: true; onTriggered: usageProc.running = true }

    // CPU / RAM from /proc every 2s
    FileView { id: statFile; path: "/proc/stat"; blockLoading: true }
    FileView { id: memFile; path: "/proc/meminfo"; blockLoading: true }
    FileView { id: emojiFile; path: Quickshell.shellPath("data/emoji.tsv"); blockLoading: true }
    Timer {
        interval: 2000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            statFile.reload(); memFile.reload();
            const t = statFile.text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
            const idle = t[3] + t[4], total = t.reduce((a, b) => a + b, 0);
            if (root.prevCpu) root.cpu = 100 * (1 - (idle - root.prevCpu.idle) / (total - root.prevCpu.total));
            root.prevCpu = { idle, total };
            const m = memFile.text(), kb = k => Number(m.match(new RegExp(k + ":\\s+(\\d+)"))[1]);
            root.mem = 100 * (1 - kb("MemAvailable") / kb("MemTotal"));
            root.memUsedGb = (kb("MemTotal") - kb("MemAvailable")) / 1048576;
        }
    }

    Variants { model: Quickshell.screens; Bar { shell: root } }
    Variants { model: Quickshell.screens; Launcher { shell: root } }
    Variants { model: Quickshell.screens; Power { shell: root } }
    Notifications { shell: root }
}
