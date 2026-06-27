--   $$$$$$$$\                     $$\                                                                  $$\           $$\    $$\                    $$\           $$\       $$\                     
--   $$  _____|                    \__|                                                                 $$ |          $$ |   $$ |                   \__|          $$ |      $$ |                    
--   $$ |      $$$$$$$\ $$\    $$\ $$\  $$$$$$\   $$$$$$\  $$$$$$$\  $$$$$$\$$$$\   $$$$$$\  $$$$$$$\ $$$$$$\         $$ |   $$ |$$$$$$\   $$$$$$\  $$\  $$$$$$\  $$$$$$$\  $$ | $$$$$$\   $$$$$$$\ 
--   $$$$$\    $$  __$$\\$$\  $$  |$$ |$$  __$$\ $$  __$$\ $$  __$$\ $$  _$$  _$$\ $$  __$$\ $$  __$$\\_$$  _|        \$$\  $$  |\____$$\ $$  __$$\ $$ | \____$$\ $$  __$$\ $$ |$$  __$$\ $$  _____|
--   $$  __|   $$ |  $$ |\$$\$$  / $$ |$$ |  \__|$$ /  $$ |$$ |  $$ |$$ / $$ / $$ |$$$$$$$$ |$$ |  $$ | $$ |           \$$\$$  / $$$$$$$ |$$ |  \__|$$ | $$$$$$$ |$$ |  $$ |$$ |$$$$$$$$ |\$$$$$$\  
--   $$ |      $$ |  $$ | \$$$  /  $$ |$$ |      $$ |  $$ |$$ |  $$ |$$ | $$ | $$ |$$   ____|$$ |  $$ | $$ |$$\         \$$$  / $$  __$$ |$$ |      $$ |$$  __$$ |$$ |  $$ |$$ |$$   ____| \____$$\ 
--   $$$$$$$$\ $$ |  $$ |  \$  /   $$ |$$ |      \$$$$$$  |$$ |  $$ |$$ | $$ | $$ |\$$$$$$$\ $$ |  $$ | \$$$$  |         \$  /  \$$$$$$$ |$$ |      $$ |\$$$$$$$ |$$$$$$$  |$$ |\$$$$$$$\ $$$$$$$  |
--   \________|\__|  \__|   \_/    \__|\__|       \______/ \__|  \__|\__| \__| \__| \_______|\__|  \__|  \____/           \_/    \_______|\__|      \__| \_______|\_______/ \__| \_______|\_______/

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/


-- Cursor Settings

--- Cursor Size ---
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

--- Cursor Theme ---
-- hl.env("XCURSOR_THEME", "macOS")
-- hl.env("HYPRCURSOR_THEME", "macOS_HYPR")

-- Toolkit Backend
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("CLUTTER_BACKEND", "wayland")

-- XDG Specification
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

-- Qt Variables
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1") -- Value Depends on the monitor scale factor 1 for 100%, 2 for 200%, etc.
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")

-- Nvidia Specific 

-- Current PC does not have but my previous one did, so I will leave it here for future reference
-- hl.env("LIBVA_DRIVER_NAME", "nvidia") -- For hardware acceleration with Nvidia GPUs 
-- hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia") 