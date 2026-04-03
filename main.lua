--------------------------------------------------
-- CONFIG
-- Last edited via Claude Code on the web
--------------------------------------------------

local NAME = "RotorDash"
local top_offset = 10
local model_image
local default_model_image
local cached_model_name = ""
local battery_warning = false
local battery_warning_disabled = false
local cell_voltage_warning = 4.15
local battery_warning_blink_rate = 100
local tx_low_voltage = 6.5
local tx_warn_voltage = 7.0
local screen_switch_neg = -50
local screen_switch_pos = 50
local timer_source = "timer1"
local tx_voltage_sources = { "tx-voltage", "TxBt" }
local current_peak = 0
local divider_color = lcd.RGB(60, 60, 60)
local topbar_divider_y = 40
local topbar_divider_x = 195
local topbar_divider_x2 = 320
local ui_screen_width = 480
local ui_screen_height = 320
local options = {
    { "HoldSwitch", SWITCH, 0 },
    { "ScreenSwitch", SOURCE, 0 }
}

--------------------------------------------------
-- TELEMETRY CATALOG
--------------------------------------------------

local telemetry = {
    arm       = { sensor = "ARM",  id = 0, available = false, now = 0, fmt = "%d"  },
    batp      = { sensor = "Bat%", id = 0, available = false, now = 0, fmt = "%d"  },
    capacity  = { sensor = "Capa", id = 0, available = false, now = 0, fmt = "%.0f"},
    current   = { sensor = "Curr", id = 0, available = false, now = 0, fmt = "%.2f"},
    gov       = { sensor = "Gov",  id = 0, available = false, now = 0, fmt = "%d"  },
    headspeed = { sensor = "Hspd", id = 0, available = false, now = 0, fmt = "%d"  },
    profile   = { sensor = "PID#", id = 0, available = false, now = 0, fmt = "%d"  },
    rate      = { sensor = "RTE#", id = 0, available = false, now = 0, fmt = "%d"  },
    rqly      = { sensor = "RQly", id = 0, available = false, now = 0, fmt = "%d"  },
    vbat      = { sensor = "Vbat", id = 0, available = false, now = 0, fmt = "%.2f"},
    vbec      = { sensor = "Vbec", id = 0, available = false, now = 0, fmt = "%.2f"},
    vcel      = { sensor = "Vcel", id = 0, available = false, now = 0, fmt = "%.2f"}
}

--------------------------------------------------
-- TELEMETRY SYSTEM
--------------------------------------------------

local function telemetryBind()
    for _, f in pairs(telemetry) do
        local info = getFieldInfo(f.sensor)
        f.id = info and info.id or 0
        f.available = info ~= nil
        f.now = 0
    end
end

local function telemetryRefresh()
    for _, f in pairs(telemetry) do
        if f.available then
            f.now = getValue(f.id)
        else
            f.now = 0
        end
    end
end

--------------------------------------------------
-- HELPERS
--------------------------------------------------

local function telemetryNow(key)
    local f = telemetry[key]
    if f and f.available then return f.now end
    return 0
end

local function isTelemetryWorking()
    return telemetryNow("rqly") > 0
end

local function telemetryDisplay(key)
    local f = telemetry[key]
    if not isTelemetryWorking() then return "--" end
    if not f or not f.available then return "--" end
    local value = tonumber(f.now)
    if value == nil then return "--" end
    return string.format(f.fmt or "%s", value)
end

local function getCurrentPeak()
    if not isTelemetryWorking() then
        current_peak = 0
        return "--"
    end
    local current = tonumber(telemetryNow("current")) or 0
    if current > current_peak then
        current_peak = current
    end
    if current > 0 then
        return string.format("%.2f", current)
    end
    if current_peak <= 0 then
        return "--"
    end
    return string.format("%.2f", current_peak)
end

local function isArmed()
    local arm_status = tonumber(telemetryNow("arm")) or 0
    return arm_status == 1 or arm_status == 3
end

local function isBatteryWarning()
    if not isTelemetryWorking() then
        battery_warning = false
        battery_warning_disabled = false
        return false
    end

    if isArmed() then
        battery_warning_disabled = true
    end

    if battery_warning_disabled then
        return false
    end

    local vcell = tonumber(telemetryNow("vcel")) or 0
    if vcell > 0 and vcell < cell_voltage_warning then
        battery_warning = true
    end

    return battery_warning
end

local function pidRteColor(value, default_color)
    if value == 1 then return lcd.RGB(0, 100, 255) end
    if value == 2 then return lcd.RGB(255, 165, 0) end
    if value == 3 then return lcd.RGB(255, 255, 0) end
    return default_color
end

local function getTimerText()
    local t1 = getValue(timer_source) or 0
    t1 = math.floor(t1)
    if t1 < 0 then t1 = -t1 end

    local mm = math.floor(t1 / 60)
    local ss = t1 % 60
    return string.format("%d:%02d", mm, ss)
end

local function largeMetricBlock(label, value, label_x, value_x, label_y, value_y, label_color, value_color)
    lcd.drawText(label_x, label_y, label, VCENTER + label_color)
    lcd.drawText(value_x, value_y, value, VCENTER + DBLSIZE + BOLD + value_color)
end

local function getScreenMode(screen_switch)
    if not screen_switch or screen_switch == 0 then
        return 1
    end

    local sw_raw = getValue(screen_switch)
    if type(sw_raw) ~= "number" then
        return 1
    end
    if sw_raw <= screen_switch_neg then
        return 1
    elseif sw_raw >= screen_switch_pos then
        return 3
    elseif sw_raw == 0 then
        return 2
    end
    return 2
end

--------------------------------------------------
-- DRAW FUNCTIONS
--------------------------------------------------

local function drawTopBar(label_color, value_color, hold_switch)
    local topbar = {
        hold_x = 8,
        pid_x = 85,
        rte_x = 140,
        gov_x = 205,
        rqly_x = 335,
        tx_x = 420,
        divider1_x = topbar_divider_x,
        divider2_x = topbar_divider_x2,
        divider_y = topbar_divider_y
    }
    local bar_top = 0
    local content_y = math.floor(topbar_divider_y / 2)

    local hold_value_x_offset = 45
    local pid_value_x_offset = 35
    local rte_value_x_offset = 35
    local gov_value_x_offset = 40
    local rqly_value_x_offset = 40
    local tx_value_x_offset = 25

    lcd.drawText(topbar.hold_x, content_y, "HOLD:", SMLSIZE + VCENTER + label_color)
    local hold_active = false
    if hold_switch and hold_switch ~= 0 then
        local sw = getSwitchValue(hold_switch)
        hold_active = (sw and sw ~= 0 and sw ~= false) or false
    end
    lcd.drawText(topbar.hold_x + hold_value_x_offset, content_y, hold_active and "ON" or "OFF", SMLSIZE + VCENTER + (hold_active and GREEN or RED))

    lcd.drawText(topbar.pid_x, content_y, "PID:", SMLSIZE + VCENTER + label_color)
    local profile = tonumber(telemetryDisplay("profile")) or 0
    lcd.drawText(topbar.pid_x + pid_value_x_offset, content_y, telemetryDisplay("profile"), SMLSIZE + VCENTER + pidRteColor(profile, value_color))

    lcd.drawText(topbar.rte_x, content_y, "RTE:", SMLSIZE + VCENTER + label_color)
    local rate = tonumber(telemetryDisplay("rate")) or 0
    lcd.drawText(topbar.rte_x + rte_value_x_offset, content_y, telemetryDisplay("rate"), SMLSIZE + VCENTER + pidRteColor(rate, value_color))

    lcd.drawLine(topbar.divider1_x, bar_top, topbar.divider1_x, topbar.divider_y, SOLID, divider_color)

    if isTelemetryWorking() and isArmed() then
        lcd.drawText(topbar.gov_x, content_y, "GOV:", SMLSIZE + VCENTER + label_color)
        local gov_status = tonumber(telemetryNow("gov")) or 0
        local gov_names = {
            "OFF", "IDLE", "SPOOLUP", "RECOVERY", "ACTIVE",
            "THR-OFF", "LOST-HS", "AUTOROT", "BAILOUT"
        }
        lcd.drawText(topbar.gov_x + gov_value_x_offset, content_y, gov_names[gov_status + 1] or "UNK", SMLSIZE + VCENTER + RED)
    else
        lcd.drawText(topbar.gov_x, content_y, "ARM:", SMLSIZE + VCENTER + label_color)
        lcd.drawText(topbar.gov_x + gov_value_x_offset, content_y, "DISARMED", SMLSIZE + VCENTER + GREEN)
    end

    lcd.drawLine(topbar.divider2_x, bar_top, topbar.divider2_x, topbar.divider_y, SOLID, divider_color)

    lcd.drawText(topbar.rqly_x, content_y, "RQLY:", SMLSIZE + VCENTER + label_color)

    local rqly_percent = tonumber(telemetryNow("rqly")) or 0
    rqly_percent = math.max(0, math.min(100, rqly_percent))
    local active_blocks = math.floor((rqly_percent + 19) / 20)
    local block_size = 5
    local block_spacing = 7
    local block_x = topbar.rqly_x + rqly_value_x_offset
    local block_y = content_y
    for i = 1, 5 do
        local color = WHITE
        if rqly_percent > 0 and i <= active_blocks then
            if i == 1 then
                color = RED
            elseif i == 2 then
                color = ORANGE
            elseif i == 3 then
                color = YELLOW
            elseif i == 4 then
                color = lcd.RGB(173, 255, 47)
            else
                color = GREEN
            end
        end
        lcd.drawFilledRectangle(block_x + (i - 1) * block_spacing, block_y, block_size, block_size, color)
    end

    lcd.drawText(topbar.tx_x, content_y, "TX:", SMLSIZE + VCENTER + label_color)
    local tx_voltage = getValue(tx_voltage_sources[1]) or getValue(tx_voltage_sources[2]) or 0
    local tx_text = string.format("%.1fv", tonumber(tx_voltage) or 0)
    local tx_color = GREEN
    if tx_voltage < tx_low_voltage then
        tx_color = RED
    elseif tx_voltage >= tx_low_voltage and tx_voltage <= tx_warn_voltage then
        tx_color = YELLOW
    end
    lcd.drawText(topbar.tx_x + tx_value_x_offset, content_y, tx_text, SMLSIZE + VCENTER + tx_color)

    lcd.drawLine(0, topbar.divider_y, ui_screen_width, topbar.divider_y, SOLID, divider_color)
end

local function drawClock(value_color)
    local now = getDateTime()
    local time_str = string.format("%02d:%02d:%02d", now.hour, now.min, now.sec)
    lcd.drawText(390, 290, time_str, BOLD + value_color)
end

local function drawDataBlock(label_color, value_color)
    local current_text = getCurrentPeak()
    lcd.drawText(30, 170 + top_offset, "Battery", VCENTER + label_color)
    lcd.drawText(30, 190 + top_offset, telemetryDisplay("vbat"), VCENTER + MIDSIZE + value_color)

    lcd.drawText(30, 220 + top_offset, "Cell", VCENTER + label_color)
    lcd.drawText(30, 240 + top_offset, telemetryDisplay("vcel"), VCENTER + MIDSIZE + value_color)

    lcd.drawText(30, 270 + top_offset, "Bat%", VCENTER + label_color)
    lcd.drawText(30, 290 + top_offset, telemetryDisplay("batp"), VCENTER + MIDSIZE + value_color)

    lcd.drawText(150, 170 + top_offset, "Bec", VCENTER + label_color)
    lcd.drawText(150, 190 + top_offset, telemetryDisplay("vbec"), VCENTER + MIDSIZE + value_color)

    lcd.drawText(150, 220 + top_offset, "Current", VCENTER + label_color)
    lcd.drawText(150, 240 + top_offset, current_text, VCENTER + MIDSIZE + value_color)

    lcd.drawText(150, 270 + top_offset, "Capacity", VCENTER + label_color)
    lcd.drawText(150, 290 + top_offset, telemetryDisplay("capacity"), VCENTER + MIDSIZE + value_color)
end

local function drawBattery()
    local batp = tonumber(telemetryNow("batp")) or 0
    local vcell = tonumber(telemetryNow("vcel")) or 0
    local vcell_ready = vcell > 0
    local is_warning = isBatteryWarning()
    if is_warning then
        batp = 100
    end
    local x = 40
    local y = 80
    local bar_w = 115
    local bar_h = 210
    local cap_w = 30
    local cap_h = 10

    local batp_safe = math.max(0, math.min(100, batp))
    local body_inner_x = x + 1
    local body_inner_y = y + 1
    local body_inner_w = bar_w - 2
    local body_inner_h = bar_h - 2
    local fill_h = math.floor(body_inner_h * (batp_safe / 100))
    local max_fill_h = body_inner_h - 1
    if fill_h > max_fill_h then
        fill_h = max_fill_h
    end
    local fill_y = body_inner_y + (body_inner_h - fill_h)
    local cap_x = x + (bar_w - cap_w) / 2
    local fill_color = GREEN
    local outline_color = WHITE
    local segment_color = WHITE
    local blink_on = true
    if not is_warning and not vcell_ready then
        fill_color = BLACK
    end
    if is_warning then
        fill_color = RED
        outline_color = WHITE
        segment_color = WHITE
        local current_time = getTime and getTime() or 0
        blink_on = math.floor((current_time / battery_warning_blink_rate) % 2) == 0
        if not blink_on then
            fill_color = BLACK
            outline_color = BLACK
            segment_color = BLACK
        end
    end
    lcd.drawFilledRectangle(cap_x, y - cap_h, cap_w, cap_h, outline_color)
    lcd.drawRectangle(cap_x, y - cap_h, cap_w, cap_h, outline_color)
    lcd.drawRectangle(x, y, bar_w, bar_h, outline_color)
    if fill_h > 0 then
        lcd.drawFilledRectangle(body_inner_x, fill_y, body_inner_w, fill_h, fill_color)
    end
    for i = 1, 4 do
        local segment_y = math.floor(body_inner_y + (body_inner_h / 5) * i)
        lcd.drawLine(body_inner_x, segment_y, body_inner_x + body_inner_w, segment_y, SOLID, segment_color)
    end
end

local function drawModelInfo(value_color)
    local current_model_name = model.getInfo().name or ""
    if cached_model_name ~= current_model_name then
        cached_model_name = current_model_name
        local safe_model_name = string.gsub(current_model_name or "", "[<>:\"/\\|?*]", "")
        local cached_pic_path = "/WIDGETS/RotorDash/" .. safe_model_name .. ".png"
        if fstat(cached_pic_path) then
            model_image = Bitmap.open(cached_pic_path)
        else
            model_image = nil
        end
    end

    lcd.drawText(260, 290, cached_model_name, BOLD + value_color)

    if model_image then
        lcd.drawBitmap(model_image, 260, 170)
    elseif default_model_image then
        lcd.drawBitmap(default_model_image, 260, 170)
    end
end

local function drawRpm(label_color, value_color, label_x, value_x, label_y, value_y)
    largeMetricBlock("RPM", telemetryDisplay("headspeed"), label_x, value_x, label_y, value_y, label_color, value_color)
end

local function drawTimer(label_color, value_color, label_x, value_x, label_y, value_y)
    largeMetricBlock("TIMER", getTimerText(), label_x, value_x, label_y, value_y, label_color, value_color)
end

local function drawGroundSeparators()
    lcd.drawLine(0, 150, ui_screen_width, 150, SOLID, divider_color)
    lcd.drawLine(240, 150, 240, ui_screen_height, SOLID, divider_color)
end

local function drawGroundScreen(label_color, value_color)
    drawClock(value_color)
    drawDataBlock(label_color, value_color)
    drawModelInfo(value_color)
    drawRpm(label_color, value_color, 30, 30, 50 + top_offset, 100 + top_offset)
    drawTimer(label_color, value_color, 270, 270, 50 + top_offset, 100 + top_offset)
    drawGroundSeparators()
end

local function drawFlightSeparators()
    local mid_y = math.floor(topbar_divider_y + (ui_screen_height - topbar_divider_y) / 2)
    lcd.drawLine(topbar_divider_x, topbar_divider_y, topbar_divider_x, ui_screen_height, SOLID, divider_color)
    lcd.drawLine(topbar_divider_x, mid_y, ui_screen_width, mid_y, SOLID, divider_color)
end

local function drawFlightScreen(label_color, value_color)
    drawBattery()
    drawRpm(label_color, value_color, 260, 260, 75, 125)
    drawTimer(label_color, value_color, 260, 260, 215, 265)
    drawFlightSeparators()
end

local function drawScreen3()
    lcd.drawText(165, 115, "SCREEN 3", MIDSIZE + VCENTER + WHITE)
end

--------------------------------------------------
-- WIDGET LIFECYCLE
--------------------------------------------------

local function create(zone, options)
    local widget = {
        zone = zone,
        options = options
    }
    cached_model_name = ""
    telemetryBind()
    default_model_image = Bitmap.open("/WIDGETS/RotorDash/default.png") -- Load the default image only during create.
    return widget
end

local function update(widget, options)
    widget.options = options
end

local function background(widget)
end

--------------------------------------------------
-- REFRESH LOOP
--------------------------------------------------

local function refresh(widget, event, touchState)
    ui_screen_width = LCD_W or widget.zone.w
    ui_screen_height = LCD_H or widget.zone.h
    local background_color = BLACK
    local label_color = lcd.RGB(180, 180, 180)
    local value_color = WHITE

    lcd.drawFilledRectangle(0, 0, ui_screen_width, ui_screen_height, background_color)

    telemetryRefresh()

    drawTopBar(label_color, value_color, widget.options.HoldSwitch)

    local screen_mode = getScreenMode(widget.options.ScreenSwitch)
    
    if screen_mode == 1 then
        drawGroundScreen(label_color, value_color)
    elseif screen_mode == 2 then
        drawFlightScreen(label_color, value_color)
    else
        drawScreen3()
    end
end

--------------------------------------------------
-- WIDGET REGISTRATION
--------------------------------------------------

return {
    name = NAME,
    options = options,
    create = create,
    update = update,
    refresh = refresh,
    background = background
}
