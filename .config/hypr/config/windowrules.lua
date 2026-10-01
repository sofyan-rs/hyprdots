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

-- Keep Brave video and Google Meet picture-in-picture windows clear.
hl.window_rule({
    name  = "brave-pip-no-blur",
    match = {
        class = "^[Bb]rave(-.*)?$",
        title = "^([Pp]icture[- ][Ii]n[- ][Pp]icture|meet[.]google[.]com)$",
    },

    border_size = 0,
    decorate = false,
    no_shadow = true,
    no_blur = true,
    opacity = "1.0 override 1.0 override 1.0 override",
})

-- Meet's document PiP uses the meeting title rather than "Picture-in-Picture".
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
    opacity = "1.0 override 1.0 override 1.0 override",
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

-- Blur quickshell (their backgrounds are semi-transparent, so blur is
-- only visible here if layer blur is enabled)
hl.layer_rule({ name = "blur-quickshell",    match = { namespace = "^quickshell$" },    blur = true })

-- Hyprland-run windowrule
hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },

    move  = "20 monitor_h-120",
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
