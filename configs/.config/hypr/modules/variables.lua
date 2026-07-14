--  $$\    $$\                    $$\           $$\       $$\                     
--  $$ |   $$ |                   \__|          $$ |      $$ |                    
--  $$ |   $$ |$$$$$$\   $$$$$$\  $$\  $$$$$$\  $$$$$$$\  $$ | $$$$$$\   $$$$$$$\ 
--  \$$\  $$  |\____$$\ $$  __$$\ $$ | \____$$\ $$  __$$\ $$ |$$  __$$\ $$  _____|
--   \$$\$$  / $$$$$$$ |$$ |  \__|$$ | $$$$$$$ |$$ |  $$ |$$ |$$$$$$$$ |\$$$$$$\  
--    \$$$  / $$  __$$ |$$ |      $$ |$$  __$$ |$$ |  $$ |$$ |$$   ____| \____$$\ 
--     \$  /  \$$$$$$$ |$$ |      $$ |\$$$$$$$ |$$$$$$$  |$$ |\$$$$$$$\ $$$$$$$  |
--      \_/    \_______|\__|      \__| \_______|\_______/ \__| \_______|\_______/

-- https://wiki.hypr.land/Configuring/Basics/Variables/

local v = {}

-- \\\\\\\\\\\\\\\///////////// --
--        SUPER KEY             --
-- \\\\\\\\\\\\\\\///////////// --

v.mainMod = "SUPER"

-- \\\\\\\\\\\\\\\///////////// --
--        DEFAULT APPS          --
-- \\\\\\\\\\\\\\\///////////// --

v.terminal = "kitty"                                       -- Terminal application
v.browser = "google-chrome-stable"                                -- Web browser
v.fileManager = "nautilus -w"                                  -- File manager
v.menu = "rofi -show drun" 
v.menu_v2 = "qs ipc call launcher open"                                -- Application launcher
v.textEditor = "code"                                      -- Text editor
-- v.notes = "your_notes_app"                              -- Notes application

-- Stitching variables together using '..'
v.fileManagert = v.terminal .. " yazi"                       -- File manager terminal

-- \\\\\\\\\\\\\\\///////////// --
--        DIRECTORIES           --
-- \\\\\\\\\\\\\\\///////////// --

local home = os.getenv("HOME")
v.wallpapersDir = home .. "/.config/hypr/images/wallpapers"
v.scriptsDir = home .. "/.config/hypr/scripts"

return v