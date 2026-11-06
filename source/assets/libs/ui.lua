-- Lightweight shared UI primitives; uses only the bundled runtime's drawing API.
UI = { dt = 1000 / 60 }
local ticker = Timer.new()
local sidebarBands = {}
for i = 0, 23 do
	sidebarBands[i + 1] = COLOR_GRADIENT(Color.new(22, 104, 174), Color.new(9, 30, 65), i / 23)
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
	for i = 1, #sidebarBands do
		Graphics.fillRect(0, 205, (i - 1) * 23, math.min(i * 23, 544), sidebarBands[i])
	end
	Graphics.fillRect(204, 205, 0, 544, Color.new(255, 255, 255, 45))
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
		UI.roundBorder(left - spread, right + spread, top - spread, bottom + spread, radius + spread, 1, Color.new(65, 166, 255, (22 + 36 * pulse) * (4 - spread) / 3 * opacity))
	end
	UI.roundBorder(left, right, top, bottom, radius, 2, Color.new(75, 174, 255, (165 + 90 * pulse) * opacity))
	UI.roundBorder(left + 2, right - 2, top + 2, bottom - 2, radius - 2, 1, Color.new(181, 232, 255, (65 + 105 * pulse) * opacity))
end

function UI.listCard(top, bottom, active)
	local background = active and COLOR_SELECTED or COLOR_GRADIENT(COLOR_BACK, COLOR_SELECTED, 0.45)
	Graphics.fillRect(215, 945, top, bottom, background)
	UI.roundCorners(215, 945, top, bottom, 10, COLOR_BACK)
	UI.roundBorder(215, 945, top, bottom, 10, 1, Color.new(128, 148, 168, 85))
end
