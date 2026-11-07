-- Run from the repository root: lua spec/grid_settings_test.lua.
dofile('spec/ui_test.lua')
dofile('source/assets/libs/utils.lua')
dofile('source/assets/libs/language.lua')
dofile('source/assets/libs/themes.lua')
local saved
local function noop() end
System.doesFileExist = function(path) return path == 'ux0:data/noboru/settings.ini' and saved ~= nil end
System.openFile = function() return 1 end
System.closeFile = noop
System.deleteFile = noop
System.readFile = function() return saved end
System.sizeFile = function() return #saved end
System.writeFile = function(_, text) saved = text end
GetParserLanguages = function() return {'DIF'} end
Network = { setConnectionTime = noop }
GenPanels = noop
dofile('source/assets/libs/settings.lua')
assert(Settings.GridDisplay == 'Compact grid', 'existing layout must remain the default')
assert(Settings.GridColumns == 4, 'default size must keep four columns')
local listed = false
for _, item in ipairs(Settings.list()) do if item == 'GridDisplay' then listed = true end end
assert(listed, 'display mode must be discoverable in Settings')
for _, expected in ipairs({'Comfortable grid', 'Cover-only', 'Compact grid'}) do
	SettingsFunctions.GridDisplay()
	assert(Settings.GridDisplay == expected, 'setting must cycle through all three modes')
end
Settings.GridDisplay = 'Comfortable grid'
for _, expected in ipairs({5, 3, 4}) do
	SettingsFunctions.GridColumns()
	assert(Settings.GridColumns == expected and Settings.GridDisplay == 'Comfortable grid', 'grid size must change independently of style')
end
Settings.GridColumns = 5
Settings.save()
dofile('source/assets/libs/settings.lua')
Settings.load()
assert(Settings.GridDisplay == 'Comfortable grid', 'saved display mode must survive reload')
assert(Settings.GridColumns == 5, 'saved column count must survive reload')
saved = 'Settings = { Theme = "Light" }'
dofile('source/assets/libs/settings.lua')
Settings.load()
assert(Settings.GridDisplay == 'Compact grid', 'older settings files must keep the compact layout')
assert(Settings.GridColumns == 4, 'older settings must keep four columns')
saved = 'Settings = { GridDisplay = "Invalid mode", GridColumns = 7 }'
dofile('source/assets/libs/settings.lua')
Settings.load()
assert(Settings.GridDisplay == 'Compact grid', 'invalid saved display modes must fall back safely')
assert(Settings.GridColumns == 4, 'invalid column counts must fall back safely')
for _, language in pairs(Language) do assert(language.SETTINGS.GridDisplay and language.SETTINGS_DESCRIPTION.GridDisplay) end
print('Grid settings checks passed: default, discoverability, cycling, persistence, old settings and invalid-value fallback.')
