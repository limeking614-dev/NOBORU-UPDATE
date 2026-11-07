-- Run from the repository root: lua spec/reader_performance_test.lua.
dofile('spec/ui_test.lua')
local function noop() end
local pending, requested, loaded, freed = {}, {}, 0, 0
local function enqueue(key, task)
 if pending[key] then return false end
 pending[key] = task
 requested[#requested + 1] = task.Path
 return true
end
Threads = { addTask = enqueue, insertTask = enqueue,
 check = function(key) return pending[key] ~= nil end,
 remove = function(key) pending[key] = nil end }
ParserManager = { check = function() return false end, remove = noop }
GetGPUMemoryUsed = function() return loaded * 800 * 1200 * 4 end
MAX_VRAM_MEMORY = 88 * 1024 * 1024
local chapters = {{ Manga = {}, Pages = {} }}
for i = 1, 300 do chapters[1].Pages[i] = { Path = i .. '.image' } end
dofile('source/assets/libs/webtoon.lua')
local function context(page)
 return { chapters = chapters, index = 1, startPage = page }
end
local function finishRequests()
 for owner, task in pairs(pending) do
  pending[owner] = nil
  loaded = loaded + 1
  local alive = true
  owner.Image = { Width = 800, Height = 1200, e = 1, free = function()
   assert(alive, 'texture must be freed once')
   alive = false; loaded = loaded - 1; freed = freed + 1
  end }
 end
end
Webtoon.begin(context(150))
for _ = 1, 120 do finishRequests(); Webtoon.update() end
assert(loaded == 7 and #requested == 7, 'idle reading must retain only the nearby seven-page window')
for _, path in ipairs(requested) do
 local page = tonumber(path:match('%d+'))
 assert(page >= 148 and page <= 154, 'distant pages must not be prefetched')
end
Webtoon.begin(context(250))
assert(freed == 7, 'changing reader context must release old native textures')
for _ = 1, 120 do finishRequests(); Webtoon.update() end
assert(loaded == 7 and #requested == 14, 'new context must have its own bounded window')
Webtoon.free()
assert(loaded == 0 and next(pending) == nil, 'leaving the reader must release textures and pending work')
print('Reader performance checks passed: bounded prefetch, nearby retention, chapter cleanup and cancellation.')

-- Exercise the paged reader's actual chapter-entry and chapter-change paths too.
function CreatePoint(x, y) return { x = x, y = y } end
Console = { write = noop, error = function(err) error(err) end }
Settings.ReaderDirection, Settings.Orientation = 'RIGHT', 'Horizontal'
Settings.ZoomReader, Settings.ReaderMode = 'Fit', 'Paged'
CuSettings = { load = function() return {
 ReaderDirection = 'Default', Orientation = 'Default', ZoomReader = 'Default', ReaderView = 'Paged'
} end }
Cache = { getBookmark = function() return 1 end }
ChapterSaver = {
 check = function() return true end,
 getChapter = function(chapter) return chapter.saved end
}
local order = {}
Threads.insertTask = function(owner, task) order[#order + 1] = 'visible:' .. task.Path; return enqueue(owner, task) end
Threads.addTask = function(owner, task) order[#order + 1] = 'prefetch:' .. task.Path; return enqueue(owner, task) end
local paged = {}
for i = 1, 2 do
 paged[i] = {Manga = {}, saved = {{Path = i .. '-1.image'}, {Path = i .. '-2.image'}, Done = true}}
end
dofile('source/assets/libs/reader.lua')
Reader.load(paged, 1)
Reader.update()
assert(order[1] == 'visible:1-1.image' and order[2] == 'prefetch:1-2.image', 'chapter entry must prioritize the visible page and begin prefetch immediately')
finishRequests()
assert(loaded == 2)
Reader.loadChapter(2)
assert(loaded == 0 and next(pending) == nil, 'paged chapter changes must free old textures and cancel old work')
Reader.update()
assert(order[3] == 'visible:2-1.image' and order[4] == 'prefetch:2-2.image')
Reader.loadChapter(1)
assert(next(pending) == nil, 'changing chapter during loading must cancel pending work')
print('Paged reader checks passed: immediate visible-page priority, prefetch, native texture cleanup and pending-task cancellation.')
