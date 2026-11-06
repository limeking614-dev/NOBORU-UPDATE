-- Run from the repository root: lua spec/launch_ui_test.lua.
dofile('spec/ui_test.lua')
dofile('source/assets/libs/utils.lua')
dofile('source/assets/libs/themes.lua')
local now = 0
Timer.new = function() return { start = now } end
Timer.getTime = function(timer) return now - timer.start end
local bars, labels, background = {}, {}, nil
Graphics.fillRect = function(x1, x2, y1, y2, color)
	assert(x2 >= x1 and y2 >= y1)
	if y1 == 382 then bars[#bars + 1] = { x1, x2 } end
	if x1 == 0 and x2 == 960 and y1 == 0 and y2 == 544 then background = color end
end
Graphics.createImage = function() error('launch UI must not allocate image textures') end
Font.print = function(_, _, _, text) labels[text] = true end
dofile('source/assets/libs/splash.lua')
Splash.draw('Loading library')
assert(Color.getR(background) == 0 and labels['loading library'] and labels.noboru, 'first frame must stay dark and show a lowercase status')
Settings.Theme, Splash.ready = 'OLED', true
for _, progress in ipairs({-1, 0, 0.5, 1, 2}) do
	bars = {}
	Splash.draw('Loading cache', progress)
	for _, bar in ipairs(bars) do assert(bar[1] >= 300 and bar[2] <= 660, 'progress must stay within its track') end
end
now, bars = 2000, {}
Splash.draw('Checking saved chapters', nil, 0.5)
assert(Color.getA(background) == 127.5, 'launch screen must support fading into the app')
assert(#bars == 2 and bars[2][2] - bars[2][1] == 80, 'unknown progress must animate without a fake percentage')
assert(UI.lower('LIBRARY ÉTÉ БИБЛИОТЕКА THƯ VIỆN') == 'library été библиотека thư viện', 'UI lowercase must handle supported Latin/Cyrillic labels')
print('Launch UI checks passed: dark first frame, themed OLED screen, bounded progress, indeterminate animation, lowercase labels and fade.')
