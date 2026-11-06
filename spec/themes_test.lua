-- Run from the repository root: lua spec/themes_test.lua.
dofile('spec/details_ui_test.lua')
dofile('source/assets/libs/themes.lua')
local function same(a, b)
	return Color.getR(a) == Color.getR(b) and Color.getG(a) == Color.getG(b) and Color.getB(a) == Color.getB(b)
end
local function luminance(c)
	local function linear(n)
		n = n / 255
		return n <= 0.04045 and n / 12.92 or ((n + 0.055) / 1.055) ^ 2.4
	end
	return 0.2126 * linear(Color.getR(c)) + 0.7152 * linear(Color.getG(c)) + 0.0722 * linear(Color.getB(c))
end
local function contrast(a, b)
	local x, y = luminance(a), luminance(b)
	return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05)
end
assert(#GetThemes() == 9, 'theme list must contain the five legacy themes and four additions')
local roles = {'BACK', 'SURFACE', 'FONT', 'SUBFONT', 'SELECTED', 'PRIMARY', 'ON_PRIMARY', 'HEADER', 'SIDEBAR_FONT', 'BORDER', 'SELECTOR', 'SUCCESS', 'DANGER', 'ON_DANGER', 'ON_PANEL'}
local primaryColor, backgroundColor, titleColor, sidebarColor, popupColor, spinnerColor
local fill = UI.fillRoundRect
UI.fillRoundRect = function(left, right, top, bottom, radius, color)
	if left == 30 and top == 420 then primaryColor = color end
	if left == 160 and radius == 16 then popupColor = color end
	return fill(left, right, top, bottom, radius, color)
end
Graphics.fillRect = function(left, right, top, bottom, color)
	if left == 0 and right == 960 and top == 0 and bottom == 544 then backgroundColor = color end
	if left == 0 and right == 205 and top == 0 then sidebarColor = color end
end
Font.print = function(_, _, _, text, color)
	if text == 'theme test' then titleColor = color end
end
Timer.getTime = function() return 100000 end
Graphics.drawImage = function(_, _, image, color)
	if image == 'app0:assets/icons/circle.png' then spinnerColor = color end
end
dofile('source/assets/libs/loading.lua')
Browser = { getCookies = function() return {} end }
VitaSurf = nil
Settings.CFCheck = true
dofile('source/assets/libs/cfcheck.lua')
for _, name in ipairs(GetThemes()) do
	local palette = assert(Themes[name])
	for _, role in ipairs(roles) do assert(palette['COLOR_' .. role], name .. ' missing ' .. role) end
	assert(contrast(palette.COLOR_FONT, palette.COLOR_SURFACE) >= 4.5, name .. ': body contrast')
	assert(contrast(palette.COLOR_SUBFONT, palette.COLOR_BACK) >= 4.5, name .. ': secondary contrast')
	assert(contrast(palette.COLOR_ON_PRIMARY, palette.COLOR_PRIMARY) >= 4.5, name .. ': button contrast')
	assert(contrast(palette.COLOR_SIDEBAR_FONT, palette.COLOR_LEFT_BACK) >= 4.5, name .. ': sidebar contrast')
	Settings.Theme = name
	for key, color in pairs(palette) do _G[key] = color end
	AppMode = MENU
	Details.setManga({Name = 'Theme test', ParserID = 'TEST', RawLink = ''})
	Details.update()
	Details.update()
	Details.draw()
	assert(same(backgroundColor, palette.COLOR_BACK), name .. ': Details background ignored theme')
	assert(same(titleColor, palette.COLOR_FONT), name .. ': Details title ignored theme')
	assert(same(primaryColor, palette.COLOR_PRIMARY), name .. ': CTA ignored theme')
	UI.sidebar()
	assert(same(sidebarColor, palette.COLOR_LEFT_BACK), name .. ': stale sidebar palette')
	CFCheck.begin({ID = 'TEST', Link = 'https://example.invalid'}, function() end)
	CFCheck.draw()
	assert(same(popupColor, palette.COLOR_SURFACE), name .. ': popup ignored theme')
	CFCheck.input(0, SCE_CTRL_CIRCLE)
	Loading.setStatus('WHITE')
	Loading.draw()
	assert(same(spinnerColor, palette.COLOR_FONT), name .. ': loading indicator ignored theme')
	assert(Language.English.THEME[name], name .. ': missing theme label')
end
for _, role in ipairs({'BACK', 'SURFACE', 'HEADER', 'LEFT_BACK', 'PANEL'}) do
	assert(luminance(Themes.OLED['COLOR_' .. role]) == 0, 'OLED ' .. role .. ' must be true black')
end
print('Theme checks passed: legacy names, new themes, text contrast, live switching, Details/sidebar/popup rendering and true-black OLED surfaces.')
