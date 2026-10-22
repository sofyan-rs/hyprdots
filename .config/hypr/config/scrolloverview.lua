-- ScrollOverview: https://github.com/yayuuu/hyprland-scroll-overview
-- Built against the installed Fedora Hyprland headers; rebuild after updates.
hl.plugin.load("/home/sofyan/.config/hypr/plugins/scrolloverview.so")

hl.config({
    plugin = {
        scrolloverview = {
            gesture_distance = 300,
            scale = 0.5,
            workspace_gap = 100,
            layout = "vertical",
            wallpaper = 2,
            blur = true,
            shadow = {
                enabled = true,
                range = 50,
            },
        },
    },
})

-- Show workspaces on both monitors; press again to close.
hl.bind("SUPER + Tab", function()
    hl.plugin.scrolloverview.overview("toggle all")
end)
