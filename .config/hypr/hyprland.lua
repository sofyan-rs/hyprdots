-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
--                   HYPRLAND CONFIG                     --
--                     BY KURONEKO                       --
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

-- Split into per-topic files under config/ for easier navigation. Old
-- single-file config backed up at hyprland.lua.bak-20260729. See
-- https://wiki.hypr.land/Configuring/Start/ for how require() resolves files.

require("config.monitors")
require("config.autostart")
require("config.env")
require("config.xwayland")
require("config.permissions")
require("config.appearance")
require("config.layouts")
require("config.misc")
require("config.input")
require("config.keybinds")
require("config.windowrules")
