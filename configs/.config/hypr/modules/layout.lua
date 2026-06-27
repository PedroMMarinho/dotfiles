-- $$\                                                $$\     
-- $$ |                                               $$ |    
-- $$ |      $$$$$$\  $$\   $$\  $$$$$$\  $$\   $$\ $$$$$$\   
-- $$ |      \____$$\ $$ |  $$ |$$  __$$\ $$ |  $$ |\_$$  _|  
-- $$ |      $$$$$$$ |$$ |  $$ |$$ /  $$ |$$ |  $$ |  $$ |    
-- $$ |     $$  __$$ |$$ |  $$ |$$ |  $$ |$$ |  $$ |  $$ |$$\ 
-- $$$$$$$$\\$$$$$$$ |\$$$$$$$ |\$$$$$$  |\$$$$$$  |  \$$$$  |
-- \________|\_______| \____$$ | \______/  \______/    \____/ 
--                    $$\   $$ |                              
--                    \$$$$$$  |                              
--                     \______/                               


-- See https://wiki.hypr.land/Configuring/Layouts/Dwindle-Layout/ for more
hl.config({
    general = {
        layout = "dwindle",
    },

    dwindle = {
        preserve_split = true,
    },
})

-- See https://wiki.hypr.land/Configuring/Layouts/Master-Layout/ for more
hl.config({
    master = {
        new_status = "master",
    },
})

-- See https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/ for more
hl.config({
    scrolling = {
        fullscreen_on_one_column = true,
    },
})