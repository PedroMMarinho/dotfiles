
--   $$$$$$\              $$\                           $$\                          $$\     
--  $$  __$$\             $$ |                          $$ |                         $$ |    
--  $$ /  $$ |$$\   $$\ $$$$$$\    $$$$$$\   $$$$$$$\ $$$$$$\    $$$$$$\   $$$$$$\ $$$$$$\   
--  $$$$$$$$ |$$ |  $$ |\_$$  _|  $$  __$$\ $$  _____|\_$$  _|   \____$$\ $$  __$$\\_$$  _|  
--  $$  __$$ |$$ |  $$ |  $$ |    $$ /  $$ |\$$$$$$\    $$ |     $$$$$$$ |$$ |  \__| $$ |    
--  $$ |  $$ |$$ |  $$ |  $$ |$$\ $$ |  $$ | \____$$\   $$ |$$\ $$  __$$ |$$ |       $$ |$$\ 
--  $$ |  $$ |\$$$$$$  |  \$$$$  |\$$$$$$  |$$$$$$$  |  \$$$$  |\$$$$$$$ |$$ |       \$$$$  |
--  \__|  \__| \______/    \____/  \______/ \_______/    \____/  \_______|\__|        \____/

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/


hl.on("hyprland.start", function ()
  hl.exec_cmd("nm-applet")
  hl.exec_cmd("blueman-applet") 
  hl.exec_cmd("waybar")
  hl.exec_cmd("clipse -listen") -- Copy and Paste for Images
  hl.exec_cmd("fcitx5 -d") -- Mandarin Input Method
  hl.exec_cmd("awww-daemon") 
  hl.exec_cmd("systemctl --user start hyprpolkitagent")
  hl.exec_cmd("qs")
end)