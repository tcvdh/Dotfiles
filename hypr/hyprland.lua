---@module 'hl'

-- Variables
local mod         = "SUPER"
local terminal    = "kitty"
local fileManager = "thunar"
local browser     = "google-chrome-stable"
local screenshots = os.getenv("HOME") .. "/Pictures/Screenshots"

-- Monitors
hl.monitor({ output = "DP-2", mode = "2560x1440@165", position = "-2560x0", scale = 1 })
hl.monitor({ output = "DP-1", mode = "2560x1440@144", position = "0x0",       scale = 1 })

-- Environment
hl.env("HYPRSHOT_DIR", screenshots)
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("_JAVA_AWT_WM_NONREPARENTING", 1)
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("XCURSOR_SIZE", 24)
hl.env("HYPRCURSOR_SIZE", 24)
-- Nvidia
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")

-- Autostart
hl.on("hyprland.start", function()
    hl.exec_cmd("/usr/lib/xdg-desktop-portal")
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd("waypaper --restore")
    hl.exec_cmd("quickshell")
    hl.exec_cmd("flameshot")
    -- tray apps must start after quickshell owns the StatusNotifierWatcher, or they never show up
    hl.exec_cmd("sh -c 'until busctl --user list | grep -q StatusNotifierWatcher; do sleep 0.5; done; exec bitwarden-desktop'")
    -- clipboard history (cliphist): store every copy, text and images
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd(terminal)
end)

-- Look and feel
hl.config({
    general = {
        gaps_in = 2,
        gaps_out = 8,
        border_size = 2,
        col = {
            active_border = { colors = { "rgba(81a1c1ee)", "rgba(88c0d0ee)" }, angle = 45 },
            inactive_border = "rgba(4c566aaa)",
        },
    },
    decoration = {
        rounding = 10,
        rounding_power = 2,
        shadow = { enabled = true, range = 4, render_power = 3, color = "rgba(1a1a1aee)" },
        blur = { enabled = true, size = 3, passes = 1, vibrancy = 0.1696 },
    },
    misc = {
        vrr = 0,
        disable_hyprland_logo = true,
    },
    dwindle = { preserve_split = true },
    cursor = { no_hardware_cursors = true },
    opengl = { nvidia_anti_flicker = false },
    debug  = { damage_tracking = 0 },
})

-- Input
hl.config({
    input = {
        kb_layout = "us",
        sensitivity = 1,
    },
})

hl.device({ name = "glorious-model-o-wireless", sensitivity = -0.3 })

-- Blur behind quickshell surfaces (bar, launcher, power menu, notifications); ignore_alpha keeps the transparent gaps unblurred
hl.layer_rule({ name = "quickshell-blur", match = { namespace = "^qs-" }, blur = true, blur_popups = true, ignore_alpha = 0.2 })

-- Window rules
hl.window_rule({ name = "suppress-maximize", match = { class = ".*" }, suppress_event = "maximize" })
hl.window_rule({
    name = "xwayland-drag-fix",
    match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
    no_focus = true,
})
hl.window_rule({
    name = "claude-agent-float",
    match = { class = "^(claude-agent)$" },
    float = true,
    size = { 1280, 720 },
    center = true,
})

-- Keybindings: apps
hl.bind(mod .. " + Q", hl.dsp.exec_cmd(terminal))
hl.bind(mod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mod .. " + R", hl.dsp.exec_cmd("quickshell ipc call app-launcher toggle"))
hl.bind(mod .. " + F", hl.dsp.exec_cmd(browser))
hl.bind(mod .. " + SHIFT + V", hl.dsp.exec_cmd("quickshell ipc call app-launcher clipboard"))
hl.bind(mod .. " + period", hl.dsp.exec_cmd("quickshell ipc call app-launcher emoji"))
hl.bind(mod .. " + A", hl.dsp.exec_cmd("~/.local/bin/agent-launch"))
hl.bind(mod .. " + B", hl.dsp.exec_cmd("rbw-menu"))
hl.bind(mod .. " + L", hl.dsp.exec_cmd("hyprlock"))
hl.bind(mod .. " + SHIFT + S", hl.dsp.exec_cmd("hyprshot -m region"))

-- Keybindings: windows
hl.bind(mod .. " + C", hl.dsp.window.close())
hl.bind(mod .. " + M", hl.dsp.exit())
hl.bind(mod .. " + V", hl.dsp.window.float())
hl.bind(mod .. " + Return", hl.dsp.window.fullscreen())
hl.bind(mod .. " + P", hl.dsp.window.pseudo())
hl.bind(mod .. " + J", hl.dsp.layout("togglesplit"))
for _, dir in ipairs({ "left", "right", "up", "down" }) do
    hl.bind(mod .. " + " .. dir, hl.dsp.focus({ direction = dir }))
end

-- Keybindings: workspaces (key 0 = workspace 10)
for i = 1, 10 do
    local key = i % 10
    hl.bind(mod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end
hl.bind(mod .. " + W", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mod .. " + SHIFT + W", hl.dsp.window.move({ workspace = "special:magic" }))
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Keybindings: mouse drag/resize
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Keybindings: media (needs wpctl, playerctl)
local locked = { locked = true }
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), locked)
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), locked)
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), locked)
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), locked)
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), locked)
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), locked)
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), locked)
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), locked)
