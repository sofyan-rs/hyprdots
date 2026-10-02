-----------------------
----- XWAYLAND -----
-----------------------

-- See https://wiki.hypr.land/Configuring/XWayland/
-- Keep XWayland surfaces unscaled for sharp rendering. Applications must
-- apply their own UI scale; otherwise they appear smaller on scaled monitors.
hl.config({
    xwayland = {
        force_zero_scaling = true,
    },
})
