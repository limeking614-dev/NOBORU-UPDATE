-- Run from the repository root: lua spec/launch_ui_test.lua.
dofile('spec/ui_test.lua')
dofile('source/assets/libs/utils.lua')
local function noop() end
local file = assert(io.open('source/main.lua', 'r'))
local main = file:read('*a'); file:close()
local startup = assert(main:match('(local LoadingTimer = Timer.new%(%).-Timer.destroy%(LoadingTimer%))'))
local logos, labels, progress, destroyed = 0, {}, nil, false
Graphics.initBlend, Graphics.termBlend = noop, noop
Graphics.drawImage = function(x, y, image)
	assert(x == 147 and y == 186 and image == 'original-logo', 'original logo must be centered at its original size')
	logos = logos + 1
end
Graphics.fillRect = function(x1, x2, y1, y2)
	assert(x2 >= x1 and y2 >= y1)
	if x1 == 150 and y1 == 400 then progress = x2 end
end
Font.print = function(_, _, _, text) labels[text] = true end
Screen.flip, Screen.waitVblankStart = noop, noop
Timer.new = function() return {} end
Timer.reset = noop
Timer.getTime = function() return 0 end
Timer.destroy = function() destroyed = true end
Console = {error = function(err) error(err) end}
Settings.SkipCacheChapterChecking = false
local run = assert(load('return function(preloadData, logo) ' .. startup .. ' end'))()
run(function() coroutine.yield('Loading library', 0.5) end, {e = 'original-logo'})
assert(logos == 1 and labels['Loading library'] and progress == 480 and destroyed, 'restored loading screen must show its original logo, status and progress')
assert(UI.capitalize('LIBRARY') == 'Library' and UI.capitalize('PC SOURCES') == 'Pc sources')
assert(UI.capitalize('ÉTÉ') == 'Été' and UI.capitalize('БИБЛИОТЕКА') == 'Библиотека' and UI.capitalize('THƯ VIỆN') == 'Thư viện', 'sentence-case labels must preserve supported scripts')
print('Launch checks passed: original logo/status/progress, safe completion, timer cleanup and sentence-case labels.')
