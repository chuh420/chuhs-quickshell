local base = "/home/chuh/.config/pleamar/shells/material/"
local rice = "/home/chuh/.config/rice/"
local workers = {}
local wired_connected = false
local wifi = { networks = {} }
local bluetooth = { devices = {} }
local audio = { outputs = {}, inputs = {} }
local apps, hidden, wallpapers, items, tray = {}, {}, {}, {}, {}
local prompt_kind = ""
local current_wallpaper = ""
local previews = {}
local gallery_request = ""
local show_tray_menu
local tray_target = nil
local menu_stack = {}
local keyboard_initial = true
local keyboard_name = ""
local inhibitor = nil
fact.awake = false
fact.opened = false
fact.panel = 0
fact.prompt_open = false
local names = { "applications", "control center", "calendar", "wallpapers", "Wi-Fi", "Bluetooth", "sound", "battery", "application menu" }
local refresh_items
local update_labels
local slice
local open_panel
local function parse(out)
    local ok, value = pcall(json.decode, out)
    return ok and value or nil
end
local function python(path, args, callback, how)
    local values = { path }
    for _, a in ipairs(args or {}) do table.insert(values, a) end
    run("python", values, callback, how)
end
local function wifi_command(data)
    if workers.wifi then write(workers.wifi, json.encode(data) .. "\n") end
end
local function watch_worker(name, path, args, callback, input)
    local values = { path }
    for _, a in ipairs(args or {}) do table.insert(values, a) end
    local function start()
        workers[name] = spawn("python", values, function(line)
            local value = parse(line)
            if value then callback(value) end
        end, function(_, code)
            workers[name] = nil
            log(name .. " worker exited", code)
            after(2000, start)
        end, input and { stdin = "open" } or nil)
    end
    start()
end
update_labels = function()
    text.power_wifi = wifi.powered and "ON" or "OFF"
    text.power_bt = bluetooth.powered and "ON" or "OFF"
    text.power_awake = fact.awake and "ON" or "OFF"
    text.network_name = wifi.connected and wifi.network or wired_connected and "Wired connection" or "Offline"
    text.wifi_status = wifi.powered and (wifi.busy and "Connecting…" or wifi.connected and wifi.network or "Select a network") or "Wi-Fi is turned off"
    text.wifi_empty = wifi.powered and "No networks found" or "Wireless disabled"
    text.bluetooth_name = bluetooth.name or "No adapter found"
    text.bluetooth_label = bluetooth.powered and "Bluetooth enabled" or "Bluetooth disabled"
    text.bluetooth_empty = bluetooth.powered and "Scan to discover devices" or "Bluetooth is turned off"
    text.scan_wifi = wifi.scanning and "Scanning…" or "󰑐"
    fact.scan_wifi_width = wifi.scanning and 108.336 or 38.064
    text.scan_bt = bluetooth.discovering and "Stop scan" or "Scan"
    fact.scan_bt_width = (bluetooth.discovering and 9 or 4) * 8.784 + 29.28
    local percent = math.floor((audio.volume or 0) * 100 + 0.5) .. "%"
    text.volume_label = audio.muted and "MUTE" or percent
    text.volume_percent_label = percent
    fact.volume_chip_width = #text.volume_label * 8.784 + 29.28
    text.input_label = audio.input_muted and "MUTED" or "ON"
    fact.input_chip_width = #text.input_label * 8.784 + 29.28
    fact.has_message = text.message ~= ""
    local selected = items[fact.selected + 1]
    text.launcher_help = "Enter launch  ·  Ctrl+h " .. (selected and selected.hidden and "unhide" or "hide") .. "  ·  Ctrl+Shift+h " .. (fact.show_hidden and "hide hidden" or "show hidden") .. "  ·  Esc close"
end
on("fact:awake", update_labels)
on("text:message", update_labels)
on("list_scrolled", function(first) fact.offset = math.floor(first); slice() end)
on("volume_percent", function(value) sys.call("audio.volume", value / 100) end)
on("input_percent", function(value) sys.call("audio.input", value / 100) end)
on("audio_device", function(index)
    local devices = index > 0 and audio.outputs or audio.inputs
    local device = devices[math.abs(index)]
    if device then sys.call("audio.default", device.id) end
end)
local tips = { [2] = "Super + Space", [7] = "XF86AudioRaiseVolume / XF86AudioLowerVolume / XF86AudioMute", [8] = "XF86AudioMute", [9] = "XF86AudioMicMute", [10] = "Super + N", [11] = "Prevent automatic locking and sleep", [12] = "Super + N", [13] = "Super + C", [14] = "Print", [15] = "Super + B", [26] = "Super + Ctrl + L", [27] = "XF86AudioRaiseVolume / XF86AudioLowerVolume", [28] = "XF86MonBrightnessUp / XF86MonBrightnessDown" }
on("tip_show", function(code)
    text.tip_label = code >= 10000 and "Super + " .. (code - 10000) or tips[code] or ""
    fact.tip_visible = text.tip_label ~= ""
end)
on("tip_hide", function() fact.tip_visible = false end)
slice = function()
    fact.count = #items
    fact.selected = math.clamp(fact.selected, 0, math.max(0, #items - 1))
    local window = fact.panel == 4 and 8 or 12
    fact.offset = math.clamp(fact.offset, 0, math.max(0, #items - 1))
    if fact.panel == 4 then fact.offset = math.floor(fact.offset / 2) * 2 end
    local visible = {}
    for index = fact.offset + 1, math.min(#items, fact.offset + window) do
        local item = table.clone(items[index])
        item.selected = index - 1 == fact.selected
        item.active = item.active or false
        visible[#visible + 1] = item
    end
    if fact.panel == 4 then
        local missing = {}
        for _, item in ipairs(visible) do
            local key = item.path .. "\n" .. item.revision
            item.picture = previews[key] or ""
            if previews[key] == nil then missing[#missing + 1] = { path = item.path, revision = item.revision } end
        end
        model.pictures = visible
        local requested = json.encode(missing)
        if requested ~= gallery_request and workers.gallery then
            gallery_request = requested
            write(workers.gallery, requested .. "\n")
        end
    else model.rows = visible end
end
local app_generation = 0
local empty_apps = {}
local function app_list(concealed)
    app_generation += 1
    if workers.desktop then
        write(workers.desktop, json.encode({ query = text.query, generation = app_generation, hidden = concealed }) .. "\n")
    end
end
local function wallpaper_list()
    python(rice .. "wallpapers.py", { "list" }, function(out, code)
        local data = code == 0 and parse(out)
        if data then
            wallpapers, current_wallpaper = data.items, data.current
            if fact.panel == 4 then refresh_items() end
        else text.message = "could not read wallpapers" end
    end)
end
refresh_items = function()
    local previous = items[fact.selected + 1]
    items = {}
    local panel = fact.panel
    if panel == 1 then
        for _, app in ipairs(apps) do
            local concealed = table.find(hidden, app.id) ~= nil
            if not concealed or fact.show_hidden then
                items[#items + 1] = { name = app.name, detail = app.generic ~= "" and app.generic or app.comment, id = app.id, hidden = concealed, initial = app.initial or "", icon = app.icon, has_icon = app.icon ~= "", extra = false }
            end
        end
        text.subtitle = fact.show_hidden and "hidden applications · Ctrl+h restores selection" or "search by name, generic name or description"
    elseif panel == 4 then
        for _, wall in ipairs(wallpapers) do
            items[#items + 1] = { name = wall.name, picture = "", path = wall.path, revision = wall.revision or "", active = wall.path == current_wallpaper }
        end
        text.subtitle = "~/Pictures/Wallpapers · " .. #items .. " images"
    elseif panel == 5 then
        for _, net in ipairs(wifi.networks) do
            if (fact.saved_tab and net.saved) or (not fact.saved_tab and net.available) then
                items[#items + 1] = { name = net.name, detail = net.connected and "connected · disconnect" or (not net.available and "out of range" or (net.security .. " · " .. math.floor(net.strength) .. "%")), net = net, active = net.connected, has_icon = false, extra = net.saved and fact.saved_tab, allowed = net.available and not wifi.busy, symbol = net.connected and "󰤨" or "󰤥" }
            end
        end
        text.subtitle = (wifi.powered and "on · " or "off · ") .. (wifi.network or wifi.state or "") .. (wifi.scanning and " · scanning" or "")
        text.message = wifi.message or ""
    elseif panel == 6 then
        for _, dev in ipairs(bluetooth.devices) do
            items[#items + 1] = { name = dev.name, detail = (dev.pairing and "pairing · cancel" or dev.connected and "connected · disconnect" or dev.paired and "paired · connect" or "pair") .. (dev.battery >= 0 and " · " .. dev.battery .. "%" or ""), action_label = dev.pairing and "Cancel" or dev.connected and "Disconnect" or dev.paired and "Connect" or "Pair", action_width = (dev.pairing and 6 or dev.connected and 10 or dev.paired and 7 or 4) * 8.784 + 29.28, device = dev, active = dev.connected, has_icon = false, extra = dev.paired }
        end
        text.subtitle = (bluetooth.name or "") .. (bluetooth.powered and " · on" or " · off") .. (bluetooth.discovering and " · scanning" or "")
    elseif panel == 7 then
        for _, dev in ipairs(audio.outputs) do items[#items + 1] = { name = dev.name, detail = "output" .. (dev.default and " · default" or ""), device_id = dev.id, active = dev.default, has_icon = false, extra = false } end
        for _, dev in ipairs(audio.inputs) do items[#items + 1] = { name = dev.name, detail = "input" .. (dev.default and " · default" or ""), device_id = dev.id, active = dev.default, has_icon = false, extra = false } end
        text.subtitle = (audio.muted and "output muted" or "output on") .. " · " .. (audio.input_muted and "input muted" or "input on")
    end
    if panel == 1 and previous then
        for i, item in ipairs(items) do if item.id == previous.id then fact.selected = i - 1; break end end
    end
    slice()
    if update_labels then update_labels() end
end
local close_timer
local function close_panel()
    if fact.panel == 4 and workers.gallery then write(workers.gallery, "[]\n"); gallery_request = "" end
    if fact.panel == 6 and bluetooth.discovering then wifi_command({ action = "bt-scan", enabled = false }) end
    wifi_command({ action = "panel", visible = false })
    if prompt_kind == "wifi" then wifi_command({ action = "cancel" }) end
    if prompt_kind == "bluetooth" then wifi_command({ action = "bluetooth-reply", accepted = false }) end
    if workers.status then write(workers.status, '{"detailed":false}\n') end
    prompt_kind = ""
    fact.prompt_open = false
    fact.tip_visible = false
    text.pin = ""
    text.answer = ""
    focus()
    fact.opened = false
    if close_timer then cancel(close_timer) end
    close_timer = after(500, function() close_timer = nil; if not fact.opened then fact.panel = 0 end end)
end
open_panel = function(panel, origin, x)
    if panel == 10 then close_panel(); run("/home/chuh/.local/bin/chuhshell", { "notifications" }); return end
    if fact.opened and fact.panel == panel then close_panel(); return end
    close_panel()
    if close_timer then cancel(close_timer); close_timer = nil end
    fact.panel, fact.origin, fact.panel_x = panel, origin or 0, x or 0
    fact.selected, fact.offset = 0, 0
    fact.opened = true
    text.heading = names[panel] or ""
    text.subtitle, text.message = "", ""
    if panel == 1 then apps = empty_apps; fact.show_hidden = false; text.query = ""; app_list(); focus("query") end
    if panel == 4 then gallery_request = ""; wallpaper_list() end
    if panel == 5 then
        wifi_command({ action = "panel", visible = true })
        if wifi.powered then wifi_command({ action = "scan" }) end
    end
    if panel == 8 and workers.status then write(workers.status, '{"detailed":true}\n') end
    if panel == 3 then
        python(base .. "helpers/desktop.py", { "calendar" }, function(out)
            local data = parse(out)
            if data then model.days = data.cells; text.month_label = data.title end
        end)
    end
    refresh_items()
    emit("list_reset")
end
on("toggle_panel", function(panel) open_panel(panel, fact.origin, fact.panel_x) end)
on("close", close_panel)
for name, index in pairs({ launcher = 1, menu = 2, calendar = 3, wallpapers = 4, wifi = 5, bluetooth = 6, audio = 7, battery = 8 }) do
    on(name, function() open_panel(index, 0, 0) end)
end
on("text:query", function()
    if fact.panel ~= 1 or not fact.opened then return end
    fact.selected, fact.offset = 0, 0
    items = {}
    slice()
    emit("list_reset")
    app_list()
end)
on("scroll_rows", function(wheel) fact.offset = fact.offset - math.floor(wheel); slice() end)
local function move_selection(step)
    if fact.panel ~= 1 and fact.panel ~= 4 then return end
    fact.selected = math.clamp(fact.selected + step, 0, math.max(0, #items - 1))
    slice()
    emit("selection_changed")
end
on("move_selection", move_selection)
on("move_vertical", function(step) move_selection(step * (fact.panel == 4 and 2 or 1)) end)
local function choose(index)
    if not fact.opened then return end
    local item = items[index + 1]
    if not item then return end
    fact.selected = index
    if fact.panel == 1 then
        close_panel()
        python(base .. "helpers/desktop.py", { "launch", item.id }, function(_, code) if code ~= 0 then log("application launch failed", item.id) end end)
    elseif fact.panel == 4 then
        python(rice .. "wallpapers.py", { "apply", item.path }, function(out, code)
            if code == 0 then wallpaper_list() else text.message = out end
        end, { errors = true })
    elseif fact.panel == 5 and item.net.available and not wifi.busy then
        wifi_command(item.net.connected and { action = "disconnect" } or { action = "connect", path = item.net.path })
    elseif fact.panel == 6 then
        local dev = item.device
        wifi_command({ action = dev.pairing and "bt-cancel" or dev.connected and "bt-disconnect" or dev.paired and "bt-connect" or "bt-pair", path = dev.path })
    elseif fact.panel == 7 then sys.call("audio.default", item.device_id)
    elseif fact.panel == 9 then
        if item.submenu then table.insert(menu_stack, items); items = item.submenu; fact.tray_root = false; fact.offset = 0; slice()
        elseif item.tray_action then
            if item.tray_action == "open" then sys.call("tray.activate", tray_target.key); close_panel()
            elseif item.tray_action == "quit" then python(base .. "helpers/tray.py", { "quit", tray_target.id, tray_target.title }, function(out, code) if code ~= 0 then text.message = out else close_panel() end end, { errors = true })
            elseif item.tray_action == "back" then items = table.remove(menu_stack) or {}; fact.tray_root = #menu_stack == 0; fact.offset = 0; slice() end
        elseif item.enabled then sys.call("tray.menu_click", tray_target.key, item.menu_id); close_panel() end
    end
end
on("choose", choose)
on("activate_selection", function() if not fact.prompt_open then choose(fact.selected) end end)
on("extra", function(index)
    local item = items[index + 1]
    if not item then return end
    if fact.panel == 5 then wifi_command({ action = "forget", path = item.net.known }) end
    if fact.panel == 6 then wifi_command({ action = "bt-forget", path = item.device.path }) end
end)
on("hide_selected", function()
    if fact.panel ~= 1 then return end
    local item = items[fact.selected + 1]
    if not item then return end
    local at = table.find(hidden, item.id)
    if at then table.remove(hidden, at) else table.insert(hidden, item.id) end
    app_list(hidden)
    refresh_items()
end)
on("hidden_toggle", function() fact.show_hidden = not fact.show_hidden; refresh_items(); emit("selection_changed") end)
local function answer_prompt(accepted)
    if prompt_kind == "wifi" then wifi_command(accepted and { action = "password", password = text.answer } or { action = "cancel" })
    elseif prompt_kind == "bluetooth" then wifi_command({ action = "bluetooth-reply", accepted = accepted, value = text.pin }) end
    text.answer = ""
    fact.prompt_open = false
    prompt_kind = ""
    focus()
end
on("prompt_submit", function() answer_prompt(true) end)
on("prompt_cancel", function() answer_prompt(false) end)
on("volume_step", function(wheel) run("/home/chuh/.local/bin/chuhshell", { wheel > 0 and "volume-up" or "volume-down" }) end)
on("volume_set", function(value) sys.call("audio.volume", value) end)
on("input_set", function(value) sys.call("audio.input", value) end)
on("go", function(id) run("hyprctl", { "eval", "hl.dispatch(hl.dsp.focus({workspace=" .. id .. "}))" }) end)
local brightness_timer, wanted_brightness
on("brightness_set", function(value)
    wanted_brightness = math.floor(value)
    fact.brightness = wanted_brightness
    if brightness_timer then return end
    brightness_timer = after(80, function()
        brightness_timer = nil
        run("brightnessctl", { "set", wanted_brightness .. "%" })
    end)
end)
local commands = { "keyboard", "wifi-power", "wifi-available", "wifi-saved", "wifi-scan", "bt-power", "bt-scan", "mute", "input-mute", "audio", "awake", "notifications", "clipboard", "screenshot", "wallpapers", "lock", "suspend", "power", "wifi", "bluetooth", "audio-panel", "battery", "refresh", "prompt-cancel", "prompt-submit", "control", "close" }
on("command", function(index)
    local action = commands[index]
    local panels = { control = 2, wifi = 5, bluetooth = 6, ["audio-panel"] = 7, battery = 8, wallpapers = 4 }
    if panels[action] then open_panel(panels[action], fact.origin, fact.panel_x)
    elseif action == "close" then close_panel()
    elseif action == "keyboard" then python(rice .. "keyboard.py", { "next" })
    elseif action == "wifi-power" then wifi_command({ action = "power", enabled = not wifi.powered })
    elseif action == "wifi-scan" then wifi_command({ action = "scan" })
    elseif action == "wifi-available" or action == "wifi-saved" then fact.saved_tab = action == "wifi-saved"; fact.offset = 0; refresh_items(); emit("list_reset")
    elseif action == "bt-power" then wifi_command({ action = "bt-power", enabled = not bluetooth.powered })
    elseif action == "bt-scan" then wifi_command({ action = "bt-scan", enabled = not bluetooth.discovering })
    elseif action == "mute" then sys.call("audio.mute")
    elseif action == "input-mute" then sys.call("audio.input_mute")
    elseif action == "refresh" then previews = {}; gallery_request = ""; wallpaper_list(); app_list()
    elseif action == "prompt-submit" then answer_prompt(true)
    elseif action == "prompt-cancel" then answer_prompt(false)
    elseif action == "awake" then
        if inhibitor then kill(inhibitor); inhibitor = nil; fact.awake = false
        else
            inhibitor = spawn(base .. "helpers/idle-inhibit", {}, function(line) if line == "ready" then fact.awake = true end end, function(_, code) inhibitor = nil; fact.awake = false; if code ~= 0 then text.message = "idle inhibition failed" end end)
        end
    else close_panel(); run("/home/chuh/.local/bin/chuhshell", { action }) end
end)
sys.watch("workspaces", function(value)
    local records, occupied, ids = {}, {}, {}
    for i = 1, 5 do ids[i] = i end
    for _, desk in ipairs(value.list) do occupied[desk.id] = true; if desk.id > 5 then table.insert(ids, desk.id) end end
    table.sort(ids)
    for _, id in ipairs(ids) do records[#records + 1] = { id = id, active = id == value.active, occupied = occupied[id] or false, label = id == value.active and "0" .. id or occupied[id] and "●" or "○" } end
    model.desks = records
end)
sys.watch("window", function(value) text.title = value.title ~= "" and value.title or "still / material" end)
sys.watch("audio", function(value)
    audio = value
    model.outputs = value.outputs
    model.inputs = value.inputs
    fact.volume, fact.audio_muted = value.volume, value.muted
    text.audio_label = value.muted and "󰖁" or "󰕾"
    fact.input_volume, fact.input_muted = value.input or 0, value.input_muted or false
    if fact.panel == 7 then refresh_items() end
    update_labels()
end)
local function update_clock()
    run("date", { "+%A, %-d %B" }, function(out) text.long_date = string.gsub(out, "\n", "") end, { env = { LC_TIME = "C" } })
    run("date", { "+%a, %-d %b  ·  %H:%M" }, function(out) text.date_time = string.gsub(out, "\n", "") end, { env = { LC_TIME = "C" } }) end
update_clock()
local clock_day
sys.watch("clock", function(value)
    update_clock()
    local day = string.format("%d-%d-%d", value.year, value.month, value.day)
    if clock_day ~= day and fact.panel == 3 then
        python(base .. "helpers/desktop.py", { "calendar" }, function(out)
            local data = parse(out)
            if data then model.days = data.cells; text.month_label = data.title end
        end)
    end
    clock_day = day
end)
watch_worker("resources", rice .. "resources.py", {}, function(value)
    text.cpu_label = value.cpu and value.cpu .. "%" or "…"
    text.ram_label = string.format("%.1f GiB", value.ramUsed)
end)
watch_worker("status", rice .. "status.py", { "watch" }, function(value)
    fact.battery, fact.battery_present, fact.charging = value.battery, value.present, value.charging
    fact.brightness = value.brightness
    text.battery_label = (value.charging and "󰂄 " or "󰁹 ") .. value.battery .. "%"
    text.battery_details = value.present and (value.battery .. "% · " .. (value.batteryStatus or "") .. "\n\n" .. (value.batteryTime or "") .. "\n\n" .. (value.batteryPower or 0) .. " W\n\nhealth " .. (value.batteryHealth or 0) .. "%") or "no battery present"
    text.battery_status = value.batteryStatus or ""
    text.battery_percent = value.battery .. "%"
    text.battery_time = value.batteryTime or "Calculating…"
    text.battery_power = (value.batteryPower or 0) > 0 and value.batteryPower .. " W" or "—"
    text.battery_health = (value.batteryHealth or 0) > 0 and value.batteryHealth .. "%" or "—"
    text.battery_icon = value.charging and "󰂄" or "󰁹"
    text.battery_bar_percent = value.battery .. "%"
    wired_connected = value.connected
    fact.connected = wifi.connected or wired_connected
    text.network_label = fact.connected and "󰤨" or "󰤭"
    update_labels()
end, true)
watch_worker("keyboard", base .. "helpers/events.py", {}, function(value)
    text.keyboard_label = value.label
    if not keyboard_initial and value.name ~= keyboard_name then python(rice .. "keyboard.py", { "notify", value.name }) end
    keyboard_name, keyboard_initial = value.name, false
end)
watch_worker("wifi", base .. "helpers/wifi.py", {}, function(value)
    if value.kind == "state" then
        wifi = value
        fact.wifi_power, fact.connected = value.powered, value.connected or wired_connected
        text.network_label = fact.connected and "󰤨" or "󰤭"
        if fact.panel == 5 then refresh_items() end
        update_labels()
    elseif value.kind == "bluetooth-state" then
        bluetooth = value
        fact.bt_power, fact.bt_scan = value.powered, value.discovering
        if fact.panel == 6 then refresh_items() end
        update_labels()
    elseif value.kind == "bluetooth-error" then
        if fact.panel == 6 then text.message = value.message end
    elseif value.kind == "prompt" or value.kind == "bluetooth-prompt" then
        if value.name ~= "" then
            local wanted = value.kind == "prompt" and 5 or 6
            if fact.panel ~= wanted then open_panel(wanted, fact.origin, fact.panel_x) end
            prompt_kind = wanted == 5 and "wifi" or "bluetooth"
            text.prompt_label = value.name .. (value.value and " · " .. value.mode .. " " .. value.value or "")
            text.answer = ""
            fact.prompt_secret, fact.prompt_open = wanted == 5, true
            fact.prompt_input = wanted == 6 and (value.mode == "pin" or value.mode == "passkey")
            text.pin = ""
            text.prompt_detail = value.value and tostring(value.value) or ""
            if wanted == 5 then focus("answer") elseif fact.prompt_input then focus("pin") else focus() end
        else fact.prompt_open = false; text.answer = ""; prompt_kind = ""; focus() end
    end
end, true)
sys.watch("tray", function(list) tray = list; model.tray_icons = list end)
on("tray_click", function(index)
    local item = tray[index + 1]
    if item then
        python(base .. "helpers/tray.py", { "flags", item.key }, function(out)
            local flags = parse(out)
            if flags and flags.only_menu then
                for i, current in ipairs(tray) do if current.key == item.key then show_tray_menu(i - 1, true); return end end
            else sys.call("tray.activate", item.key) end
        end)
    end
end)
on("tray_wheel", function(wheel)
    local index = fact.tray_index
    local item = tray[index + 1]
    if item then sys.call("tray.scroll", item.key, wheel) end
end)
local function menu_rows(entries, nested)
    local records = {}
    if nested then records[#records + 1] = { name = "← back", detail = "", tray_action = "back" } end
    for _, entry in ipairs(entries or {}) do
        if not entry.separator then
            local row = { allowed = entry.enabled, name = string.gsub(entry.label or "", "_", ""), detail = entry.checked and "✓" or "", menu_id = entry.id, enabled = entry.enabled, has_icon = false, extra = false }
            records[#records + 1] = row
            if entry.children and #entry.children > 0 then row.detail = "›"; row.submenu = menu_rows(entry.children, true) end
        end
    end
    return records
end
show_tray_menu = function(index, only_menu)
    local origin, x = fact.origin, fact.panel_x
    tray_target = tray[index + 1]
    if not tray_target then return end
    open_panel(9, origin, x)
    local native = sys.ask("tray.menu", tray_target.key)
    local root = {
        { name = "Open application", detail = "", tray_action = "open", has_icon = false, extra = false },
        { name = "Application menu", detail = "›", has_icon = false, extra = false },
        { danger = true, name = "Quit application", detail = "", tray_action = "quit", has_icon = false, extra = false },
    }
    root[2].submenu = menu_rows(native, true)
    menu_stack = {}
    fact.tray_root = not only_menu
    items = only_menu and menu_rows(native, false) or root
    text.heading = tray_target.title
    slice()
end
on("tray_menu", show_tray_menu)
watch_worker("desktop", base .. "helpers/desktop.py", { "watch" }, function(data)
    if data.error then log("application catalog failed", data.error); return end
    if data.generation == 0 then
        empty_apps = data.apps
        if text.query ~= "" then app_list(); return end
    elseif data.generation ~= app_generation or data.query ~= text.query then return end
    apps, hidden = data.apps, data.hidden
    if data.query == "" then empty_apps = apps end
    if fact.panel == 1 then refresh_items() end
end, true)
watch_worker("gallery", base .. "helpers/gallery.py", { "watch" }, function(data)
    if data.ready then gallery_request = ""
    elseif data.error then log("wallpaper preview failed", data.error); return
    elseif data.path then previews[data.path .. "\n" .. (data.revision or "")] = data.picture end
    if fact.panel == 4 and fact.opened then slice() end
end, true)
