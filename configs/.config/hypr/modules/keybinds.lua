--  $$\   $$\                    $$\       $$\                 $$\           
--  $$ | $$  |                   $$ |      \__|                $$ |          
--  $$ |$$  / $$$$$$\  $$\   $$\ $$$$$$$\  $$\ $$$$$$$\   $$$$$$$ | $$$$$$$\ 
--  $$$$$  / $$  __$$\ $$ |  $$ |$$  __$$\ $$ |$$  __$$\ $$  __$$ |$$  _____|
--  $$  $$<  $$$$$$$$ |$$ |  $$ |$$ |  $$ |$$ |$$ |  $$ |$$ /  $$ |\$$$$$$\  
--  $$ |\$$\ $$   ____|$$ |  $$ |$$ |  $$ |$$ |$$ |  $$ |$$ |  $$ | \____$$\ 
--  $$ | \$$\\$$$$$$$\ \$$$$$$$ |$$$$$$$  |$$ |$$ |  $$ |\$$$$$$$ |$$$$$$$  |
--  \__|  \__|\_______| \____$$ |\_______/ \__|\__|  \__| \_______|\_______/ 
--                     $$\   $$ |                                            
--                     \$$$$$$  |                                            
--                      \______/

-- https://wiki.hypr.land/Configuring/Basics/Binds/

-- Variable Source
local v = require("modules.variables")

--\\\\\\\\\\\\\\\////////////--
--           APPS            --
--\\\\\\\\\\\\\\\////////////--

-- Launch ROFI for wallpaper selection
-- hl.bind(v.mainMod .. " + W", hl.dsp.exec_cmd(v.scriptsDir .. "/WallpaperSelect.sh")) TODO

-- Launch Default Applications
hl.bind(v.mainMod .. " + Q", hl.dsp.exec_cmd(v.terminal .. " -e --hold fastfetch"))
hl.bind(v.mainMod .. " + E", hl.dsp.exec_cmd(v.fileManager))
hl.bind(v.mainMod .. " + SHIFT + E", hl.dsp.exec_cmd(v.fileManagert))
hl.bind(v.mainMod .. " + B", hl.dsp.exec_cmd(v.browser))
hl.bind(v.mainMod .. " + D", hl.dsp.exec_cmd("pkill rofi || true && " .. v.menu .. " -modi drun,filebrowser,run,window"))
hl.bind(v.mainMod .. " + T", hl.dsp.exec_cmd(v.textEditor))

--\\\\\\\\\\\\\\\////////////--
--        FUNCTIONS          --
--\\\\\\\\\\\\\\\////////////--

hl.bind("CTRL + ALT + Delete", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"))
hl.bind(v.mainMod .. " + C", hl.dsp.window.close())
hl.bind(v.mainMod .. " + SHIFT + C", hl.dsp.window.kill())
hl.bind(v.mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind(v.mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
hl.bind(v.mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(v.mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(v.mainMod .. " + J", hl.dsp.layout("togglesplit"))
hl.bind(v.mainMod .. " + SPACE", hl.dsp.exec_cmd(v.scriptsDir .. "/Keyboard.sh"))  
-- TODO
-- hl.bind(v.mainMod .. " + L", hl.dsp.exec_cmd(v.scriptsDir .. "/LockScreen.sh"))
-- hl.bind(v.mainMod .. " + X", hl.dsp.exec_cmd(v.scriptsDir .. "/Wlogout.sh"))
-- hl.bind(v.mainMod .. " + CTRL + B", hl.dsp.exec_cmd(v.scriptsDir .. "/WaybarStyles.sh"))
-- hl.bind(v.mainMod .. " + ALT + B", hl.dsp.exec_cmd(v.scriptsDir .. "/WaybarLayout.sh"))
-- hl.bind(v.mainMod .. " + ALT + E", hl.dsp.exec_cmd(v.scriptsDir .. "/RofiEmoji.sh"))

--\\\\\\\\\\\\\\\////////////--
--        SCREENSHOTS        --
--\\\\\\\\\\\\\\\////////////--

hl.bind(v.mainMod .. " + SHIFT + S", hl.dsp.exec_cmd(v.scriptsDir .. "/Screenshot.sh --area"))
hl.bind(v.mainMod .. " + SHIFT + O", hl.dsp.exec_cmd(v.scriptsDir .. "/Screenshot.sh --now"))
hl.bind(v.mainMod .. " + SHIFT + W", hl.dsp.exec_cmd(v.scriptsDir .. "/Screenshot.sh --active"))
    
--\\\\\\\\\\\\\\\////////////--
--        WINDOW FOCUS       --
--\\\\\\\\\\\\\\\////////////--

hl.bind(v.mainMod .. " + left", hl.dsp.focus({ direction = "l" }))
hl.bind(v.mainMod .. " + right", hl.dsp.focus({ direction = "r" }))
hl.bind(v.mainMod .. " + up", hl.dsp.focus({ direction = "u" }))
hl.bind(v.mainMod .. " + down", hl.dsp.focus({ direction = "d" }))

--\\\\\\\\\\\\\\\\\\\\\\\//////////////////////--
--        WINDOW MOVEMENT (Same Workspace)     --
--\\\\\\\\\\\\\\\\\\\\\\\//////////////////////--

hl.bind(v.mainMod .. " + SHIFT + left", hl.dsp.window.move({ direction = "l" }))
hl.bind(v.mainMod .. " + SHIFT + right", hl.dsp.window.move({ direction = "r" }))
hl.bind(v.mainMod .. " + SHIFT + up", hl.dsp.window.move({ direction = "u" }))
hl.bind(v.mainMod .. " + SHIFT + down", hl.dsp.window.move({ direction = "d" }))

--\\\\\\\\\\\\\\\////////////--
--  WORKSPACE/MOVES SCROLL   --
--\\\\\\\\\\\\\\\////////////--

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(v.mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(v.mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + SHIFT + [0-9]
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(v.mainMod .. " + " .. key,             hl.dsp.focus({ workspace = i}))
    hl.bind(v.mainMod .. " + SHIFT + " .. key,     hl.dsp.window.move({ workspace = i }))
end

--\\\\\\\\\\\\\\\\\\\////////////--
--     FLOATING WINDOW RESIZING  --
--\\\\\\\\\\\\\\\\\\\////////////--

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(v.mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(v.mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

--\\\\\\\\\\\\\\\////////////--
--        AUDIO CONTROL      --
--\\\\\\\\\\\\\\\////////////--

-- Requires playerctl
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

--\\\\\\\\\\\\\\\\////////////--
--        MULTIMEDIA KEYS     --
--\\\\\\\\\\\\\\\\////////////--

-- Laptop multimedia keys for volume and LCD brightness
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true })
