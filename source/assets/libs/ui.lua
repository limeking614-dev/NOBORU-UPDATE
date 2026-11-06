-- Lightweight shared UI primitives; uses only the bundled runtime's drawing API.
UI = { dt = 1000 / 60 }
local ticker = Timer.new()
local sidebarBands = {}
local sidebarTheme
local fallbackRoles = { SURFACE = "SELECTED", HEADER = "BACK", PRIMARY = "ROYAL_BLUE",
	ON_PRIMARY = "WHITE", ON_PANEL = "FONT", SIDEBAR_TOP = "BLACK", SIDEBAR_BOTTOM = "BLACK",
	SIDEBAR_FONT = "WHITE", BORDER = "SUBFONT", HIGHLIGHT = "WHITE", SUCCESS = "ROYAL_BLUE",
	DANGER = "CRIMSON", OVERLAY = "BLACK" }

-- Lowercase UI labels without altering the stored names or URLs.
function UI.lower(text)
	text = tostring(text or ""):lower()
	if not u8c then return text end
	return (text:gsub("[\194-\244][\128-\191]+", function(char)
		local a, b, c, d = char:byte(1, 4)
		if (a >= 240 and not d) or (a >= 224 and not c) then return char end
		local code = a < 224 and (a - 192) * 64 + b - 128 or a < 240 and (a - 224) * 4096 + (b - 128) * 64 + c - 128 or (a - 240) * 262144 + (b - 128) * 4096 + (c - 128) * 64 + d - 128
		if (code >= 0x00c0 and code <= 0x00d6) or (code >= 0x00d8 and code <= 0x00de) or (code >= 0x0391 and code <= 0x03a1) or (code >= 0x03a3 and code <= 0x03ab) or (code >= 0x0410 and code <= 0x042f) then return u8c(code + 32) end
		if code >= 0x0400 and code <= 0x040f then return u8c(code + 80) end
		if code == 0x0130 then return "i" end
		if code == 0x0178 then return u8c(0x00ff) end
		if code == 0x01af then return u8c(0x01b0) end
		if code == 0x1e9e then return u8c(0x00df) end
		if code % 2 == 0 and ((code >= 0x0100 and code <= 0x012f) or (code >= 0x0132 and code <= 0x0137) or (code >= 0x014a and code <= 0x0177) or code == 0x01a0 or (code >= 0x01de and code <= 0x01ef) or (code >= 0x01f8 and code <= 0x0233) or (code >= 0x1e00 and code <= 0x1e95) or (code >= 0x1ea0 and code <= 0x1eff)) then return u8c(code + 1) end
		if code % 2 == 1 and ((code >= 0x0139 and code <= 0x0148) or (code >= 0x0179 and code <= 0x017e) or (code >= 0x01cd and code <= 0x01dc)) then return u8c(code + 1) end
		return char
	end))
end

function UI.capitalize(text)
	local lower = UI.lower(text)
	return (lower:gsub("^[%z\1-\127\194-\244][\128-\191]*", function(char)
		local a, b, c, d = char:byte(1, 4)
		if a < 128 then return char:upper() end
		if not u8c or (a >= 240 and not d) or (a >= 224 and not c) then return char end
		local code = a < 224 and (a - 192) * 64 + b - 128 or a < 240 and (a - 224) * 4096 + (b - 128) * 64 + c - 128 or (a - 240) * 262144 + (b - 128) * 4096 + (c - 128) * 64 + d - 128
		if (code >= 0x00e0 and code <= 0x00f6) or (code >= 0x00f8 and code <= 0x00fe) or (code >= 0x03b1 and code <= 0x03c1) or (code >= 0x03c3 and code <= 0x03cb) or (code >= 0x0430 and code <= 0x044f) then return u8c(code - 32) end
		if code >= 0x0450 and code <= 0x045f then return u8c(code - 80) end
		if code == 0x00ff then return u8c(0x0178) end
		if code == 0x01b0 then return u8c(0x01af) end
		if code % 2 == 1 and ((code >= 0x0101 and code <= 0x0137) or (code >= 0x014b and code <= 0x0177) or code == 0x01a1 or (code >= 0x01df and code <= 0x01ef) or (code >= 0x01f9 and code <= 0x0233) or (code >= 0x1e01 and code <= 0x1e95) or (code >= 0x1ea1 and code <= 0x1eff)) then return u8c(code - 1) end
		if code % 2 == 0 and ((code >= 0x013a and code <= 0x0148) or (code >= 0x017a and code <= 0x017e) or (code >= 0x01ce and code <= 0x01dc)) then return u8c(code - 1) end
		return char
	end, 1))
end

function UI.playIcon(x, y, size, color)
	for column = 0, size - 1 do
		local half = (size - column) / 2
		Graphics.fillRect(x + column, x + column + 1, y + size / 2 - half, y + size / 2 + half, color)
	end
end

function UI.color(role, opacity)
	local palette = Themes[Settings.Theme] or Themes.Light
	local color = palette["COLOR_" .. role] or _G["COLOR_" .. role] or _G["COLOR_" .. (fallbackRoles[role] or "WHITE")] or COLOR_WHITE
	if opacity == nil or opacity == 1 then return color end
	return Color.new(Color.getR(color), Color.getG(color), Color.getB(color), Color.getA(color) * (opacity or 1))
end

function UI.update()
	UI.dt = math.min(50, math.max(1, Timer.getTime(ticker)))
	Timer.reset(ticker)
end

function UI.approach(value, target, ms)
	local nextValue = value + (target - value) * (1 - math.exp(-UI.dt / ms))
	return math.abs(nextValue - target) < 0.01 and target or nextValue
end

function UI.sidebar()
	if sidebarTheme ~= Settings.Theme then
		sidebarTheme = Settings.Theme
		for i = 0, 23 do sidebarBands[i + 1] = COLOR_GRADIENT(UI.color("SIDEBAR_TOP"), UI.color("SIDEBAR_BOTTOM"), i / 23) end
	end
	for i = 1, #sidebarBands do
		Graphics.fillRect(0, 205, (i - 1) * 23, math.min(i * 23, 544), sidebarBands[i])
	end
	Graphics.fillRect(204, 205, 0, 544, UI.color("SIDEBAR_FONT", 0.18))
end

-- Small rounded corners without extra textures or runtime extensions.
function UI.roundRect(x1, x2, y1, y2, color)
	if x2 - x1 < 8 or y2 - y1 < 8 then
		Graphics.fillRect(x1, x2, y1, y2, color)
		return
	end
	Graphics.fillRect(x1 + 4, x2 - 4, y1, y2, color)
	Graphics.fillRect(x1 + 2, x1 + 4, y1 + 1, y2 - 1, color)
	Graphics.fillRect(x2 - 4, x2 - 2, y1 + 1, y2 - 1, color)
	Graphics.fillRect(x1, x1 + 2, y1 + 4, y2 - 4, color)
	Graphics.fillRect(x2 - 2, x2, y1 + 4, y2 - 4, color)
end

-- Cache circular corner profiles so drawing cards needs no per-frame square roots.
local corners = {}
local function corner(radius)
	if not corners[radius] then
		local profile = {}
		for row = 0, radius - 1 do
			local dy = radius - row - 0.5
			profile[row + 1] = math.floor(radius - math.sqrt(radius * radius - dy * dy) + 0.5)
		end
		corners[radius] = profile
	end
	return corners[radius]
end

-- Filled rounded surfaces can sit over a dimmed scene without erasing it.
function UI.fillRoundRect(x1, x2, y1, y2, radius, color)
	Graphics.fillRect(x1, x2, y1 + radius, y2 - radius, color)
	for row, inset in ipairs(corner(radius)) do
		Graphics.fillRect(x1 + inset, x2 - inset, y1 + row - 1, y1 + row, color)
		Graphics.fillRect(x1 + inset, x2 - inset, y2 - row, y2 - row + 1, color)
	end
end

-- Cover images remain unchanged; erase only the pixels outside rounded corners.
function UI.roundCorners(x1, x2, y1, y2, radius, background)
	for row, inset in ipairs(corner(radius)) do
		if inset > 0 then
			Graphics.fillRect(x1, x1 + inset, y1 + row - 1, y1 + row, background)
			Graphics.fillRect(x2 - inset, x2, y1 + row - 1, y1 + row, background)
			Graphics.fillRect(x1, x1 + inset, y2 - row, y2 - row + 1, background)
			Graphics.fillRect(x2 - inset, x2, y2 - row, y2 - row + 1, background)
		end
	end
end

function UI.roundBorder(x1, x2, y1, y2, radius, thickness, color)
	local outer, inner = corner(radius), corner(radius - thickness)
	for row = 0, radius - 1 do
		local outside = outer[row + 1]
		if row < thickness then
			Graphics.fillRect(x1 + outside, x2 - outside, y1 + row, y1 + row + 1, color)
			Graphics.fillRect(x1 + outside, x2 - outside, y2 - row - 1, y2 - row, color)
		else
			local inside = thickness + inner[row - thickness + 1]
			Graphics.fillRect(x1 + outside, x1 + inside, y1 + row, y1 + row + 1, color)
			Graphics.fillRect(x2 - inside, x2 - outside, y1 + row, y1 + row + 1, color)
			Graphics.fillRect(x1 + outside, x1 + inside, y2 - row - 1, y2 - row, color)
			Graphics.fillRect(x2 - inside, x2 - outside, y2 - row - 1, y2 - row, color)
		end
	end
	Graphics.fillRect(x1, x1 + thickness, y1 + radius, y2 - radius, color)
	Graphics.fillRect(x2 - thickness, x2, y1 + radius, y2 - radius, color)
end

-- Shared focus treatment for cover tiles and catalog source cards.
function UI.focusBorder(left, right, top, bottom, radius, opacity)
	opacity = opacity or 1
	local pulse = (1 - math.cos(Timer.getTime(GlobalTimer) * math.pi / 900)) / 2
	for spread = 3, 1, -1 do
		UI.roundBorder(left - spread, right + spread, top - spread, bottom + spread, radius + spread, 1, UI.color("SELECTOR", (22 + 36 * pulse) * (4 - spread) / 765 * opacity))
	end
	UI.roundBorder(left, right, top, bottom, radius, 2, UI.color("SELECTOR", (165 + 90 * pulse) / 255 * opacity))
	UI.roundBorder(left + 2, right - 2, top + 2, bottom - 2, radius - 2, 1, UI.color("HIGHLIGHT", (65 + 105 * pulse) / 255 * opacity))
end

function UI.listCard(top, bottom, active)
	local background = active and COLOR_SELECTED or UI.color("SURFACE")
	Graphics.fillRect(215, 945, top, bottom, background)
	UI.roundCorners(215, 945, top, bottom, 10, COLOR_BACK)
	UI.roundBorder(215, 945, top, bottom, 10, 1, UI.color("BORDER"))
end
