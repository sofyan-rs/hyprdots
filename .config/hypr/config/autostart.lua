-------------------
---- AUTOSTART ----
-------------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/

hl.on("hyprland.start", function ()
  -- xdg-desktop-portal doesn't start on its own unless the session was launched
  -- via uwsm (systemd graphical-session.target never activates otherwise), which
  -- breaks color-scheme (dark theme) for GTK4/libadwaita apps, screen sharing, etc.
  hl.exec_cmd("/usr/libexec/xdg-desktop-portal-hyprland")
  hl.exec_cmd("/usr/libexec/xdg-desktop-portal-gtk")
  hl.exec_cmd("/usr/libexec/xdg-desktop-portal")

  hl.exec_cmd("nm-applet")
  hl.exec_cmd("blueman-applet")
  hl.exec_cmd("mako")
  hl.exec_cmd("waybar")

  -- Wallpaper: awww-daemon does the rendering (swww's successor, package "swww"
  -- was renamed to "awww" upstream/in the copr). waypaper --restore re-applies
  -- whatever wallpaper is set in ~/.config/waypaper/config.ini (waybar's
  -- wallpaper button opens the picker). Give the daemon a moment to come up.
  hl.exec_cmd("awww-daemon")
  hl.exec_cmd("sleep 1 && waypaper --restore")
end)
