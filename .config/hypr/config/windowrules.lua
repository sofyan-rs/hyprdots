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

-- Blur waybar and rofi (their backgrounds are semi-transparent, so blur is
-- only visible here if layer blur is enabled)
hl.layer_rule({ name = "blur-waybar",        match = { namespace = "^waybar$" },        blur = true })
hl.layer_rule({ name = "blur-rofi",          match = { namespace = "^rofi$" },          blur = true, animation = "popin 80%" })

-- Hyprland-run windowrule
hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },

    move  = "20 monitor_h-120",
    float = true,
})

-- Android Studio + its emulator: float instead of tiling
hl.window_rule({
    name  = "float-android-studio",
    match = { class = "^jetbrains-studio$" },

    float = true,
})

hl.window_rule({
    name  = "float-android-emulator",
    match = { class = "^Emulator$" },

    float = true,
})
