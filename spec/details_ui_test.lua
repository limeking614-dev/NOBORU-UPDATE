-- Run from the repository root: lua spec/details_ui_test.lua.
dofile('spec/ui_test.lua')
dofile('source/assets/libs/utils.lua')
dofile('source/assets/libs/language.lua')
local function noop() end
CreatePoint = function(x, y) return { x = x, y = y } end
IsCJK = function() return false end
EaseInOutCubic = function(t) return t end
SCE_CTRL_SELECT, SCE_CTRL_START = 1024, 2048
MENU, READER, AppMode = 0, 1, 0
local now = 0
Timer.new = function() return { start = now } end
Timer.getTime = function(timer) return now - timer.start end
Timer.reset = function(timer) timer.start = now end
local chapterList, bookmarks, read, downloaded, following, sortChanges, menus
following, sortChanges, menus = false, 0, 0
Settings.ChapterSorting, Settings.LoadSummary = '1->N', false
Network = { isWifiEnabled = function() return false end }
Threads.netActionUnSafe = function() return false end
GetParserByID = function() return nil end
Database.check = function() return following end
Database.addManga = function() following = true end
Database.removeManga = function() following = false end
Cache = {
	isCached = function() return true end, BookmarksLoaded = function() return true end,
	loadChapters = function() return chapterList end,
	getBookmark = function(chapter) return bookmarks[chapter.Link] end,
	getLatestBookmark = function() return nil end,
	addManga = noop, makeHistory = noop
}
Notifications = { push = noop, pushUnique = noop }
Extra.doesBookmarksUpdate = function() return false end
Extra.setChapters = function() menus = menus + 1 end
Reader = { load = function(_, item) read = item end }
Catalogs.shrink = noop
ChapterSaver.check = function(chapter) return chapter.Link == 'chapter3' end
ChapterSaver.is_downloading = function(chapter)
	if chapter.Link == 'chapter2' then return { page = 1, page_count = 2 } end
end
ChapterSaver.stop = function(chapter) downloaded = chapter.Link end
ChapterSaver.delete = function(chapter) downloaded = chapter.Link end
DrawDetailsManga = noop
SettingsFunctions = { ChapterSorting = function()
	sortChanges = sortChanges + 1
	Settings.ChapterSorting = Settings.ChapterSorting == '1->N' and 'N->1' or '1->N'
end }
Settings.save = noop
local labels, focus = {}, nil
Font.print = function(_, _, _, text) labels[tostring(text)] = true end
Graphics.fillEmptyRect = function() error('details focus must use rounded borders') end
local originalFocus = UI.focusBorder
UI.focusBorder = function(...)
	focus = { ... }
	return originalFocus(...)
end
dofile('source/assets/libs/details.lua')
local manga = { Name = 'Test manga', RawLink = 'https://example.invalid/manga', ParserID = 'TEST' }
local function open(summary)
	AppMode = MENU
	chapterList, bookmarks = {}, { chapter1 = 5, chapter3 = true }
	for i = 1, 8 do chapterList[i] = { Name = 'Chapter ' .. i, Link = 'chapter' .. i, Manga = manga } end
	chapterList.Description = summary
	Details.setManga(manga)
	now = now + 300
	Details.update()
	Details.update()
	Details.draw()
end
local function tap(x, y)
	local touch = { x = x, y = y }
	Details.input(0, 0, {}, touch)
	Details.input(0, 0, touch, touch)
	Details.input(0, 0, touch, {})
end
open()
assert(labels['Test manga'] and labels['Chapter 1'] and labels['50%'], 'details must show title, chapters and download progress')
Details.input(0, SCE_CTRL_DOWN, {}, {})
Details.draw()
assert(focus and focus[1] == 278 and focus[5] == 10, 'chapter selector must use the shared rounded glow')
tap(300, 100)
assert(read == 1, 'top of first chapter card must open chapter one')
open()
tap(900, 180)
assert(downloaded == 'chapter2', 'chapter action area must stop its download')
tap(100, 445)
assert(following, 'library action must add the manga')
tap(100, 445)
assert(not following, 'library action must remove the manga')
tap(100, 510)
assert(read == 1, 'start button must open the first chapter')
open()
Details.input(0, SCE_CTRL_RTRIGGER, {}, {})
assert(sortChanges == 1, 'sorting control must remain functional')
tap(300, 100)
assert(read == 8, 'reverse sorting must map the first visible card to the last chapter')
open()
Details.input(0, SCE_CTRL_START, {}, {})
assert(menus == 1, 'chapter options must remain accessible')
Settings.LoadSummary = true
open(('Summary description words. '):rep(12))
for _ = 1, 20 do Details.update() end
labels = {}
Details.draw()
assert(labels[Language.English.DETAILS.EXPAND], 'long summary must keep its expand action')
Details.input(0, SCE_CTRL_LTRIGGER, {}, {})
for _ = 1, 20 do Details.update() end
labels = {}
Details.draw()
assert(labels[Language.English.DETAILS.SHRINK], 'summary must expand and offer collapse')
Details.input(0, SCE_CTRL_CIRCLE, {}, {})
now = now + 300
Details.update()
Details.update()
assert(Details.getStatus() == 'END', 'back must finish the exit animation')
print('Details checks passed: chapter UI, reading, download actions, library toggle, start, reverse sorting, options and back.')
