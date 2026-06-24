-- If LuaRocks is installed, make sure that packages installed through it are
-- found (e.g. lgi). If LuaRocks is not installed, do nothing.
pcall(require, "luarocks.loader")

-- Standard awesome library
local gears = require("gears")
local awful = require("awful")
require("awful.autofocus")
-- Widget and layout library
local wibox = require("wibox")
-- Theme handling library
local beautiful = require("beautiful")
-- Notification library
local naughty = require("naughty")
local menubar = require("menubar")
local hotkeys_popup = require("awful.hotkeys_popup")
-- Enable hotkeys help widget for VIM and other apps
-- when client with a matching name is opened:
require("awful.hotkeys_popup.keys")

-- {{{ Error handling
-- Check if awesome encountered an error during startup and fell back to
-- another config (This code will only ever execute for the fallback config)
if awesome.startup_errors then
    naughty.notify({ preset = naughty.config.presets.critical,
                     title = "Oops, there were errors during startup!",
                     text = awesome.startup_errors })
end

-- Handle runtime errors after startup
do
    local in_error = false
    awesome.connect_signal("debug::error", function (err)
        -- Make sure we don't go into an endless error loop
        if in_error then return end
        in_error = true

        naughty.notify({ preset = naughty.config.presets.critical,
                         title = "Oops, an error happened!",
                         text = tostring(err) })
        in_error = false
    end)
end
-- }}}

-- {{{ Variable definitions
-- Themes define colours, icons, font and wallpapers.
beautiful.init(os.getenv("HOME") .. "/.config/awesome/train-station/theme.lua")

-- ==========================================
-- Custom Network Widget (Replaces nm-applet)
-- ==========================================
local network_widget = wibox.widget.textbox(" 🌐 --")
network_widget:set_font("Z003 14")

-- Function to update network status
local function update_network_status()
    local handle = io.popen("nmcli -t -f TYPE,STATE device | grep connected | grep -v loopback")
    if not handle then 
        network_widget:set_text(" ⚠️ Down")
        return 
    end
    
    local result = handle:read("*a")
    handle:close()
    
    if result == "" then
        network_widget:set_text(" 📡 Disconnected")
    else
        local conn_type = result:match("([^:]+):connected")
        
        if conn_type == "wifi" then
            local ssid_handle = io.popen("nmcli -t -f ACTIVE,SSID dev wifi | grep '^yes' | cut -d':' -f2-")
            local ssid = ssid_handle:read("*l") or "Unknown"
            ssid_handle:close()
            network_widget:set_text(" 📶 " .. ssid)
        elseif conn_type == "ethernet" then
            network_widget:set_text(" 🔌 Wired")
        else
            network_widget:set_text(" 🌐 " .. conn_type)
        end
    end
end

-- Update every 10 seconds
local network_timer = gears.timer {
    timeout   = 10,
    call_now  = true,
    autostart = true,
    callback  = function()
        update_network_status()
    end
}

-- Add menus and click actions (SAFE VERSION)
network_widget:buttons(gears.table.join(
    awful.button({}, 3, function()
        local net_menu = awful.menu({
            items = {
                { "🔄 Rescan Networks", function() awful.spawn("nmcli device wifi rescan") end },
                { "📶 Turn Wi-Fi ON", function() awful.spawn("nmcli radio wifi on") end },
                { " Turn Wi-Fi OFF", function() awful.spawn("nmcli radio wifi off") end },
                { "⚙️ Network Settings", function() awful.spawn("nm-connection-editor") end },
            }
        })
        net_menu:show()
    end),
    awful.button({}, 1, function()
        update_network_status()
    end)
))

-- Add menus and click actions
network_widget:buttons(gears.table.join(
    -- Right-click: Open Network Management Menu
    awful.button({}, 3, function()
        local net_menu = awful.menu({
            items = {
                { "🔄 Refresh Internet", function() awful.spawn("nmcli networking off && sleep 2 && nmcli networking on") end },
                { "📶 Toggle Wi-Fi", function() awful.spawn("nmcli radio wifi toggle") end },
                { "⚙️ Network Settings", function() awful.spawn("nm-connection-editor") end },
            }
        })
        net_menu:show()
    end),
    -- Left-click: Manually refresh the widget display
    awful.button({}, 1, function()
        update_network_status()
    end)
))

-- ==========================================
-- CPU Usage Widget
-- ==========================================
local cpu_widget = wibox.widget.textbox(" 💻 --%")
cpu_widget:set_font("Z003 14")

local function update_cpu_usage()
    local handle = io.popen("top -bn1 | grep 'Cpu(s)' | awk '{print $2}' | cut -d'%' -f1")
    if handle then
        local cpu_usage = handle:read("*a")
        handle:close()
        cpu_usage = cpu_usage:gsub("^%s*(.-)%s*$", "%1")
        if cpu_usage ~= "" then
            cpu_widget:set_text(" 💻 " .. cpu_usage .. "%")
        else
            cpu_widget:set_text(" 💻 --%")
        end
    end
end

local cpu_timer = gears.timer {
    timeout   = 5,
    call_now  = true,
    autostart = true,
    callback  = function()
        update_cpu_usage()
    end
}

-- ==========================================
-- Memory Usage Widget
-- ==========================================
local memory_widget = wibox.widget.textbox(" 🧠 --%")
memory_widget:set_font("Z003 14")

local function update_memory_usage()
    local handle = io.popen("free | grep Mem | awk '{printf(\"%.0f\", $3/$2 * 100.0)}'")
    if handle then
        local mem_usage = handle:read("*a")
        handle:close()
        mem_usage = mem_usage:gsub("^%s*(.-)%s*$", "%1")
        if mem_usage ~= "" then
            memory_widget:set_text(" 🧠 " .. mem_usage .. "%")
        else
            memory_widget:set_text(" 🧠 --%")
        end
    end
end

local memory_timer = gears.timer {
    timeout   = 5,
    call_now  = true,
    autostart = true,
    callback  = function()
        update_memory_usage()
    end
}

-- ==========================================
-- CPU Temperature Widget
-- ==========================================
local temp_widget = wibox.widget.textbox(" 🌡️ --°C")
temp_widget:set_font("Z003 14")

local function update_cpu_temp()
    -- Try to get CPU temperature using sensors
    local handle = io.popen("sensors | grep 'Tctl\\|Core 0\\|Package id 0' | head -1 | awk '{print $4}' | tr -d '+°C'")
    if handle then
        local temp = handle:read("*a")
        handle:close()
        temp = temp:gsub("^%s*(.-)%s*$", "%1")
        if temp ~= "" and temp ~= "N/A" then
            temp_widget:set_text(" 🌡️ " .. temp .. "°C")
        else
            -- Fallback: try reading from thermal zone
            local handle2 = io.popen("cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null")
            if handle2 then
                local temp_raw = handle2:read("*a")
                handle2:close()
                temp_raw = temp_raw:gsub("^%s*(.-)%s*$", "%1")
                if temp_raw ~= "" then
                    local temp_c = math.floor(temp_raw / 1000)
                    temp_widget:set_text(" 🌡️ " .. temp_c .. "°C")
                else
                    temp_widget:set_text(" 🌡️ --°C")
                end
            else
                temp_widget:set_text(" 🌡️ --°C")
            end
        end
    end
end

local temp_timer = gears.timer {
    timeout   = 10,
    call_now  = true,
    autostart = true,
    callback  = function()
        update_cpu_temp()
    end
}

-- This is used later as the default terminal and editor to run.
terminal = "xterm"
editor = os.getenv("EDITOR") or "nano"
editor_cmd = terminal .. " -e " .. editor

-- Default modkey.
-- Usually, Mod4 is the key with a logo between Control and Alt.
-- If you do not like this or do not have such a key,
-- I suggest you to remap Mod4 to another key using xmodmap or other tools.
-- However, you can use another modifier like Mod1, but it may interact with others.
modkey = "Mod4"

-- Table of layouts to cover with awful.layout.inc, order matters.
awful.layout.layouts = {
    awful.layout.suit.floating,
    awful.layout.suit.tile,
    awful.layout.suit.tile.left,
    awful.layout.suit.tile.bottom,
    awful.layout.suit.tile.top,
    awful.layout.suit.fair,
    awful.layout.suit.fair.horizontal,
    awful.layout.suit.spiral,
    awful.layout.suit.spiral.dwindle,
    awful.layout.suit.max,
    awful.layout.suit.max.fullscreen,
    awful.layout.suit.magnifier,
    awful.layout.suit.corner.nw,
    -- awful.layout.suit.corner.ne,
    -- awful.layout.suit.corner.sw,
    -- awful.layout.suit.corner.se,
}
-- }}}

-- {{{ Menu
-- Create a launcher widget and a main menu
myawesomemenu = {
   { "hotkeys", function() hotkeys_popup.show_help(nil, awful.screen.focused()) end },
   { "manual", terminal .. " -e man awesome" },
   { "edit config", editor_cmd .. " " .. awesome.conffile },
   { "restart", awesome.restart },
   { "quit", function() awesome.quit() end },
}

mymainmenu = awful.menu({ items = { { "awesome", myawesomemenu, beautiful.awesome_icon },
                                    { "open terminal", terminal }
                                  }
                        })

mylauncher = awful.widget.launcher({ image = beautiful.awesome_icon,
                                     menu = mymainmenu })

-- Menubar configuration
menubar.utils.terminal = terminal -- Set the terminal for applications that require it
-- }}}

-- Keyboard map indicator and switcher
mykeyboardlayout = awful.widget.keyboardlayout()

-- Create weather widget
local weather_text = wibox.widget.textbox(" ️ --°")
weather_text:set_font("Z003 11")  

local weather_widget = wibox.container.margin(weather_text, 10, 10, 0, 0)

-- Update weather every 5 minutes
local weather_timer = gears.timer {
    timeout   = 300,
    call_now  = true,
    autostart = true,
    callback  = function()
        -- Use jq to extract ONLY the "text" part from your Python script's JSON output
        local cmd = os.getenv("HOME") .. "/.config/awesome/rofi/weather.py | jq -r '.text'"
        local handle = io.popen(cmd)
        if handle then
            local result = handle:read("*a")
            handle:close()
            
            -- Clean up any extra spaces or newlines
            result = result:gsub("^%s*(.-)%s*$", "%1")
            
            if result ~= "" and result ~= "null" then
                weather_text:set_text(result)
                weather_text:set_font("Z003 11")
            else
                weather_text:set_text(" 🌤️ --°")
            end
        end
    end
}

-- {{{ Wibar
-- Create a textclock widget with proper format
mytextclock = wibox.widget.textclock("%a %d %b %Y %H:%M:%S %p", 1)
mytextclock:set_font("Z003 11")

-- Create a wibox for each screen and add it
local taglist_buttons = gears.table.join(
                    awful.button({ }, 1, function(t) t:view_only() end),
                    awful.button({ modkey }, 1, function(t)
                                              if client.focus then
                                                  client.focus:move_to_tag(t)
                                              end
                                          end),
                    awful.button({ }, 3, awful.tag.viewtoggle),
                    awful.button({ modkey }, 3, function(t)
                                              if client.focus then
                                                  client.focus:toggle_tag(t)
                                              end
                                          end),
                    awful.button({ }, 4, function(t) awful.tag.viewnext(t.screen) end),
                    awful.button({ }, 5, function(t) awful.tag.viewprev(t.screen) end)
                )

local tasklist_buttons = gears.table.join(
                     awful.button({ }, 1, function (c)
                                              if c == client.focus then
                                                  c.minimized = true
                                              else
                                                  c:emit_signal(
                                                      "request::activate",
                                                      "tasklist",
                                                      {raise = true}
                                                  )
                                              end
                                          end),
                     awful.button({ }, 3, function()
                                              awful.menu.client_list({ theme = { width = 250 } })
                                          end),
                     awful.button({ }, 4, function ()
                                              awful.client.focus.byidx(1)
                                          end),
                     awful.button({ }, 5, function ()
                                              awful.client.focus.byidx(-1)
                                          end))

local function set_wallpaper(s)
    -- Wallpaper
    if beautiful.wallpaper then
        local wallpaper = beautiful.wallpaper
        -- If wallpaper is a function, call it with the screen
        if type(wallpaper) == "function" then
            wallpaper = wallpaper(s)
        end
        gears.wallpaper.maximized(wallpaper, s, true)
    end
end

-- Re-set wallpaper when a screen's geometry changes (e.g. different resolution)
screen.connect_signal("property::geometry", set_wallpaper)

awful.screen.connect_for_each_screen(function(s)
    -- Wallpaper    
    set_wallpaper(s)
    
    -- Force wallpaper directly
    gears.wallpaper.maximized("/home/wgparch/Pictures/ALNW/Trainstation.jpg", s, true)
    
    -- Each screen has its own tag table.
    awful.tag({ "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11" }, s, awful.layout.layouts[1])

    -- Create a promptbox for each screen
    s.mypromptbox = awful.widget.prompt()
    
    -- Create an imagebox widget which will contain an icon indicating which layout we're using.
    s.mylayoutbox = awful.widget.layoutbox(s)
    s.mylayoutbox:buttons(gears.table.join(
                           awful.button({ }, 1, function () awful.layout.inc( 1) end),
                           awful.button({ }, 3, function () awful.layout.inc(-1) end),
                           awful.button({ }, 4, function () awful.layout.inc( 1) end),
                           awful.button({ }, 5, function () awful.layout.inc(-1) end)))

    -- Create a taglist widget 
        -- Create a taglist widget 
    s.mytaglist = awful.widget.taglist {
        screen  = s,
        filter  = awful.widget.taglist.filter.all,
        buttons = taglist_buttons,
        widget_template = {
            {
                {
                    id     = "text_role",
                    widget = wibox.widget.textbox,
                    font   = "Z003 11", 
                },
                left  = 8,
                right = 8,
                widget = wibox.container.margin,
            },
            id     = "background_role",
            widget = wibox.container.background,
        },
    }

    -- Create a tasklist widget
    s.mytasklist = awful.widget.tasklist {
        screen  = s,
        filter  = awful.widget.tasklist.filter.currenttags,
        buttons = tasklist_buttons
    }

    -- Create the wibox
    s.mywibox = awful.wibar({ 
        position = "top", 
        screen = s,
        height = 34,
        bg = "#190e03",
        fg = "#C9B8A4",
        border_width = 2,
        border_color = "#C9B8A4",
    })

    -- Add widgets to the wibox
    -- 1. Create a Launcher Button with Arch Logo and Rofi
       local my_launcher_btn = wibox.widget.textbox("  ")
       my_launcher_btn:set_font("Sans Bold 15")
       my_launcher_btn:buttons(gears.table.join(
       awful.button({}, 1, function()
       awful.spawn("rofi -show drun -show-icons -theme ~/.config/awesome/rofi/Monokai.rasi")
        end)
    ))

    -- 2. Create a Weather Placeholder
    local my_weather = wibox.widget.textbox(" 🌤️ Weather ")

    -- 3. Create a Power Button
       local my_power_btn = wibox.widget.textbox(" ⏻ ")
       my_power_btn:set_font("Sans Bold 15")
       my_power_btn:buttons(gears.table.join(
       awful.button({}, 1, function()
       awful.spawn.with_shell(os.getenv("HOME") .. "/.config/awesome/rofi/powermenu.sh")
        end)
    ))

    -- Setup the Wibox
    s.mywibox:setup {
        layout = wibox.layout.align.horizontal,
        { -- Left widgets: Launcher + Tags
            layout = wibox.layout.fixed.horizontal,
            wibox.container.margin(my_launcher_btn, 10, 10, 0, 0),
            s.mytaglist,
            s.mypromptbox,
        },
       { -- Center widgets: Clock + Weather
            layout = wibox.layout.fixed.horizontal,
            wibox.container.margin(mytextclock, 200, 15, 0, 0),
            weather_widget,  -- Use the container directly
        },
       { -- Right widgets: Network + CPU + RAM + Temp + Systray + Power
            layout = wibox.layout.fixed.horizontal,
            wibox.container.margin(network_widget, 0, 5, 0, 0),
            wibox.container.margin(cpu_widget, 0, 5, 0, 0),
            wibox.container.margin(memory_widget, 0, 5, 0, 0),
            wibox.container.margin(temp_widget, 0, 10, 0, 0),
            wibox.widget.systray(),
            wibox.container.margin(my_power_btn, 10, 10, 0, 0),
        },
    }
end)

-- }}}

-- {{{ Mouse bindings
root.buttons(gears.table.join(
    awful.button({ }, 3, function () mymainmenu:toggle() end),
    awful.button({ }, 4, awful.tag.viewnext),
    awful.button({ }, 5, awful.tag.viewprev)
))
-- }}}

-- {{{ Key bindings
globalkeys = gears.table.join(
    awful.key({ modkey,           }, "s",      hotkeys_popup.show_help,
              {description="show help", group="awesome"}),
    awful.key({ modkey,           }, "Left",   awful.tag.viewprev,
              {description = "view previous", group = "tag"}),
    awful.key({ modkey,           }, "Right",  awful.tag.viewnext,
              {description = "view next", group = "tag"}),
    awful.key({ modkey,           }, "Escape", awful.tag.history.restore,
              {description = "go back", group = "tag"}),

    awful.key({ modkey,           }, "j",
        function ()
            awful.client.focus.byidx( 1)
        end,
        {description = "focus next by index", group = "client"}
    ),
    awful.key({ modkey,           }, "k",
        function ()
            awful.client.focus.byidx(-1)
        end,
        {description = "focus previous by index", group = "client"}
    ),
    awful.key({ modkey,           }, "w", function () mymainmenu:show() end,
              {description = "show main menu", group = "awesome"}),
    -- ==========================================
    -- Screenshot Keybindings (Using 'p' for Picture)
    -- ==========================================
    
    -- 1. Immediate Full Screen (Mod + p)
    awful.key({ modkey }, "p",
        function ()
            os.execute("mkdir -p /home/wgparch/Pictures/Screenshots/awesome")
            local filename = "/home/wgparch/Pictures/Screenshots/awesome/screenshot_" .. os.date("%Y-%m-%d_%H-%M-%S") .. ".png"
            awful.spawn({"scrot", filename})
            naughty.notify({ title = "Screenshot", text = "Saved!", timeout = 2 })
        end,
        {description = "immediate screenshot", group = "hotkeys"}),

    -- 2. Delayed Screenshot for Menus (Mod + Shift + p)
    awful.key({ modkey, "Shift" }, "p",
        function ()
            naughty.notify({ title = "Screenshot", text = "Get your menu ready! 3 seconds...", timeout = 3 })
            awful.spawn.with_shell("sleep 3 && scrot /home/wgparch/Pictures/Screenshots/awesome/menu_" .. os.date("%Y-%m-%d_%H-%M-%S") .. ".png")
        end,
        {description = "screenshot with 3s delay", group = "hotkeys"}),

    -- Layout manipulation
    awful.key({ modkey, "Shift"   }, "j", function () awful.client.swap.byidx(  1)    end,
              {description = "swap with next client by index", group = "client"}),
    awful.key({ modkey, "Shift"   }, "k", function () awful.client.swap.byidx( -1)    end,
              {description = "swap with previous client by index", group = "client"}),
    awful.key({ modkey, "Control" }, "j", function () awful.screen.focus_relative( 1) end,
              {description = "focus the next screen", group = "screen"}),
    awful.key({ modkey, "Control" }, "k", function () awful.screen.focus_relative(-1) end,
              {description = "focus the previous screen", group = "screen"}),
    awful.key({ modkey,           }, "u", awful.client.urgent.jumpto,
              {description = "jump to urgent client", group = "client"}),
    awful.key({ modkey,           }, "Tab",
        function ()
            awful.client.focus.history.previous()
            if client.focus then
                client.focus:raise()
            end
        end,
        {description = "go back", group = "client"}),

    -- Standard program
    awful.key({ modkey,           }, "Return", function () awful.spawn(terminal) end,
              {description = "open a terminal", group = "launcher"}),
    awful.key({ modkey, "Control" }, "r", awesome.restart,
              {description = "reload awesome", group = "awesome"}),
    awful.key({ modkey, "Shift"   }, "q", awesome.quit,
              {description = "quit awesome", group = "awesome"}),

    awful.key({ modkey,           }, "l",     function () awful.tag.incmwfact( 0.05)          end,
              {description = "increase master width factor", group = "layout"}),
    awful.key({ modkey,           }, "h",     function () awful.tag.incmwfact(-0.05)          end,
              {description = "decrease master width factor", group = "layout"}),
    awful.key({ modkey, "Shift"   }, "h",     function () awful.tag.incnmaster( 1, nil, true) end,
              {description = "increase the number of master clients", group = "layout"}),
    awful.key({ modkey, "Shift"   }, "l",     function () awful.tag.incnmaster(-1, nil, true) end,
              {description = "decrease the number of master clients", group = "layout"}),
    awful.key({ modkey, "Control" }, "h",     function () awful.tag.incncol( 1, nil, true)    end,
              {description = "increase the number of columns", group = "layout"}),
    awful.key({ modkey, "Control" }, "l",     function () awful.tag.incncol(-1, nil, true)    end,
              {description = "decrease the number of columns", group = "layout"}),
    awful.key({ modkey,           }, "space", function () awful.layout.inc( 1)                end,
              {description = "select next", group = "layout"}),
    awful.key({ modkey, "Shift"   }, "space", function () awful.layout.inc(-1)                end,
              {description = "select previous", group = "layout"}),

    awful.key({ modkey, "Control" }, "n",
              function ()
                  local c = awful.client.restore()
                  -- Focus restored client
                  if c then
                    c:emit_signal(
                        "request::activate", "key.unminimize", {raise = true}
                    )
                  end
              end,
              {description = "restore minimized", group = "client"}),

    -- Prompt
    awful.key({ modkey },            "r",     function () awful.screen.focused().mypromptbox:run() end,
              {description = "run prompt", group = "launcher"}),

    awful.key({ modkey }, "x",
              function ()
                  awful.prompt.run {
                    prompt       = "Run Lua code: ",
                    textbox      = awful.screen.focused().mypromptbox.widget,
                    exe_callback = awful.util.eval,
                    history_path = awful.util.get_cache_dir() .. "/history_eval"
                  }
              end,
              {description = "lua execute prompt", group = "awesome"}),
    -- Menubar
    awful.key({ modkey }, "p", function() menubar.show() end,
              {description = "show the menubar", group = "launcher"})
)

clientkeys = gears.table.join(
    awful.key({ modkey,           }, "f",
        function (c)
            c.fullscreen = not c.fullscreen
            c:raise()
        end,
        {description = "toggle fullscreen", group = "client"}),
    awful.key({ modkey, "Shift"   }, "c",      function (c) c:kill()                         end,
              {description = "close", group = "client"}),
    awful.key({ modkey, "Control" }, "space",  awful.client.floating.toggle                     ,
              {description = "toggle floating", group = "client"}),
    awful.key({ modkey, "Control" }, "Return", function (c) c:swap(awful.client.getmaster()) end,
              {description = "move to master", group = "client"}),
    awful.key({ modkey,           }, "o",      function (c) c:move_to_screen()               end,
              {description = "move to screen", group = "client"}),
    awful.key({ modkey,           }, "t",      function (c) c.ontop = not c.ontop            end,
              {description = "toggle keep on top", group = "client"}),
    awful.key({ modkey,           }, "n",
        function (c)
            -- The client currently has the input focus, so it cannot be
            -- minimized, since minimized clients can't have the focus.
            c.minimized = true
        end ,
        {description = "minimize", group = "client"}),
    awful.key({ modkey,           }, "m",
        function (c)
            c.maximized = not c.maximized
            c:raise()
        end ,
        {description = "(un)maximize", group = "client"}),
    awful.key({ modkey, "Control" }, "m",
        function (c)
            c.maximized_vertical = not c.maximized_vertical
            c:raise()
        end ,
        {description = "(un)maximize vertically", group = "client"}),
    awful.key({ modkey, "Shift"   }, "m",
        function (c)
            c.maximized_horizontal = not c.maximized_horizontal
            c:raise()
        end ,
        {description = "(un)maximize horizontally", group = "client"})
)

-- Bind all key numbers to tags.
-- Be careful: we use keycodes to make it work on any keyboard layout.
-- This should map on the top row of your keyboard, usually 1 to 9.
for i = 1, 11 do
    globalkeys = gears.table.join(globalkeys,
        -- View tag only.
        awful.key({ modkey }, "#" .. i + 9,
                  function ()
                        local screen = awful.screen.focused()
                        local tag = screen.tags[i]
                        if tag then
                           tag:view_only()
                        end
                  end,
                  {description = "view tag #"..i, group = "tag"}),
        -- Toggle tag display.
        awful.key({ modkey, "Control" }, "#" .. i + 9,
                  function ()
                      local screen = awful.screen.focused()
                      local tag = screen.tags[i]
                      if tag then
                         awful.tag.viewtoggle(tag)
                      end
                  end,
                  {description = "toggle tag #" .. i, group = "tag"}),
        -- Move client to tag.
        awful.key({ modkey, "Shift" }, "#" .. i + 9,
                  function ()
                      if client.focus then
                          local tag = client.focus.screen.tags[i]
                          if tag then
                              client.focus:move_to_tag(tag)
                          end
                     end
                  end,
                  {description = "move focused client to tag #"..i, group = "tag"}),
        -- Toggle tag on focused client.
        awful.key({ modkey, "Control", "Shift" }, "#" .. i + 9,
                  function ()
                      if client.focus then
                          local tag = client.focus.screen.tags[i]
                          if tag then
                              client.focus:toggle_tag(tag)
                          end
                      end
                  end,
                  {description = "toggle focused client on tag #" .. i, group = "tag"})
    )
end

clientbuttons = gears.table.join(
    awful.button({ }, 1, function (c)
        c:emit_signal("request::activate", "mouse_click", {raise = true})
    end),
    awful.button({ modkey }, 1, function (c)
        c:emit_signal("request::activate", "mouse_click", {raise = true})
        awful.mouse.client.move(c)
    end),
    awful.button({ modkey }, 3, function (c)
        c:emit_signal("request::activate", "mouse_click", {raise = true})
        awful.mouse.client.resize(c)
    end)
)

-- Set keys
root.keys(globalkeys)
-- }}}

-- {{{ Rules
-- Rules to apply to new clients (through the "manage" signal).
awful.rules.rules = {
    -- All clients will match this rule.
    { rule = { },
      properties = { border_width = beautiful.border_width,
                     border_color = beautiful.border_normal,
                     focus = awful.client.focus.filter,
                     raise = true,
                     keys = clientkeys,
                     buttons = clientbuttons,
                     screen = awful.screen.preferred,
                     placement = awful.placement.no_overlap+awful.placement.no_offscreen
     }
    },

    -- Floating clients.
    { rule_any = {
        instance = {
          "DTA",  -- Firefox addon DownThemAll.
          "copyq",  -- Includes session name in class.
          "pinentry",
        },
        class = {
          "Arandr",
          "Blueman-manager",
          "Gpick",
          "Kruler",
          "MessageWin",  
          "Sxiv",
          "Tor Browser", 
          "Wpa_gui",
          "veromix",
          "xtightvncviewer"},

        -- Note that the name property shown in xprop might be set slightly after creation of the client
        -- and the name shown there might not match defined rules here.
        name = {
          "Event Tester",  -- xev.
        },
        role = {
          "AlarmWindow",  -- Thunderbird's calendar.
          "ConfigManager",  -- Thunderbird's about:config.
          "pop-up",       -- e.g. Google Chrome's (detached) Developer Tools.
        }
      }, properties = { floating = true }},

    -- Add titlebars to normal clients and dialogs
    { rule_any = {type = { "normal", "dialog" }
      }, properties = { titlebars_enabled = true }
    },

    -- Set Firefox to always map on the tag named "2" on screen 1.
    -- { rule = { class = "Firefox" },
    --   properties = { screen = 1, tag = "2" } },
}
-- }}}

-- {{{ Signals
-- Signal function to execute when a new client appears.
client.connect_signal("manage", function (c)
    -- Set the windows at the slave,
    -- i.e. put it at the end of others instead of setting it master.
    -- if not awesome.startup then awful.client.setslave(c) end

    if awesome.startup
      and not c.size_hints.user_position
      and not c.size_hints.program_position then
        -- Prevent clients from being unreachable after screen count changes.
        awful.placement.no_offscreen(c)
    end
end)

-- Add a titlebar if titlebars_enabled is set to true in the rules.
client.connect_signal("request::titlebars", function(c)
    -- buttons for the titlebar
    local buttons = gears.table.join(
        awful.button({ }, 1, function()
            c:emit_signal("request::activate", "titlebar", {raise = true})
            awful.mouse.client.move(c)
        end),
        awful.button({ }, 3, function()
            c:emit_signal("request::activate", "titlebar", {raise = true})
            awful.mouse.client.resize(c)
        end)
    )

    awful.titlebar(c) : setup {
        { -- Left
            awful.titlebar.widget.iconwidget(c),
            buttons = buttons,
            layout  = wibox.layout.fixed.horizontal
        },
        { -- Middle
            { -- Title
                align  = "center",
                widget = awful.titlebar.widget.titlewidget(c)
            },
            buttons = buttons,
            layout  = wibox.layout.flex.horizontal
        },
        { -- Right
            awful.titlebar.widget.floatingbutton (c),
            awful.titlebar.widget.maximizedbutton(c),
            awful.titlebar.widget.stickybutton   (c),
            awful.titlebar.widget.ontopbutton    (c),
            awful.titlebar.widget.closebutton    (c),
            layout = wibox.layout.fixed.horizontal()
        },
        layout = wibox.layout.align.horizontal
    }
end)

-- Enable sloppy focus, so that focus follows mouse.
client.connect_signal("mouse::enter", function(c)
    c:emit_signal("request::activate", "mouse_enter", {raise = false})
end)

client.connect_signal("focus", function(c) 
    c.border_color = beautiful.border_focus or "#FFD54F" 
end)

client.connect_signal("unfocus", function(c) 
    c.border_color = beautiful.border_normal or "#C9B8A4" 
end)
-- }}}
