-- Run from the repository root: lua spec/catalog_performance_test.lua.
dofile('spec/pages_ui_test.lua')
local requests, removals, freed, scans = 0, 0, 0, 0
local drawing = false
local function noop() end
Details.getManga = function() return nil end
System.doesFileExist = function() return false end
System.doesDirExist = function() return false end
System.listDirectory = function()
 assert(not drawing, 'drawing must not enumerate directories')
 scans = scans + 1
 local entries = {}
 for i = 1, 100 do entries[i] = { name = i .. '.image', size = 10 } end
 return entries
end
CustomCovers = { hasCustomCover = function() return false end }
Cache = { isCached = function() return false end, getKey = function(m) return m.Name end }
local library = {}
for i = 1, 40 do library[i] = {Name = 'Manga ' .. i, ImageLink = i .. '.jpg'} end
Database = { getMangaList = function() return library end, check = function() return false end }
Threads = { check = function() return false end, remove = function() removals = removals + 1 end,
 addTask = function(_, task)
  requests = requests + 1
  local alive = true
  task.Table[task.Index] = { Type = 'image', e = requests, free = function()
   assert(alive, 'cover must be freed only once'); alive = false; freed = freed + 1
  end }
  task.OnFinalComplete()
 end }
dofile('source/assets/libs/catalogs.lua')
Catalogs.setStatus('LIBRARY')
Catalogs.update()
assert(requests == 2, 'visible covers must start immediately and work must be bounded per update')
for _ = 1, 10 do Catalogs.update() end
local before = requests
local cancellations = removals
Catalogs.input(0, 0, {x = 300, y = 400}, {x = 300, y = 400})
Catalogs.input(0, 0, {x = 300, y = 400}, {x = 300, y = 390})
Catalogs.update()
assert(removals == cancellations, 'movement within the retained window must not cancel cover work')
Catalogs.input(0, 0, {x = 300, y = 390}, {})
for _ = 1, 5 do Catalogs.update() end
assert(requests <= before + Grid.layout().columns, 'nearby navigation must reuse loaded covers')
local replacement = {}
for i = 1, 40 do replacement[i] = {Name = 'Replacement ' .. i, ImageLink = i .. '.jpg'} end
library = replacement
Catalogs.update()
local drawn
DrawManga = function(_, _, manga) drawn = drawn or manga end
Catalogs.draw()
assert(drawn == replacement[1] and freed > 0, 'same-length replacement must refresh titles and release old covers')

Settings.list = function() return {'ClearChapters', 'ClearAllCache'} end
Settings.isTab = function() return false end
Settings.getTab = function() return 'Main' end
Panels.SETTINGS = {}
Catalogs.setStatus('SETTINGS')
Catalogs.update()
local labels = {}
Font.print = function(_, _, _, text) labels[tostring(text)] = true end
BytesToStr = function(value) return tostring(value) .. ' bytes' end
local function draw()
 drawing = true; Catalogs.draw(); drawing = false
end
draw()
assert(scans == 0 and labels['...'], 'size rows must display a placeholder without filesystem work')
for _ = 1, 30 do Catalogs.update(); draw() end
assert(scans == 2 and labels['1000 bytes'], 'size scans must finish incrementally and run once per root')
print('Catalog performance checks passed: immediate bounded cover loading, retained covers, same-length library refresh and incremental filesystem scans.')
