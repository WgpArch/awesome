local gears = require("gears")
local theme = {}
theme.systray_icon_size = 10

-- Wallpaper
theme.wallpaper = "/home/wgparch/Pictures/ALNW/Trainsatation.jpg"

-- Colors 
theme.bg_normal  = "#3E2723" 
theme.bg_focus   = "#C9B8A4" 
theme.bg_urgent  = "#ef5350"
theme.bg_minimize = "#5D4037"

theme.fg_normal  = "#FFE0B2" 
theme.fg_focus   = "#3E2723" 
theme.fg_urgent  = "#ffffff"
theme.fg_minimize = "#8D6E63"

-- Borders
theme.border_width  = 2
theme.border_normal = "#C9B8A4"
theme.border_focus  = "#FFD54F" 
theme.border_marked = "#FFC107"

-- Font
theme.font = "Z003 12"

-- Menu
theme.menu_height = 28
theme.menu_width  = 200
theme.menu_bg_normal = "#3E2723" 
theme.menu_fg_normal = "#FFD54F"
theme.menu_bg_focus  = "#C9B8A4" 
theme.menu_fg_focus  = "#3E2723" 
theme.menu_border_width = 1
theme.menu_border_color = "#C9B8A4"

-- Wibar (Top Bar)
theme.wibar_bg = "#3E2723"
theme.wibar_fg = "#FFE0B2"

-- Taglist (Inline numbers)
theme.taglist_fg_empty = "#8D6E63"   
theme.taglist_fg_occupied = "#FFD54F" 
theme.taglist_fg_focus = "#3E2723"   
theme.taglist_fg_urgent = "#ffffff"

-- Taglist backgrounds
theme.taglist_bg_empty = beautiful.bg_normal
theme.taglist_bg_occupied = beautiful.bg_normal
theme.taglist_bg_urgent = beautiful.bg_urgent
theme.taglist_bg_focus = beautiful.bg_focus

-- Notifications
theme.notification_bg = "#3E2723"
theme.notification_fg = "#FFE0B2"
theme.notification_border_width = 1
theme.notification_border_color = "#C9B8A4"

return theme
