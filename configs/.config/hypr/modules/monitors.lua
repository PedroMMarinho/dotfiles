-- $$\      $$\                     $$\   $$\                                   
-- $$$\    $$$ |                    \__|  $$ |                                  
-- $$$$\  $$$$ | $$$$$$\  $$$$$$$\  $$\ $$$$$$\    $$$$$$\   $$$$$$\   $$$$$$$\ 
-- $$\$$\$$ $$ |$$  __$$\ $$  __$$\ $$ |\_$$  _|  $$  __$$\ $$  __$$\ $$  _____|
-- $$ \$$$  $$ |$$ /  $$ |$$ |  $$ |$$ |  $$ |    $$ /  $$ |$$ |  \__|\$$$$$$\  
-- $$ |\$  /$$ |$$ |  $$ |$$ |  $$ |$$ |  $$ |$$\ $$ |  $$ |$$ |       \____$$\ 
-- $$ | \_/ $$ |\$$$$$$  |$$ |  $$ |$$ |  \$$$$  |\$$$$$$  |$$ |      $$$$$$$  |
-- \__|     \__| \______/ \__|  \__|\__|   \____/  \______/ \__|      \_______/

-- See https://wiki.hypr.land/Configuring/Basics/Monitors/

-- Might not put best refresh rate
hl.monitor({
  output = "eDP-2",
  mode = "1920x1080@144",
  position = "0x0",
  scale = 1,
})

hl.monitor({
    output   = "HDMI-A-1",
    mode     = "preferred",
    position = "auto",
    scale    = 1,
})


hl.monitor({
    output   = "DP-2",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})

