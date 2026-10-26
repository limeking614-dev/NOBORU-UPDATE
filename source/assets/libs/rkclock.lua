-- rkclock.lua : clock shown over the reader  (Settings > Reader > Clock in reader)
--   OFF / TIME / DATE / TIME + DATE      (the date never shows the year)
--   Settings > Reader > Clock 24h        (12 hour or 24 hour time)
-- main.lua removes `os` and replaces `System` after the libs are loaded, so the time functions are
-- captured here, while they still exist.
RKClock = {}

local getTime = System.getTime
local getDate = System.getDate
local osDate = os and os.date

local DAYS = { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" }
local MONTHS = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }

RK_BarsShown = false -- set by the readers: top / bottom bars are visible (the clock hides then)
RK_ReaderVertical = false -- set by the readers: the view is rotated 90 degrees

-- day of week from a date, 0 = Sunday (does not depend on how the console numbers its weekdays)
local function weekday(y, m, d)
	local t = { 0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4 }
	if m < 3 then
		y = y - 1
	end
	return (y + math.floor(y / 4) - math.floor(y / 100) + math.floor(y / 400) + t[m] + d) % 7
end

---@return table | nil  {h, m, wday (1 = Sunday), day, month}
-- The console's own clock (local time set in the Vita settings) is used first.
local function now()
	local r = {}
	if getTime then
		local ok, h, m = pcall(getTime)
		if ok and tonumber(h) and tonumber(m) then
			r.h, r.m = h, m
		end
	end
	if getDate then
		local ok, _, day, month, year = pcall(getDate)
		day, month, year = tonumber(day), tonumber(month), tonumber(year)
		if ok and day and month then
			if month > 12 and day <= 12 then
				day, month = month, day -- day and month came in the other order
			end
			if month >= 1 and month <= 12 and day >= 1 and day <= 31 then
				r.day, r.month = day, month
				if year and year > 1970 then
					r.wday = weekday(year, month, day) + 1
				end
			end
		end
	end
	if not r.h and osDate then
		local ok, t = pcall(osDate, "*t")
		if ok and type(t) == "table" and t.hour then
			return { h = t.hour, m = t.min, wday = t.wday, day = t.day, month = t.month }
		end
	end
	if r.h then
		return r
	end
	return nil
end

local function timeText(t)
	local h, m = t.h or 0, t.m or 0
	if Settings.ReaderClock24h then
		return string.format("%02d:%02d", h, m)
	end
	local suffix = h >= 12 and "PM" or "AM"
	h = h % 12
	if h == 0 then
		h = 12
	end
	return string.format("%d:%02d %s", h, m, suffix)
end

---@return string
function RKClock.text(vertical)
	local mode = Settings.ReaderClock
	if mode ~= "time" and mode ~= "date" and mode ~= "both" then
		return ""
	end
	local t = now()
	if not t then
		return ""
	end
	local parts = {}
	if mode == "date" or mode == "both" then
		if t.day and t.month then
			if vertical or not MONTHS[t.month] then
				parts[#parts + 1] = string.format("%d/%d", t.day, t.month) -- numbers only: the rotated view draws digits
			elseif t.wday then
				parts[#parts + 1] = (DAYS[((t.wday - 1) % 7) + 1] or "") .. " " .. t.day .. " " .. MONTHS[t.month]
			else
				parts[#parts + 1] = t.day .. " " .. MONTHS[t.month]
			end
		end
	end
	if mode == "time" or mode == "both" then
		parts[#parts + 1] = timeText(t)
	end
	return table.concat(parts, "  ")
end

-- tiny 3x5 pixel font for the rotated (vertical) reader: digits, ":", "/", "A", "M", "P", space
local GLYPH = {
	["0"] = { "111", "101", "101", "101", "111" }, ["1"] = { "010", "110", "010", "010", "111" },
	["2"] = { "111", "001", "111", "100", "111" }, ["3"] = { "111", "001", "111", "001", "111" },
	["4"] = { "101", "101", "111", "001", "001" }, ["5"] = { "111", "100", "111", "001", "111" },
	["6"] = { "111", "100", "111", "101", "111" }, ["7"] = { "111", "001", "001", "001", "001" },
	["8"] = { "111", "101", "111", "101", "111" }, ["9"] = { "111", "101", "111", "001", "111" },
	[":"] = { "000", "010", "000", "010", "000" }, ["/"] = { "001", "001", "010", "100", "100" },
	["A"] = { "010", "101", "111", "101", "101" }, ["P"] = { "110", "101", "110", "100", "100" },
	["M"] = { "101", "111", "111", "101", "101" }, [" "] = { "000", "000", "000", "000", "000" }
}

-- logical rectangle -> physical rectangle (logical screen is 544 x 960 when rotated)
local function rect(vertical, x1, x2, y1, y2, color)
	if vertical then
		Graphics.fillRect(960 - y2, 960 - y1, x1, x2, color)
	else
		Graphics.fillRect(x1, x2, y1, y2, color)
	end
end

local function glyphs(vertical, text, lx, ly, sc, color)
	for i = 1, #text do
		local g = GLYPH[text:sub(i, i)]
		if g then
			for r = 1, 5 do
				for c = 1, 3 do
					if g[r]:sub(c, c) == "1" then
						local x = lx + (i - 1) * 4 * sc + (c - 1) * sc
						local y = ly + (r - 1) * sc
						rect(vertical, x, x + sc, y, y + sc, color)
					end
				end
			end
		end
	end
end

---Draws the clock in the top-left corner of the reader (hidden while the reader bars are shown)
function RKClock.draw()
	if RK_BarsShown then
		return
	end
	local vertical = RK_ReaderVertical
	local text = RKClock.text(vertical)
	if text == "" then
		return
	end
	if vertical then
		local sc = 2
		local w = #text * 4 * sc - sc
		local x0 = Settings.ReaderClockPos == "right" and (544 - 8 - (w + 12)) or 8 -- rotated view is 544 wide
		rect(true, x0, x0 + w + 12, 8, 8 + 5 * sc + 10, Color.new(0, 0, 0, 150))
		glyphs(true, text, x0 + 6, 13, sc, Color.new(255, 255, 255, 235))
	else
		local w = Font.getTextWidth(FONT16, text) + 16
		local x0 = Settings.ReaderClockPos == "right" and (960 - 8 - w) or 8
		Graphics.fillRect(x0, x0 + w, 8, 34, Color.new(0, 0, 0, 150))
		Font.print(FONT16, x0 + 8, 11, text, Color.new(255, 255, 255, 235))
	end
end

-- setting labels
for _, lang in pairs(Language) do
	if lang.SETTINGS then
		lang.SETTINGS.ReaderClock = "Clock in reader (time / date)"
		lang.SETTINGS.ReaderClockPos = "Clock position (top left / top right)"
		lang.SETTINGS.ReaderClock24h = "Clock 24 hour time"
		lang.SETTINGS_DESCRIPTION = lang.SETTINGS_DESCRIPTION or {}
		lang.SETTINGS_DESCRIPTION.ReaderClock = "Show the time and/or the date (no year) while reading"
		lang.SETTINGS_DESCRIPTION.ReaderClockPos = "Where the clock sits on the reader screen"
		lang.SETTINGS_DESCRIPTION.ReaderClock24h = "ON = 14:30, OFF = 2:30 PM"
	end
end
