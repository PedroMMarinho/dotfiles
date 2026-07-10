--  $$\      $$\ $$\                 $$\                               $$$$$$$\            $$\                     
--  $$ | $\  $$ |\__|                $$ |                              $$  __$$\           $$ |                    
--  $$ |$$$\ $$ |$$\ $$$$$$$\   $$$$$$$ | $$$$$$\  $$\  $$\  $$\       $$ |  $$ |$$\   $$\ $$ | $$$$$$\   $$$$$$$\ 
--  $$ $$ $$\$$ |$$ |$$  __$$\ $$  __$$ |$$  __$$\ $$ | $$ | $$ |      $$$$$$$  |$$ |  $$ |$$ |$$  __$$\ $$  _____|
--  $$$$  _$$$$ |$$ |$$ |  $$ |$$ /  $$ |$$ /  $$ |$$ | $$ | $$ |      $$  __$$< $$ |  $$ |$$ |$$$$$$$$ |\$$$$$$\  
--  $$$  / \$$$ |$$ |$$ |  $$ |$$ |  $$ |$$ |  $$ |$$ | $$ | $$ |      $$ |  $$ |$$ |  $$ |$$ |$$   ____| \____$$\ 
--  $$  /   \$$ |$$ |$$ |  $$ |\$$$$$$$ |\$$$$$$  |\$$$$$\$$$$  |      $$ |  $$ |\$$$$$$  |$$ |\$$$$$$$\ $$$$$$$  |
--  \__/     \__|\__|\__|  \__| \_______| \______/  \_____\____/       \__|  \__| \______/ \__| \_______|\_______/

-- TODO

-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- and https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/

-- Example window rules that are useful

hl.window_rule({
    -- Ignore maximize requests from all apps. You'll probably like this.
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
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

-- Hyprland-run windowrule
hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },

    move  = "20 monitor_h-120",
    float = true,
})

-- Floating kitty launched from the bar icon: fixed size, centered
hl.window_rule({
    name  = "float-bar-kitty",
    match = { class = "kitty-float" },

    float  = true,
    size   = "(monitor_w*0.56) (monitor_h*0.5)",
    center = true,
})

-- Blur the Quickshell power-menu layer so the frosted panel reads as real glass.
hl.layer_rule({
    name         = "power-menu-blur",
    match        = { namespace = "^shell:power$" },
    blur         = true,
    ignore_alpha = 0.2,
})
