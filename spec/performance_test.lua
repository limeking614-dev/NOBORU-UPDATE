-- Run from the repository root: lua spec/performance_test.lua (Lua 5.2+).
local function noop() end
local files, writes, probes, mounted = {}, 0, 0, true
System = {
 doesFileExist = function(path) return files[path] ~= nil end,
 doesDirExist = function() probes = probes + 1; return mounted end,
 openFile = function(path) return path end,
 closeFile = noop,
 readFile = function(path) return files[path] end,
 sizeFile = function(path) return #files[path] end,
 writeFile = function(path, text) files[path] = text; writes = writes + 1 end,
 deleteFile = function(path) files[path] = nil end
}
Settings = { LibrarySorting = 'A-Z' }
function CreateManga(name, link, image, parser)
 return { Name = name, Link = link, ImageLink = image, ParserID = parser }
end
dofile('source/assets/libs/utils.lua')
dofile('source/assets/libs/database.lua')
Database.load()
assert(writes == 0, 'loading an absent library must not rewrite an empty index')
local z = CreateManga('Zebra', '/z', 'z.jpg', 'TEST')
local a = CreateManga('Apple', '/a', 'a.jpg', 'TEST')
a.Location = 'uma0'
Database.addManga(z); Database.addManga(a)
local list = Database.getMangaList()
assert(list[1] == a and list[2] == z)
local originalProbes = probes
for _ = 1, 300 do assert(Database.getMangaList() == list) end
assert(probes == originalProbes, 'idle library frames must not probe storage or rebuild lists')
Settings.LibrarySorting = 'Z-A'
list = Database.getMangaList()
assert(list[1] == z and list[2] == a, 'sorting preference must invalidate the cached order')
a.Name = 'Zulu'; Database.save()
assert(Database.getMangaList()[1] == a, 'renaming must invalidate sorting without changing the item count')
mounted = false; Database.refreshStorage()
list = Database.getMangaList()
assert(#list == 1 and list[1] == z, 'removed external storage must disappear')
mounted = true; Database.refreshStorage()
assert(#Database.getMangaList() == 2, 'reattached external storage must reappear')
Database.removeManga(a)
assert(#Database.getMangaList() == 1)
local before = writes
Database.load()
assert(writes == before and #Database.getMangaList() == 1, 'loading valid data must not rewrite it')

-- Read-only startup must stay read-only, while history changes and repairs persist.
local function finishStartup(fn)
	local worker = coroutine.create(fn)
	while coroutine.status(worker) ~= 'dead' do
		local ok, err = coroutine.resume(worker)
		assert(ok, err)
	end
end
RemoveDirectory = noop
Notifications = { push = noop }
System.getPictureResolution = function() return 800, 1200 end
z.Path = 'cache/TESTz/cover.image'
files['ux0:data/noboru/cache/info.txt'] = 'return ' .. table.serialize({ TESTz = z }, true)
files['ux0:data/noboru/cache/history.dat'] = 'return {}'
dofile('source/assets/libs/cache.lua')
before = writes
finishStartup(Cache.load)
Cache.loadHistory()
assert(writes == before, 'valid cache/history startup must not rewrite indexes')
Cache.makeHistory(z)
assert(writes == before + 1, 'history changes must still be saved immediately')
mounted = false
before = writes
finishStartup(Cache.load)
assert(writes == before + 1 and next(Cache.getManga()) == nil, 'missing cache directories must still repair the index')
mounted = true
System.listDirectory = function(path)
	if path == 'ux0:data/noboru/chapters/good' then return {{ name = 'done.txt' }, { name = '1.image' }} end
	return {}
end
files['ux0:data/noboru/c.c'] = 'Keys = {good = true}'
files['ux0:data/noboru/chapters/good/done.txt'] = '1'
dofile('source/assets/libs/chsaver.lua')
before = writes
finishStartup(ChapterSaver.load)
assert(writes == before, 'valid chapter index must not be rewritten at startup')
files['ux0:data/noboru/c.c'] = 'Keys = {good = true, broken = true}'
finishStartup(ChapterSaver.load)
assert(writes == before + 1 and not files['ux0:data/noboru/c.c']:find('broken'), 'invalid chapter entries must still be repaired and persisted')

local function decode(width, height, memory, limits)
 local result, loads, slices = nil, {}, 0
 local target = {}
 Settings = { BrowserMode = false }
 USERAGENT, GET_METHOD, XWWW, FILTER_LINEAR = 'test', 0, 0, 0
 Color = { new = noop }
 Console = { write = noop, error = noop }
 RemoveDirectory = noop
 System = {
  getAsyncState = function() return 1 end,
  getAsyncResult = function() return result end,
  doesFileExist = function() return true end,
  getPictureResolution = function() return width, height end
 }
 Network = { init = noop, term = noop }
 Graphics = {
  getFreeMemory = function() return memory end,
  loadImageAsync = function(_, scale) loads[#loads + 1] = scale; result = {} end,
  loadPartImageAsync = function() slices = slices + 1; result = {} end
 }
 Image = { new = function(_, handle) return { e = handle, free = noop } end }
 dofile('source/assets/libs/net.lua')
 limits = limits or {}
 limits.Type, limits.Path, limits.Table, limits.Index = 'Image', 'test.image', target, 'Image'
 Threads.addTask(target, limits)
 for _ = 1, 30 do Threads.update() end
 assert(not Threads.isDownloadRunning(), 'image task must complete or fail cleanly')
 return target, loads, slices
end
local target, loads = decode(4000, 6000, 200000, { MaxHeight = 300 })
assert(target.Image and loads[1] == 32, 'thumbnail must fit based on its decoded size, not the original')
target, loads = decode(4000, 2000, 40000, { MaxWidth = 100, MaxHeight = 500 })
assert(target.Image and loads[1] == 64, 'both thumbnail constraints must be respected')
local slices
target, loads, slices = decode(800, 12000, 12000000)
assert(not target.Image and #loads == 0 and slices == 0, 'tall slices must not pretend to use quarter-sized textures')
target, loads, slices = decode(800, 12000, 40000000)
assert(target.Image and target.Image.Width == 800 and target.Image.Height == 12000 and slices == 3)
target, loads = decode(800, 0, 40000000)
assert(not target.Image and #loads == 0, 'invalid dimensions must never reach the decoder')

-- Promotion must preserve unique ownership and never restart the active task.
local pending, started = {}, {}
Network.requestStringAsync = function(link) started[#started + 1] = link end
System.getAsyncResult = function() return 'ok' end
dofile('source/assets/libs/net.lua')
for _, key in ipairs({'background', 'visible', 'other'}) do
 Threads.addTask(key, {Type = 'StringRequest', Link = key, Table = pending, Index = key})
end
Threads.promote('visible')
Threads.update()
Threads.promote('visible')
for _ = 1, 12 do Threads.update() end
assert(table.concat(started, ',') == 'visible,background,other' and pending.visible == 'ok', 'priority must preserve task ownership and completion')
print('Performance checks passed: library reuse/invalidation/storage, startup writes, scaled texture budgets, tall slices, invalid dimensions and queue priority.')
