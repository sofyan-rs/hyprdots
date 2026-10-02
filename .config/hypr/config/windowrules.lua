--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- and https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/

-- Example window rules that are useful

local suppressMaximizeRule = hl.window_rule({
    -- Ignore maximize requests from all apps. You'll probably like this.
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})
-- suppressMaximizeRule:set_enabled(false)

-- Open GTK portal file pickers floating in the middle of their monitor.
hl.window_rule({
    name = "gtk-file-picker-center",
    match = { class = "^[Xx]dg-desktop-portal-gtk$" },

    float = true,
    center = true,
})

-- XWayland GTK portal pickers (ChatGPT, Telegram, etc.) include transparent
-- frame margins; compositor borders, shadows and blur outline those margins.
hl.window_rule({
    name = "xwayland-gtk-file-picker-no-frame",
    match = {
        class = "^Xdg-desktop-portal-gtk$",
        xwayland = true,
    },

    border_size = 0,
    no_shadow = true,
    no_blur = true,
})

-- Keep Brave video and Google Meet picture-in-picture windows clear.
hl.window_rule({
    name  = "brave-meet-pip-no-blur",
    match = {
        class = "^[Bb]rave(-.*)?$",
        title = "^Meet - .*",
        float = true,
    },

    border_size = 0,
    decorate = false,
    no_shadow = true,
    no_blur = true,
    opacity = "1.0 override",
})

hl.window_rule({
    -- Fix some dragging issues with XWayland
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})

-- Layer rules also return a handle.
-- local overlayLayerRule = hl.layer_rule({
--     name  = "no-anim-overlay",
--     match = { namespace = "^my-overlay$" },
--     no_anim = true,
-- })
-- overlayLayerRule:set_enabled(false)

-- Show and resize the dock immediately, including its window picker.
hl.layer_rule({
    name = "quickshell-dock-no-animation",
    match = { namespace = "^quickshell-dock$" },
    no_anim = true,
})

-- Let the control center follow its content without compositor resize animation.
hl.layer_rule({
    name = "quickshell-controlcenter-no-animation",
    match = { namespace = "^quickshell-controlcenter$" },
    no_anim = true,
})

-- Blur quickshell (their backgrounds are semi-transparent, so blur is
-- only visible here if layer blur is enabled)
hl.layer_rule({ name = "blur-quickshell",    match = { namespace = "^quickshell$" },    blur = true })

-- Hyprland-run windowrule
hl.window_rule({
    name  = "float-hyprland-run",
    match = { class = "hyprland-run" },

    float = true,
})

-- Android Studio: float its dialogs/utility windows (Welcome screen, Device
-- Manager, Settings, etc.), but leave the main project window tiling, since
-- it shares the same class with no other way to tell them apart.
hl.window_rule({
    name  = "float-android-studio-dialogs",
    match = {
        class = "^jetbrains-studio$",
        title = "^(Welcome to Android Studio|Device Manager|Settings|Preferences|New Project)$",
    },

    float = true,
})

-- Its emulator: always float
hl.window_rule({
    name  = "float-android-emulator",
    match = { class = "^Emulator$" },

    float = true,
})

hl.window_rule({
    match = {
        xwayland = true,
    },

    no_blur = true,
    opacity = "1.0 override",
})

-- Center newly opened floating windows, including dialogs and utility windows.
-- Hyprland only applies center to floating windows; tiled windows keep their layout.
hl.window_rule({
    name = "center-floating-windows",
    match = { class = ".*" },

    center = true,
})
