-- Lightweight launch screen: no additional textures or background processing.
Splash = { ready = false }
local timer = Timer.new()

local function color(role, opacity)
	if Splash.ready then return UI.color(role, opacity) end
	local initial = { BACK = COLOR_BLACK, FONT = COLOR_WHITE, SUBFONT = COLOR_LIGHT_GRAY or COLOR_GRAY,
		PRIMARY = COLOR_ROYAL_BLUE, ON_PRIMARY = COLOR_WHITE, BORDER = COLOR_GRAY, SELECTOR = COLOR_ROYAL_BLUE }
	local c = initial[role] or COLOR_WHITE
	return Color.new(Color.getR(c), Color.getG(c), Color.getB(c), 255 * opacity)
end

function Splash.draw(message, progress, opacity)
	local a = opacity or 1
	Graphics.fillRect(0, 960, 0, 544, color("BACK", a))
	UI.fillRoundRect(454, 506, 156, 216, 8, color("PRIMARY", a))
	Graphics.fillRect(463, 465, 168, 204, color("ON_PRIMARY", 0.65 * a))
	for y = 172, 192, 10 do Graphics.fillRect(475, 495, y, y + 2, color("ON_PRIMARY", 0.8 * a)) end
	local name = "noboru"
	Font.print(BONT30, 480 - Font.getTextWidth(BONT30, name) / 2, 238, name, color("FONT", a))
	local tagline = "manga & comics"
	Font.print(FONT16, 480 - Font.getTextWidth(FONT16, tagline) / 2, 282, tagline, color("SUBFONT", a))
	message = FitText(FONT16, UI.lower(message or "starting…"), 640)
	Font.print(FONT16, 480 - Font.getTextWidth(FONT16, message) / 2, 343, message, color("SUBFONT", a))
	UI.roundRect(300, 660, 382, 388, color("BORDER", 0.35 * a))
	if type(progress) == "number" then
		local width = 360 * math.max(0, math.min(1, progress))
		if width > 0 then UI.roundRect(300, 300 + width, 382, 388, color("SELECTOR", a)) end
	else
		local x = 300 + 280 * (0.5 - 0.5 * math.cos(Timer.getTime(timer) / 650))
		UI.roundRect(x, x + 80, 382, 388, color("SELECTOR", a))
	end
end
