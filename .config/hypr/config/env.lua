-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

hl.env("XCURSOR_SIZE", "28")
hl.env("HYPRCURSOR_SIZE", "28")

-- Steam's own UI doesn't handle fractional monitor scaling, so it renders
-- blurry over XWayland (unlike Discord, which can run natively on Wayland).
-- Force it to render its UI at the monitor's scale directly instead of being
-- upscaled after the fact.
hl.env("STEAM_FORCE_DESKTOPUI_SCALING", "1.33")
