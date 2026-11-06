Themes = {
	Dark = {
		COLOR_COVER = Color.new(101, 115, 146),
		COLOR_LEFT_BACK = Color.new(0, 0, 0),
		COLOR_FONT = Color.new(255, 255, 255),
		COLOR_SUBFONT = Color.new(128, 128, 128),
		COLOR_BACK = Color.new(0, 0, 0),
		COLOR_SELECTED = Color.new(24, 24, 24),
		COLOR_PANEL = Color.new(72, 72, 72),
		COLOR_ICON_EXTRACT = Color.new(255, 255, 255),
		COLOR_LABEL = Color.new(137, 30, 43),
		COLOR_SELECTOR = Color.new(65, 105, 226)
	},
	Light = {
		COLOR_COVER = Color.new(101, 115, 146),
		COLOR_LEFT_BACK = Color.new(0, 0, 0),
		COLOR_FONT = Color.new(0, 0, 0),
		COLOR_SUBFONT = Color.new(128, 128, 128),
		COLOR_BACK = Color.new(255, 255, 255),
		COLOR_SELECTED = Color.new(200, 200, 200),
		COLOR_PANEL = Color.new(209, 209, 209),
		COLOR_ICON_EXTRACT = Color.new(0, 0, 0),
		COLOR_LABEL = Color.new(137, 30, 43),
		COLOR_SELECTOR = Color.new(65, 105, 226)
	},
	Blue = {
		COLOR_COVER = Color.new(101, 115, 146),
		COLOR_LEFT_BACK = Color.new(15, 17, 50),
		COLOR_FONT = Color.new(0, 0, 0),
		COLOR_SUBFONT = Color.new(128, 128, 128),
		COLOR_BACK = Color.new(255, 255, 255),
		COLOR_SELECTED = Color.new(200, 200, 200),
		COLOR_PANEL = Color.new(209, 209, 209),
		COLOR_ICON_EXTRACT = Color.new(0, 0, 0),
		COLOR_LABEL = Color.new(65, 105, 226),
		COLOR_SELECTOR = Color.new(65, 105, 226)
	},
	Crimson = {
		COLOR_COVER = Color.new(101, 115, 146),
		COLOR_LEFT_BACK = Color.new(137, 30, 43),
		COLOR_FONT = Color.new(0, 0, 0),
		COLOR_SUBFONT = Color.new(128, 128, 128),
		COLOR_BACK = Color.new(255, 255, 255),
		COLOR_SELECTED = Color.new(200, 200, 200),
		COLOR_PANEL = Color.new(209, 209, 209),
		COLOR_ICON_EXTRACT = Color.new(0, 0, 0),
		COLOR_LABEL = Color.new(137, 30, 43),
		COLOR_SELECTOR = Color.new(65, 105, 226)
	},
	PiCrestOne = {
		COLOR_COVER = Color.new(101, 115, 146),
		COLOR_LEFT_BACK = Color.new(0, 0, 0),
		COLOR_FONT = Color.new(255, 255, 255),
		COLOR_SUBFONT = Color.new(128, 128, 128),
		COLOR_BACK = Color.new(0, 0, 0),
		COLOR_SELECTED = Color.new(24, 24, 24),
		COLOR_PANEL = Color.new(200, 0, 64),
		COLOR_ICON_EXTRACT = Color.new(255, 255, 255),
		COLOR_LABEL = Color.new(4, 100, 100),
		COLOR_SELECTOR = Color.new(104, 0, 200)
	}
}

local function rgb(hex)
	return Color.new(math.floor(hex / 65536) % 256, math.floor(hex / 256) % 256, hex % 256)
end

local function palette(back, surface, font, muted, accent, sidebar, primary)
	return {
		COLOR_BACK = rgb(back), COLOR_SELECTED = rgb(surface), COLOR_SURFACE = rgb(surface),
		COLOR_FONT = rgb(font), COLOR_SUBFONT = rgb(muted), COLOR_SELECTOR = rgb(accent),
		COLOR_LEFT_BACK = rgb(sidebar), COLOR_PANEL = rgb(surface), COLOR_HEADER = rgb(surface),
		COLOR_PRIMARY = rgb(primary), COLOR_LABEL = rgb(primary), COLOR_COVER = rgb(surface),
		COLOR_ICON_EXTRACT = rgb(font)
	}
end

Themes.Midnight = palette(0x0e1827, 0x16273b, 0xf0f6ff, 0xa2b8d0, 0x69c5ff, 0x122236, 0x1b6c9d)
Themes.Forest = palette(0x101e19, 0x1c3128, 0xe8f4ed, 0xa0bdac, 0x7cdaa6, 0x14291e, 0x226a48)
Themes.Sepia = palette(0xf4ead7, 0xe8dac0, 0x392d20, 0x6c5a42, 0x87551f, 0xe1d0ae, 0x80501f)
Themes.OLED = palette(0x000000, 0x000000, 0xf4f4f4, 0xb0b0b0, 0x66d9ef, 0x000000, 0x145464)
Themes.OLED.COLOR_BORDER = rgb(0x424242)
Themes.OLED.COLOR_PANEL = rgb(0x000000)

local function contrasting(color)
	local function linear(c)
		c = c / 255
		return c <= 0.04045 and c / 12.92 or ((c + 0.055) / 1.055) ^ 2.4
	end
	local luma = 0.2126 * linear(Color.getR(color)) + 0.7152 * linear(Color.getG(color)) + 0.0722 * linear(Color.getB(color))
	return (luma + 0.05) / 0.05 > 1.05 / (luma + 0.05) and rgb(0x101010) or rgb(0xffffff)
end

-- Preserve saved legacy theme names and extend every palette with shared UI roles.
Themes.Crimson.COLOR_SELECTOR = Themes.Crimson.COLOR_LABEL
local themes = {"Light", "Dark", "Blue", "Crimson", "PiCrestOne", "Midnight", "Forest", "Sepia", "OLED"}
for _, name in ipairs(themes) do
	local p = Themes[name]
	if Color.getR(p.COLOR_FONT) == 0 then p.COLOR_SUBFONT = rgb(0x606060) end
	p.COLOR_SURFACE = p.COLOR_SURFACE or COLOR_GRADIENT(p.COLOR_BACK, p.COLOR_SELECTED, 0.45)
	p.COLOR_HEADER = p.COLOR_HEADER or p.COLOR_PANEL
	p.COLOR_PRIMARY = p.COLOR_PRIMARY or p.COLOR_SELECTOR
	p.COLOR_ON_PRIMARY = contrasting(p.COLOR_PRIMARY)
	p.COLOR_ON_PANEL = contrasting(p.COLOR_PANEL)
	p.COLOR_SIDEBAR_TOP = p.COLOR_LEFT_BACK
	p.COLOR_SIDEBAR_BOTTOM = name == "OLED" and p.COLOR_LEFT_BACK or COLOR_GRADIENT(p.COLOR_LEFT_BACK, rgb(0x000000), 0.35)
	p.COLOR_SIDEBAR_FONT = contrasting(p.COLOR_LEFT_BACK)
	p.COLOR_BORDER = p.COLOR_BORDER or COLOR_GRADIENT(p.COLOR_BACK, p.COLOR_FONT, 0.3)
	p.COLOR_HIGHLIGHT = COLOR_GRADIENT(p.COLOR_SELECTOR, p.COLOR_FONT, 0.45)
	p.COLOR_SUCCESS = Color.getR(p.COLOR_FONT) > 128 and rgb(0x50ce95) or rgb(0x187446)
	p.COLOR_DANGER = Color.getR(p.COLOR_FONT) > 128 and rgb(0xf3818f) or rgb(0xa32339)
	p.COLOR_ON_DANGER = contrasting(p.COLOR_DANGER)
	p.COLOR_OVERLAY = rgb(0x000000)
end

for _, language in pairs(Language) do
	language.THEME = language.THEME or {}
	for _, name in ipairs(themes) do language.THEME[name] = language.THEME[name] or name end
end

---@return table
---Gives list of all available themes
function GetThemes()
	return themes
end
