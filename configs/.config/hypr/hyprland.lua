-- https://wiki.hypr.land/Configuring/Start/

--  $$\   $$\                               $$\                           $$\        $$$$$$\                                                    
--  $$ |  $$ |                              $$ |                          $$ |      $$  __$$\                                                   
--  $$ |  $$ |$$\   $$\  $$$$$$\   $$$$$$\  $$ | $$$$$$\  $$$$$$$\   $$$$$$$ |      $$ /  \__| $$$$$$\  $$\   $$\  $$$$$$$\  $$$$$$\   $$$$$$$\ 
--  $$$$$$$$ |$$ |  $$ |$$  __$$\ $$  __$$\ $$ | \____$$\ $$  __$$\ $$  __$$ |      \$$$$$$\  $$  __$$\ $$ |  $$ |$$  _____|$$  __$$\ $$  _____|
--  $$  __$$ |$$ |  $$ |$$ /  $$ |$$ |  \__|$$ | $$$$$$$ |$$ |  $$ |$$ /  $$ |       \____$$\ $$ /  $$ |$$ |  $$ |$$ /      $$$$$$$$ |\$$$$$$\  
--  $$ |  $$ |$$ |  $$ |$$ |  $$ |$$ |      $$ |$$  __$$ |$$ |  $$ |$$ |  $$ |      $$\   $$ |$$ |  $$ |$$ |  $$ |$$ |      $$   ____| \____$$\ 
--  $$ |  $$ |\$$$$$$$ |$$$$$$$  |$$ |      $$ |\$$$$$$$ |$$ |  $$ |\$$$$$$$ |      \$$$$$$  |\$$$$$$  |\$$$$$$  |\$$$$$$$\ \$$$$$$$\ $$$$$$$  |
--  \__|  \__| \____$$ |$$  ____/ \__|      \__| \_______|\__|  \__| \_______|       \______/  \______/  \______/  \_______| \_______|\_______/ 
--            $$\   $$ |$$ |                                                                                                                    
--            \$$$$$$  |$$ |                                                                                                                    
--             \______/ \__|


require("modules.monitors")
require("modules.keybinds")
require("modules.autostart")
require("modules.env")
require("modules.aesthethics")
require("modules.layout")
require("modules.window-rules")


----------------
----  MISC  ----
----------------

hl.config({
    misc = {
        force_default_wallpaper = -1,    -- Set to 0 or 1 to disable the anime mascot wallpapers
        disable_hyprland_logo   = false, -- If true disables the random hyprland logo / anime girl background. :(
    },
})


---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout  = "us",
        kb_variant = "",
        kb_model   = "",
        kb_options = "",
        kb_rules   = "",

        follow_mouse = 1,

        sensitivity = 0, -- -1.0 - 1.0, 0 means no modification.

        touchpad = {
            natural_scroll = false,
        },
    },
})

hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace"
})

-- Example per-device config
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Devices/ for more
hl.device({
    name        = "epic-mouse-v1",
    sensitivity = -0.5,
})



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

-- Hyprland-run windowrule
hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },

    move  = "20 monitor_h-120",
    float = true,
})
