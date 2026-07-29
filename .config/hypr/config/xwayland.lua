-----------------------
----- XWAYLAND -----
-----------------------

-- See https://wiki.hypr.land/Configuring/XWayland/
-- Fixes blurry XWayland apps (Steam, etc.) on fractional-scaled monitors by
-- rendering them at scale 1 and letting Hyprland scale the result smoothly,
-- instead of XWayland doing its own blurry internal scaling.
hl.config({
    xwayland = {
        force_zero_scaling = true,
    },
})
