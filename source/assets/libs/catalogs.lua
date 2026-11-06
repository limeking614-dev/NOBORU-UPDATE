Catalogs = {}
Panels = {}

local slider = CreateSlider()
local TOUCH_MODES = TOUCH_MODES

local doesFileExist = System.doesFileExist
local doesDirExist = System.doesDirExist
local listDirectory = System.listDirectory
local abs = math.abs
local ceil = math.ceil
local floor = math.floor
local max = math.max
local min = math.min
local copyFile = CopyFile
local openFile = System.openFile
local closeFile = System.closeFile
local writeFile = System.writeFile
local deleteFile = System.deleteFile

local currentParser = nil
local touchTimer = Timer.new()

local status = "CATALOGS"
local function isGrid()
	return status == "MANGA" or status == "LIBRARY" or status == "HISTORY"
end

local function gridTop()
	return isGrid() and 64 or 6
end

local function gridY(index)
	local layout = Grid.layout()
	return floor((index - 1) / layout.columns) * layout.stride - slider.Y + gridTop()
end

local keyboardMode = "NONE"
local downloadBarValue = 0

local downloadedImages = {}
local page = 1
local currentMangaList = {}
local function gridLimit()
	local layout = Grid.layout()
	return max(0, ceil(#currentMangaList / layout.columns) * layout.stride + gridTop() - layout.gap - 524)
end
local parsersList = {}

local chaptersFolderSize
local cacheFolderSize
local sure_clear_library
local sure_clear_chapters
local sure_clear_all_cache
local sure_clear_cache
local manga_load_status = 0

local smilesList = {"ಥ_ಥ", "ಠ_ಠ", "ヽ(`Д´)ﾉ", "ఠ౬ఠ", "°Д°", "(ó﹏ò｡)", "(╥﹏╥)", "(⊙_⊙)", "(✖╭╮✖)", "ʘ‿ʘ", "(￣ω￣)", "(´• ω •`) ♡", "(⌒_⌒;)", "( ╥ω╥ )", "(✧∀✧)/", "	╰( ͡° ͜ʖ ͡° )つ──☆*:・ﾟ"}
local smile = nil

local mangaSelector =
	Selector:new(
	-4,
	4,
	-1,
	1,
	function()
		return Grid.first(slider.Y)
	end
)

local lastGridLayout = Grid.layout()
local function syncGridLayout()
	local layout = Grid.layout()
	if layout ~= lastGridLayout then
		slider.Y, slider.V = 0, 0
		mangaSelector:resetSelected()
		TOUCH_MODES.MODE = TOUCH_MODES.NONE
		lastGridLayout = layout
	end
	mangaSelector:setSteps(-layout.columns, layout.columns, -1, 1)
end

local parserSelector =
	Selector:new(
	-1,
	1,
	-3,
	3,
	function()
		return max(1, floor((slider.Y - 10) / 75))
	end
)

local downloadSelector =
	Selector:new(
	-1,
	1,
	-3,
	3,
	function()
		return max(1, floor((slider.Y - 10) / 75))
	end
)

local settingSelector =
	Selector:new(
	-1,
	1,
	-3,
	3,
	function()
		return max(1, floor((slider.Y - 10) / 75))
	end
)

local importSelector =
	Selector:new(
	-1,
	1,
	-3,
	3,
	function()
		return max(1, floor((slider.Y - 10) / 75))
	end
)

local pcSelector =
	Selector:new(
	-1,
	1,
	-3,
	3,
	function()
		return max(1, floor((slider.Y - 10) / 75))
	end
)

---------------------------------------------------------------- PC SOURCES (sites added on the PC, saved on the Vita)
local PCS_FILE = "ux0:data/noboru/pcsources.lua"
local PCS_CFG = "ux0:data/noboru/vitaserver.lua"
local pcSources = {}
local pcSync = nil
local pcSyncMessage = nil
local pcDeleteArm = nil
local pcDeleteTimer = Timer.new()
local fromPcSources = false
local sure_delete_sources = 0

local function pcBase()
	if doesFileExist(PCS_CFG) then
		local ok, t = pcall(dofile, PCS_CFG)
		if ok and type(t) == "table" and type(t.url) == "string" and t.url:match("^http://") then
			return (t.url:gsub("/+$", ""))
		end
	end
	return nil
end

local function pcEnc(str)
	return (tostring(str):gsub("[^%w%-_%.~]", function(c)
		return string.format("%%%02X", c:byte())
	end))
end

local function savePcSources()
	local out = {}
	for i = 1, #pcSources do
		out[#out + 1] = string.format("{Site=%q,Count=%d,Manual=%s}", pcSources[i].Site, pcSources[i].Count or 0, pcSources[i].Manual and "true" or "false")
	end
	local str = "return {" .. table.concat(out, ",") .. "}"
	-- never let a save problem crash the app
	pcall(function()
		if doesFileExist(PCS_FILE) then
			deleteFile(PCS_FILE)
		end
		local fh = openFile(PCS_FILE, FCREATE)
		writeFile(fh, str, #str)
		closeFile(fh)
	end)
	if RefreshCustomSites then
		RefreshCustomSites()
	end
end

local function loadPcSources()
	pcSources = {}
	if doesFileExist(PCS_FILE) then
		local ok, t = pcall(dofile, PCS_FILE)
		if ok and type(t) == "table" then
			for i = 1, #t do
				if type(t[i]) == "table" and type(t[i].Site) == "string" then
					pcSources[#pcSources + 1] = {Site = t[i].Site, Name = t[i].Site, Count = tonumber(t[i].Count) or 0, Manual = t[i].Manual == true}
				end
			end
		end
	end
end

---Sites typed in with the circle button (Manual) get their own entry in the CATALOGS list;
---sites that only came from the PC stay hidden there (they are still in PC SOURCES).
function RefreshCustomSites()
	local manual = {}
	for i = 1, #pcSources do
		if pcSources[i].Manual then
			manual[pcSources[i].Site] = true
		end
	end
	if PCSiteParser then
		for host in pairs(manual) do
			PCSiteParser(host)
		end
	end
	for host, P in pairs(PCSITE_CREATED or {}) do
		P.Hidden = not manual[host]
		if manual[host] then
			P.Custom = true
			P.isNew = nil
			P.isUpdated = nil
			P.isChanged = 0
		end
	end
	ChangeNSFW()
end

---Called once the bundled sources are loaded (and after every Refresh)
function SyncCustomSites()
	loadPcSources()
	RefreshCustomSites()
end

---Asks the PC which sites were added and saves them on the Vita
local function startPcSync()
	if pcSync then
		return
	end
	local base = pcBase()
	if not base then
		loadPcSources()
		pcSyncMessage = #pcSources == 0 and "PC server address not set\n(open the PC Server catalog and press Search first)" or nil
		return
	end
	pcSyncMessage = nil
	pcSync = {}
	Threads.insertTask(pcSync, {
		Type = "StringRequest",
		Link = base .. "/api/sources",
		Table = pcSync,
		Index = "text",
		Header1 = "X-Vita-Reader: 1"
	})
end

local function finishPcSync()
	local text = pcSync.text or ""
	pcSync = nil
	if text == "" then
		-- PC program not running: keep showing the sources saved on the Vita (they load without the PC)
		loadPcSources()
		pcSyncMessage = #pcSources == 0 and "PC server not running\n(start NOBORU-PC-Server on your PC, same Wi-Fi)" or nil
		return
	end
	pcSyncMessage = nil
	local seen = {}
	for line in text:gmatch("[^\r\n]+") do
		local host, _, count = line:match("^([^\t]*)\t([^\t]*)\t?([^\t]*)")
		if host and host ~= "" and host:sub(1, 1) ~= "#" then   -- "#ok" is just the "PC is reachable" marker
			seen[host] = true
			local found
			for i = 1, #pcSources do
				if pcSources[i].Site == host then
					found = pcSources[i]
				end
			end
			if not found then
				found = {Site = host, Name = host}
				pcSources[#pcSources + 1] = found
			end
			found.Count = tonumber(count) or 0
		end
	end
	-- the PC answered: sources it no longer has must disappear here too
	-- (they used to stay forever with Count = 0, which is why an old source kept showing up)
	for i = #pcSources, 1, -1 do
		if not seen[pcSources[i].Site] and not pcSources[i].Manual then
			table.remove(pcSources, i)
		end
	end
	savePcSources()
end

---Square on a source: press twice to delete the site from the PC and from the saved list
local function pcDelete(index)
	local src = pcSources[index]
	if not src then
		return
	end
	if pcDeleteArm == src.Site and Timer.getTime(pcDeleteTimer) < 3000 then
		pcDeleteArm = nil
		local base = pcBase()
		if base and (src.Count or 0) > 0 then
			local t = {}
			Threads.insertTask(t, {
				Type = "StringRequest",
				Link = base .. "/api/delete?site=1&q=" .. pcEnc(src.Site),
				Table = t,
				Index = "text",
				Header1 = "X-Vita-Reader: 1"
			})
		end
		table.remove(pcSources, index)
		savePcSources()
		Notifications.push("Deleted " .. src.Site)
	else
		pcDeleteArm = src.Site
		Timer.reset(pcDeleteTimer)
		Notifications.push("Press Square again to delete " .. src.Site .. (src.Manual and "" or " (PC + saved)"))
	end
end

---Settings > Data > "Delete added sources"
---Wipes everything the PC Server source added: the list on the PC, the saved source list on the Vita
---(ux0:data/noboru/pcsources.lua), and the cache / history / library entries and downloaded chapters of PC Server manga.
---The server address (ux0:data/noboru/vitaserver.lua) is kept so the source keeps working.
local function pcDeleteAllSources()
	local base = pcBase()
	if base then
		local t = {}
		Threads.insertTask(t, {
			Type = "StringRequest",
			Link = base .. "/api/delete?q=all",
			Table = t,
			Index = "text",
			Header1 = "X-Vita-Reader: 1"
		})
	end
	pcSources = {}
	pcSync = nil
	pcSyncMessage = nil
	pcDeleteArm = nil
	fromPcSources = false
	VitaServerSite = nil
	savePcSources()
	local removed = 0
	-- downloaded chapters (ux0:data/noboru/chapters/VITASERVER...)
	pcall(function()
		local list = ChapterSaver.getDownloadingList()
		for i = #list, 1, -1 do
			local it = list[i]
			if it and it.Saved and type(it.Key) == "string" and it.Key:find("^VITASERVER") then
				ChapterSaver.deleteSaved(it)
				removed = removed + 1
			end
		end
	end)
	-- cache folders (ux0:data/noboru/cache/VITASERVER...), history and library
	pcall(function()
		for key, manga in pairs(Cache.getManga()) do
			if type(manga) == "table" and manga.ParserID == "VITASERVER" then
				if Database.check(manga) then
					Database.removeManga(manga)
				end
				Cache.removeHistory(manga)
				Cache.removeManga(manga)
				removed = removed + 1
			end
		end
	end)
	cacheFolderSize = nil
	chaptersFolderSize = nil
	Notifications.push("Added sources deleted (" .. removed .. " saved items removed)")
end

local function freeMangaImage(manga)
	if manga and manga.ImageDownload then
		Threads.remove(manga)
		if manga.Image and manga.Image.free then
			manga.Image:free()
		end
		manga.ImageDownload = nil
	end
end

local function loadMangaImage(manga)
	if CustomCovers.hasCustomCover(manga) then
		local customCoverPath = "ux0:data/noboru/cache/" .. Cache.getKey(manga) .. "/custom_cover.image"
		if doesFileExist(customCoverPath) and System.getPictureResolution(customCoverPath) or -1 > 0 then
			Threads.addTask(
				manga,
				{
					Type = "Image",
					Path = customCoverPath,
					Table = manga,
					MaxHeight = MANGA_HEIGHT * 2,
					Index = "newImage",
					OnFinalComplete = function()
						if manga.Image ~= nil and type(manga.Image) == "table" and manga.Image.Type == "image" then
							manga.Image:free()
						end
						manga.Image = manga.newImage
					end
				}
			)
		else
			if not Cache.isCached(manga) then
				Cache.addManga(manga)
			end
			local cover = CustomCovers.getCustomCover(manga)
			local cacheKey = Cache.getKey(manga)
			local t = {}
			if cover.Path then
				copyFile(cover.Path:find("^...?0:") and cover.Path or ("ux0:data/noboru/" .. cover.Path), "ux0:data/noboru/cache/" .. cacheKey .. "/custom_cover.image")
				Threads.addTask(
					manga,
					{
						Type = "Image",
						Path = customCoverPath,
						Table = manga,
						MaxHeight = MANGA_HEIGHT * 2,
						Index = "newImage",
						OnFinalComplete = function()
							if manga.Image ~= nil and type(manga.Image) == "table" and manga.Image.Type == "image" then
								manga.Image:free()
							end
							manga.Image = manga.newImage
						end
					}
				)
			elseif cover.ParserID then
				Threads.insertTask(
					manga,
					{
						Type = "function",
						OnComplete = function()
							ParserManager.getPageImage(cover.ParserID, cover.Link, t)
							while ParserManager.check(t) do
								coroutine.yield(false)
							end
							Threads.insertTask(
								manga,
								{
									Type = "FileDownload",
									Link = t.Link,
									Path = "ux0:data/noboru/cache/" .. cacheKey .. "/custom_cover.image",
									OnComplete = function()
										Threads.addTask(
											manga,
											{
												Type = "Image",
												Path = customCoverPath,
												Table = manga,
												MaxHeight = MANGA_HEIGHT * 2,
												Index = "newImage",
												OnFinalComplete = function()
													if manga.Image ~= nil and type(manga.Image) == "table" and manga.Image.Type == "image" then
														manga.Image:free()
													end
													manga.Image = manga.newImage
												end
											}
										)
									end
								}
							)
						end
					}
				)
			elseif cover.Link then
				Threads.insertTask(
					manga,
					{
						Type = "FileDownload",
						Link = cover.Link,
						Path = "ux0:data/noboru/cache/" .. cacheKey .. "/custom_cover.image",
						OnComplete = function()
							Threads.addTask(
								manga,
								{
									Type = "Image",
									Path = customCoverPath,
									Table = manga,
									MaxHeight = MANGA_HEIGHT * 2,
									Index = "newImage",
									OnFinalComplete = function()
										if manga.Image ~= nil and type(manga.Image) == "table" and manga.Image.Type == "image" then
											manga.Image:free()
										end
										manga.Image = manga.newImage
									end
								}
							)
						end
					}
				)
			else
				CustomCovers.setMangaCover(manga, nil)
			end
		end
	else
		local path = manga.Path or ("cache/" .. Cache.getKey(manga) .. "/cover.image")
		if path and doesFileExist("ux0:data/noboru/" .. path) and System.getPictureResolution("ux0:data/noboru/" .. path) or -1 > 0 then
			Threads.addTask(
				manga,
				{
					Type = "Image",
					Path = path,
					Table = manga,
					MaxHeight = MANGA_HEIGHT * 2,
					Index = "newImage",
					OnFinalComplete = function()
						if manga.Image ~= nil and type(manga.Image) == "table" and manga.Image.Type == "image" then
							manga.Image:free()
						end
						manga.Image = manga.newImage
					end
				}
			)
		else
			if Database.check(manga) and not Cache.isCached(manga) then
				Cache.addManga(manga)
			end
			Threads.addTask(
				manga,
				{
					Type = "ImageDownload",
					Link = manga.ImageLink,
					Table = manga,
					Index = "newImage",
					OnFinalComplete = function()
						if manga.Image ~= nil and type(manga.Image) == "table" and manga.Image.Type == "image" then
							manga.Image:free()
						end
						manga.Image = manga.newImage
					end,
					MaxHeight = MANGA_HEIGHT * 2,
					Path = Cache.isCached(manga) and path or nil
				}
			)
		end
	end
end

local function UpdateMangas()
	if slider.V == 0 and Timer.getTime(touchTimer) > 200 then
		local start = Grid.first(slider.Y)
		local capacity = Grid.capacity()
		if #downloadedImages > capacity then
			local newTable = {}
			for _, i in ipairs(downloadedImages) do
				if i < start or i > min(#currentMangaList, start + capacity - 1) then
					freeMangaImage(currentMangaList[i])
				else
					newTable[#newTable + 1] = i
				end
			end
			downloadedImages = newTable
		end
		for i = start, min(#currentMangaList, start + capacity - 1) do
			local manga = currentMangaList[i]
			if not manga.ImageDownload then
				loadMangaImage(manga)
				manga.ImageDownload = true
				downloadedImages[#downloadedImages + 1] = i
			end
		end
	else
		local newTable = {}
		for _, i in ipairs(downloadedImages) do
			local manga = currentMangaList[i]
			if Threads.check(manga) and (Details.getFade() == 0 or manga ~= Details.getManga()) then
				Threads.remove(manga)
				manga.ImageDownload = nil
			else
				newTable[#newTable + 1] = i
			end
		end
		downloadedImages = newTable
	end
end

local function selectManga(index)
	local manga = currentMangaList[index]
	if manga then
		Details.setManga(manga)
	end
end

---Opens a site's catalog. A built-in source for the same site is used when there is one.
local function openSite(host, fromPc)
	local parser = GetParserForHost(host)
	if not parser and PCSiteParser then
		parser = PCSiteParser(host)
	end
	if parser then
		local function load()
			VitaServerSite = nil
			fromPcSources = fromPc
			currentParser = parser
			Catalogs.setStatus("MANGA")
			CatalogModes.load(parser)
			if fromPc then
				CatalogModes.selectMode("Latest", host)
			end
		end
		-- "Checking Cloudflare" screen first; the source loads when it is closed with Circle
		if CFCheck and CFCheck.begin then
			CFCheck.begin(parser, load)
		else
			load()
		end
	end
end

local function selectPcSource(index)
	local src = pcSources[index]
	if not src then
		return
	end
	-- the PC only told us which site this is: load its mangas straight from the site
	-- (built-in parser for that site if there is one, else a per-site parser) - no PC needed
	openSite(src.Site, true)
end

local function selectParser(index)
	local newParser = GetParserList()[index]
	if newParser then
		local function load()
			fromPcSources = false
			VitaServerSite = nil
			currentParser = newParser
			Catalogs.setStatus("MANGA")
			CatalogModes.load(newParser)
		end
		-- "Checking Cloudflare" screen first; the source loads when it is closed with Circle
		if CFCheck and CFCheck.begin then
			CFCheck.begin(newParser, load)
		else
			load()
		end
	end
end

local function selectSetting(index)
	local item = Settings.list()[index]
	if item and Settings.isTab(item) then
		if Settings.getTab() ~= "AdvancedChaptersDeletion" then
			settingSelector:resetSelected()
			slider.Y = -100
		end
		Settings.setTab(item)
	elseif item then
		if SettingsFunctions[item] then
			if item == "ClearChapters" then
				sure_clear_chapters = sure_clear_chapters + 1
				if sure_clear_chapters == 2 then
					SettingsFunctions[item]()
					chaptersFolderSize = nil
					sure_clear_chapters = 0
				end
			elseif item == "DeleteAddedSources" then
				sure_delete_sources = sure_delete_sources + 1
				if sure_delete_sources == 2 then
					pcDeleteAllSources()
					sure_delete_sources = 0
				end
			elseif item == "ClearLibrary" then
				sure_clear_library = sure_clear_library + 1
				if sure_clear_library == 2 then
					SettingsFunctions[item]()
					sure_clear_library = 0
				end
			elseif item == "ClearAllCache" then
				sure_clear_all_cache = sure_clear_all_cache + 1
				if sure_clear_all_cache == 2 then
					cacheFolderSize = nil
					SettingsFunctions[item]()
					sure_clear_all_cache = 0
				end
			elseif item == "ClearCache" then
				sure_clear_cache = sure_clear_cache + 1
				if sure_clear_cache == 2 then
					cacheFolderSize = nil
					SettingsFunctions[item]()
					sure_clear_cache = 0
				end
			else
				SettingsFunctions[item]()
				Settings.save()
			end
		end
		if item ~= "ClearChapters" then
			sure_clear_chapters = 0
		end
		if item ~= "ClearCache" then
			sure_clear_cache = 0
		end
		if item ~= "ClearAllCache" then
			sure_clear_all_cache = 0
		end
		if item ~= "ClearLibrary" then
			sure_clear_library = 0
		end
		if item ~= "DeleteAddedSources" then
			sure_delete_sources = 0
		end
	end
end

local function selectImport(index)
	local list = Import.listDir()
	if index > 0 and index <= #list then
		Import.go(list[index])
	end
end

mangaSelector:xaction(selectManga)
parserSelector:xaction(selectParser)
local function downloadAction(index)
	local item = ChapterSaver.getDownloadingList()[index]
	if not item then
		return
	end
	if item.Saved then
		ChapterSaver.openSaved(item)
	else
		ChapterSaver.stopByListItem(item)
	end
end
downloadSelector:xaction(downloadAction)
pcSelector:xaction(selectPcSource)
settingSelector:xaction(selectSetting)
importSelector:xaction(selectImport)
function Catalogs.input(oldpad, pad, oldtouch, touch)
	if isGrid() then syncGridLayout() end
	if status == "MANGA" then
		if Controls.check(pad, SCE_CTRL_CIRCLE) and not Controls.check(oldpad, SCE_CTRL_CIRCLE) then
			if fromPcSources then
				Catalogs.setStatus("PCSOURCES")
			else
				status = "CATALOGS"
				Catalogs.terminate()
			end
		elseif Controls.check(pad, SCE_CTRL_SQUARE) and not Controls.check(oldpad, SCE_CTRL_SQUARE) then
			CatalogModes.show()
		elseif Controls.check(pad, SCE_CTRL_TRIANGLE) and not Controls.check(oldpad, SCE_CTRL_TRIANGLE) then
			Keyboard.show(Language[Settings.Language].SETTINGS.InputValue, 1, 128, TYPE_NUMBER, MODE_TEXT, OPT_NO_AUTOCAP)
			keyboardMode = "JUMP_PAGE"
		end
	elseif status == "CATALOGS" then
		if Controls.check(pad, SCE_CTRL_TRIANGLE) and not Controls.check(oldpad, SCE_CTRL_TRIANGLE) then
			ParserManager.updateParserList(parsersList)
		end
		if Controls.check(pad, SCE_CTRL_CIRCLE) and not Controls.check(oldpad, SCE_CTRL_CIRCLE) and Keyboard.getState() ~= RUNNING then
			Keyboard.show("Site address (example: manhuaus.com)", "", 128, TYPE_DEFAULT, MODE_TEXT, OPT_NO_AUTOCAP)
			keyboardMode = "ADD_SITE"
		end
		if Controls.check(pad, SCE_CTRL_SQUARE) and not Controls.check(oldpad, SCE_CTRL_SQUARE) then
			local item = parsersList[parserSelector:getSelected()]
			if item and item.Custom then
				-- a site you added: press twice to remove it from the catalog
				for i = 1, #pcSources do
					if pcSources[i].Site == item.Host then
						pcDelete(i)
						break
					end
				end
			elseif item then
				Settings.toggleFavouriteParser(item)
			end
		end
		if Controls.check(pad, SCE_CTRL_SELECT) and not Controls.check(oldpad, SCE_CTRL_SELECT) and Debug.getStatus() == 2 then
			local item = parsersList[parserSelector:getSelected()]
			if item then
				ParserChecker.addCheck(item)
			end
		end
	elseif status == "PCSOURCES" then
		if Controls.check(pad, SCE_CTRL_TRIANGLE) and not Controls.check(oldpad, SCE_CTRL_TRIANGLE) then
			startPcSync()
		end
		if Controls.check(pad, SCE_CTRL_CIRCLE) and not Controls.check(oldpad, SCE_CTRL_CIRCLE) and Keyboard.getState() ~= RUNNING then
			Keyboard.show("Site address (example: manhuaus.com)", "", 128, TYPE_DEFAULT, MODE_TEXT, OPT_NO_AUTOCAP)
			keyboardMode = "ADD_SITE"
		end
		if Controls.check(pad, SCE_CTRL_SQUARE) and not Controls.check(oldpad, SCE_CTRL_SQUARE) then
			pcDelete(pcSelector:getSelected())
		end
	elseif status == "DOWNLOAD" then
		if Controls.check(pad, SCE_CTRL_SQUARE) and not Controls.check(oldpad, SCE_CTRL_SQUARE) then
			local item = ChapterSaver.getDownloadingList()[downloadSelector:getSelected()]
			if item and item.Saved then
				ChapterSaver.deleteSaved(item)
			end
		end
	elseif status == "HISTORY" then
		if Controls.check(pad, SCE_CTRL_SQUARE) and not Controls.check(oldpad, SCE_CTRL_SQUARE) then
			local item = currentMangaList[mangaSelector:getSelected()]
			if item then
				Cache.removeHistory(item)
			end
		end
	elseif status == "SETTINGS" then
		if Controls.check(pad, SCE_CTRL_CIRCLE) and not Controls.check(oldpad, SCE_CTRL_CIRCLE) then
			Settings.back()
			settingSelector:resetSelected()
		end
		if Controls.check(pad, SCE_CTRL_SQUARE) and not Controls.check(oldpad, SCE_CTRL_SQUARE) and Settings.getTab() == "AdvancedChaptersDeletion" then
			local id = settingSelector:getSelected()
			local item = Settings.list()[id]
			if item then
				Settings.delTab(item)
			end
		end
	elseif status == "IMPORT" then
		if Controls.check(pad, SCE_CTRL_CIRCLE) and not Controls.check(oldpad, SCE_CTRL_CIRCLE) then
			Import.back()
			importSelector:resetSelected()
		end
		if Controls.check(pad, SCE_CTRL_SQUARE) and not Controls.check(oldpad, SCE_CTRL_SQUARE) then
			local item = Import.listDir()[importSelector:getSelected()]
			if item and item.active and item.name ~= "..." then
				ChapterSaver.importManga(Import.getPath(item))
				importSelector:resetSelected()
			end
		end
	elseif status == "LIBRARY" then
		if Controls.check(pad, SCE_CTRL_TRIANGLE) and not Controls.check(oldpad, SCE_CTRL_TRIANGLE) then
			ParserManager.updateCounters()
		end
	end
	if slider.V ~= 0 or Controls.check(pad, SCE_CTRL_RTRIGGER) or Controls.check(pad, SCE_CTRL_LTRIGGER) or touch.x then
		Timer.reset(touchTimer)
	end
	if status == "MANGA" or status == "LIBRARY" or status == "HISTORY" then
		mangaSelector:input(#currentMangaList, oldpad, pad, touch.x)
	elseif status == "CATALOGS" then
		parserSelector:input(#parsersList, oldpad, pad, touch.x)
	elseif status == "PCSOURCES" then
		pcSelector:input(#pcSources, oldpad, pad, touch.x)
	elseif status == "DOWNLOAD" then
		downloadSelector:input(#ChapterSaver.getDownloadingList(), oldpad, pad, touch.x)
	elseif status == "SETTINGS" then
		settingSelector:input(#Settings.list(), oldpad, pad, touch.x)
	elseif status == "IMPORT" then
		importSelector:input(#Import.listDir(), oldpad, pad, touch.x)
	end
	if TOUCH_MODES.MODE == TOUCH_MODES.NONE and oldtouch.x and touch.x and touch.x > 205 and touch.y >= gridTop() and touch.y < 524 then
		TOUCH_MODES.MODE = TOUCH_MODES.READ
		slider.TouchY = touch.y
	elseif TOUCH_MODES.MODE ~= TOUCH_MODES.NONE and not touch.x then
		if oldtouch.x then
			if TOUCH_MODES.MODE == TOUCH_MODES.READ then
				if status == "MANGA" or status == "LIBRARY" or status == "HISTORY" then
					local layout = Grid.layout()
					local start = Grid.first(slider.Y)
					for i = start, min(#currentMangaList, start + Grid.capacity() - 1) do
						local lx = Grid.x(i)
						local uy = gridY(i)
						if oldtouch.x > lx and oldtouch.x < lx + layout.width and oldtouch.y >= gridTop() and oldtouch.y < 524 and oldtouch.y > uy and oldtouch.y < uy + layout.itemHeight then
							selectManga(i)
							break
						end
					end
				elseif oldtouch.x > 205 and oldtouch.x < 955 then
					local id = floor((slider.Y - 10 + oldtouch.y) / 75) + 1
					if status == "CATALOGS" then
						selectParser(id)
					elseif status == "PCSOURCES" then
						if pcSources[id] then
							selectPcSource(id)
						end
					elseif status == "DOWNLOAD" then
						downloadAction(id)
					elseif status == "SETTINGS" then
						local list = Settings.list()
						if list[id] then
							selectSetting(id)
						end
					elseif status == "IMPORT" then
						if oldtouch.x < 850 then
							local list = Import.listDir()
							if list[id] then
								selectImport(id)
							end
						else
							local item = Import.listDir()[id]
							if item and item.active and item.name ~= "..." then
								ChapterSaver.importManga(Import.getPath(item))
								importSelector:resetSelected()
							end
						end
					end
				end
			end
		end
		TOUCH_MODES.MODE = TOUCH_MODES.NONE
	end
	local newItemID = 0
	if TOUCH_MODES.MODE == TOUCH_MODES.READ then
		if abs(slider.V) > 0.1 or abs(slider.TouchY - touch.y) > 10 then
			TOUCH_MODES.MODE = TOUCH_MODES.SLIDE
		elseif oldtouch.x > 205 and oldtouch.x < 945 then
			local id = floor((slider.Y - 10 + oldtouch.y) / 75) + 1
			if status == "CATALOGS" and GetParserList()[id] then
				newItemID = id
			elseif status == "PCSOURCES" and pcSources[id] then
				newItemID = id
			elseif status == "DOWNLOAD" and ChapterSaver.getDownloadingList()[id] then
				newItemID = id
			elseif status == "SETTINGS" and Settings.list()[id] then
				newItemID = id
			elseif status == "IMPORT" and Import.listDir()[id] then
				newItemID = id
			end
		end
	end
	if slider.ItemID > 0 and newItemID > 0 and slider.ItemID ~= newItemID then
		TOUCH_MODES.MODE = TOUCH_MODES.SLIDE
	else
		slider.ItemID = newItemID
	end
	if TOUCH_MODES.MODE == TOUCH_MODES.SLIDE and oldtouch.x and touch.x and touch.x > 205 then
		slider.V = oldtouch.y - touch.y
		if isGrid() then
			slider.V = slider.V * (1000 / 60) / UI.dt
		end
	end
end

function GenPanels()
	Panels["MANGA"] = {
		"L\\R",
		"Square",
		"DPad",
		"Cross",
		"Circle",
		"Triangle",
		["L\\R"] = Language[Settings.Language].PANEL.CHANGE_SECTION,
		Square = Language[Settings.Language].PANEL.MODE,
		Triangle = Language[Settings.Language].PANEL.JUMPTOPAGE,
		Circle = Language[Settings.Language].PANEL.BACK,
		DPad = Language[Settings.Language].PANEL.CHOOSE,
		Cross = Language[Settings.Language].PANEL.SELECT
	}
	Panels["IMPORT"] = {
		"L\\R",
		"DPad",
		"Circle",
		"Cross",
		"Square",
		["L\\R"] = Language[Settings.Language].PANEL.CHANGE_SECTION,
		DPad = Language[Settings.Language].PANEL.CHOOSE,
		Cross = Language[Settings.Language].PANEL.SELECT
	}
	Panels["HISTORY"] = {
		"L\\R",
		"DPad",
		"Cross",
		"Square",
		["L\\R"] = Language[Settings.Language].PANEL.CHANGE_SECTION,
		DPad = Language[Settings.Language].PANEL.CHOOSE,
		Cross = Language[Settings.Language].PANEL.SELECT,
		Square = Language[Settings.Language].PANEL.DELETE
	}
	Panels["PCSOURCES"] = {
		"L\\R",
		"DPad",
		"Cross",
		"Circle",
		"Square",
		"Triangle",
		Circle = "Add site",
		["L\\R"] = Language[Settings.Language].PANEL.CHANGE_SECTION,
		DPad = Language[Settings.Language].PANEL.CHOOSE,
		Cross = Language[Settings.Language].PANEL.SELECT,
		Triangle = Language[Settings.Language].PANEL.UPDATE
	}
	Panels["LIBRARY"] = {
		"L\\R",
		"DPad",
		"Triangle",
		"Cross",
		["L\\R"] = Language[Settings.Language].PANEL.CHANGE_SECTION,
		DPad = Language[Settings.Language].PANEL.CHOOSE,
		Cross = Language[Settings.Language].PANEL.SELECT,
		Triangle = Language[Settings.Language].PANEL.UPDATE
	}
	Panels["CATALOGS"] = {
		"L\\R",
		"DPad",
		"Square",
		"Cross",
		"Circle",
		"Triangle",
		Circle = "Add site",
		["L\\R"] = Language[Settings.Language].PANEL.CHANGE_SECTION,
		Triangle = Language[Settings.Language].PANEL.UPDATE,
		DPad = Language[Settings.Language].PANEL.CHOOSE,
		Cross = Language[Settings.Language].PANEL.SELECT
	}
	Panels["DOWNLOAD"] = {
		"L\\R",
		"DPad",
		"Cross",
		"Square",
		["L\\R"] = Language[Settings.Language].PANEL.CHANGE_SECTION,
		DPad = Language[Settings.Language].PANEL.CHOOSE,
		Cross = Language[Settings.Language].PANEL.CANCEL
	}
	Panels["SETTINGS"] = {
		"L\\R",
		"DPad",
		"Circle",
		"Cross",
		"Square",
		["L\\R"] = Language[Settings.Language].PANEL.CHANGE_SECTION,
		DPad = Language[Settings.Language].PANEL.CHOOSE,
		Cross = Language[Settings.Language].PANEL.SELECT
	}
end

function Catalogs.update()
	if isGrid() then syncGridLayout() end
	if pcSync and not Threads.check(pcSync) then
		finishPcSync()
	end
	if isGrid() then
		local frames = UI.dt / (1000 / 60)
		-- Integrate exponential drag so travel is independent of frame rate.
		local decay = math.pow(1 / 1.12, frames)
		slider.Y = slider.Y + slider.V * (1 - decay) / (1 - 1 / 1.12)
		slider.V = slider.V * decay
		if abs(slider.V) < 0.1 then slider.V = 0 end
	elseif abs(slider.V) < 1 then
		slider.V = 0
	else
		slider.Y = slider.Y + slider.V
		slider.V = slider.V / 1.12
	end
	if status == "MANGA" or status == "LIBRARY" or status == "HISTORY" then
		-- Opening a source (or changing its filters) must start page one even
		-- when the empty grid is already clamped to its zero scroll limit.
		if status == "MANGA" and page == 1 and currentParser and not ParserManager.check(currentMangaList) then
			ParserManager.getMangaListAsync(CatalogModes.getMangaMode(), currentParser, page, currentMangaList, CatalogModes.getSearchData(), CatalogModes.getTagsData())
			page = page + 1
			manga_load_status = 1
		end
		UpdateMangas()
		if ParserManager.check(currentMangaList) then
			manga_load_status = 1
			Loading.setStatus(COLOR_FONT == COLOR_BLACK and "BLACK" or "WHITE", 580, 272)
		elseif Details.getStatus() == "END" then
			Loading.setStatus("NONE")
		end
		local item = mangaSelector:getSelected()
		if item ~= 0 then
			local layout = Grid.layout()
			local target = floor((item - 1) / layout.columns) * layout.stride + layout.height / 2 - 232
			if isGrid() then
				slider.Y = UI.approach(slider.Y, min(gridLimit(), max(0, target + gridTop() / 2)), 90)
			else
				slider.Y = slider.Y + (target - slider.Y) / 8
			end
			if status == "MANGA" and not currentMangaList.NoPages and currentParser and item > #currentMangaList - layout.columns then
				if not ParserManager.check(currentMangaList) then
					ParserManager.getMangaListAsync(CatalogModes.getMangaMode(), currentParser, page, currentMangaList, CatalogModes.getSearchData(), CatalogModes.getTagsData())
					page = page + 1
				end
			end
		end
		if slider.Y < 0 then
			slider.Y = 0
			slider.V = 0
		elseif slider.Y > gridLimit() then
			slider.Y = gridLimit()
			slider.V = 0
			if status == "MANGA" then
				if not currentMangaList.NoPages and currentParser then
					if not ParserManager.check(currentMangaList) then
						ParserManager.getMangaListAsync(CatalogModes.getMangaMode(), currentParser, page, currentMangaList, CatalogModes.getSearchData(), CatalogModes.getTagsData())
						page = page + 1
					end
				end
			end
		end
		if status == "LIBRARY" and #currentMangaList ~= #Database.getMangaList() then
			currentMangaList = Database.getMangaList()
		elseif status == "HISTORY" then
			currentMangaList = Cache.getHistory()
		end
	else
		local list = {}
		local item = 0
		if status == "CATALOGS" then
			parsersList = GetParserList()
			list = parsersList
			item = parserSelector:getSelected()
			Panels["CATALOGS"].Square = parsersList[item] and (parsersList[item].Custom and Language[Settings.Language].PANEL.DELETE or (Settings.FavouriteParsers[parsersList[item].ID] and Language[Settings.Language].PANEL.UNFOLLOW or Language[Settings.Language].PANEL.FOLLOW))
		elseif status == "PCSOURCES" then
			list = pcSources
			item = pcSelector:getSelected()
			Panels["PCSOURCES"].Square = pcSources[item] and Language[Settings.Language].PANEL.DELETE or nil
			if pcSync then
				Loading.setStatus(COLOR_FONT == COLOR_BLACK and "BLACK" or "WHITE", 580, 272)
			elseif Details.getStatus() == "END" then
				Loading.setStatus("NONE")
			end
		elseif status == "DOWNLOAD" then
			list = ChapterSaver.getDownloadingList()
			item = downloadSelector:getSelected()
			local selectedTask = list[item]
			Panels["DOWNLOAD"].Cross = selectedTask and selectedTask.Saved and Language[Settings.Language].PANEL.READ or Language[Settings.Language].PANEL.CANCEL
			Panels["DOWNLOAD"].Square = selectedTask and selectedTask.Saved and Language[Settings.Language].PANEL.DELETE or nil
		elseif status == "SETTINGS" then
			list = Settings.list()
			Panels["SETTINGS"].Cirlce = Settings.inTab() and Language[Settings.Language].PANEL.BACK
			if Settings.getTab() == "AdvancedChaptersDeletion" then
				if #list > 0 then
					Panels["SETTINGS"].Cross = Language[Settings.Language].PANEL.READ
					Panels["SETTINGS"].Square = Language[Settings.Language].PANEL.DELETE
				else
					Panels["SETTINGS"].Cross = nil
					Panels["SETTINGS"].Square = nil
				end
			elseif Settings.getTab() == "DonatorsList" then
				Panels["SETTINGS"].Cross = nil
				Panels["SETTINGS"].Square = nil
			else
				Panels["SETTINGS"].Cross = Language[Settings.Language].PANEL.SELECT
				Panels["SETTINGS"].Square = nil
			end
			item = settingSelector:getSelected()
		elseif status == "IMPORT" then
			list = Import.listDir()
			item = importSelector:getSelected()
			Panels["IMPORT"].Square = list[item] and Import.canImport(list[item]) and Language[Settings.Language].PANEL.IMPORT
			Panels["IMPORT"].Circle = Import.canBack() and Language[Settings.Language].PANEL.BACK
		end
		if status == "SETTINGS" then
			if item ~= 0 then
				slider.Y = slider.Y + (item * 75 - 272 - slider.Y) / 8
			end
			local height = ceil(#list) * 75
			if Settings.getTab() == "About" then
				height = height + 140
			end
			if slider.Y < -10 then
				slider.Y = -10
				slider.V = 0
			elseif slider.Y > height - 514 then
				slider.Y = max(-10, height - 514)
				slider.V = 0
			end
		else
			if item ~= 0 then
				slider.Y = slider.Y + (item * 75 - 272 - slider.Y) / 8
			end
			if slider.Y < -10 then
				slider.Y = -10
				slider.V = 0
			elseif slider.Y > ceil(#list) * 75 - 514 then
				slider.Y = max(-10, ceil(#list) * 75 - 514)
				slider.V = 0
			end
		end
	end
	Panel.set(Panels[status] or {})
	if keyboardMode ~= "NONE" and Keyboard.getState() ~= RUNNING then
		if keyboardMode == "JUMP_PAGE" and Keyboard.getState() == FINISHED then
			local newPage = tonumber(Keyboard.getInput())
			if newPage and newPage > 0 then
				Catalogs.terminate()
				page = newPage
			end
		end
		if keyboardMode == "ADD_SITE" and Keyboard.getState() == FINISHED then
			local host = (Keyboard.getInput() or ""):lower():gsub("%s", ""):gsub("^[%a]+://", ""):gsub("^www%.", ""):gsub("[/?#].*$", "")
			if host:match("^[%w%-%.]+%.[%a][%w%-]*$") then
				local fromCatalogs = status == "CATALOGS"
				local builtin = fromCatalogs and GetParserForHost(host)
				keyboardMode = "NONE"
				Keyboard.clear()
				if builtin then
					-- MangaTown / AsuraScans are already in the list: just open them
					Notifications.push("Already in the catalog: " .. builtin.Name)
					openSite(host, false)
					return
				end
				local at
				for i = 1, #pcSources do
					if pcSources[i].Site == host then
						at = i
					end
				end
				if not at then
					table.insert(pcSources, 1, {Site = host, Name = host, Count = 0, Manual = true})
					at = 1
				else
					pcSources[at].Manual = true
				end
				savePcSources()
				if fromCatalogs then
					Notifications.push("Added " .. host)
					openSite(host, false)
				else
					selectPcSource(at)
				end
				return
			elseif host ~= "" then
				Notifications.push("Not a site address: " .. host)
			end
		end
		keyboardMode = "NONE"
		Keyboard.clear()
	end
end

function Catalogs.draw()
	local scrollHeight, item
	local itemHeight = 0
	local centerScreenMessage
	if status == "CATALOGS" then
		if #parsersList == 0 and not ParserManager.check("UpdateParsers") then
			centerScreenMessage = Language[Settings.Language].MESSAGE.NO_CATALOGS
		end
		local first = max(1, floor((slider.Y - 10) / 75))
		local y = first * 75 - slider.Y
		local last = min(#parsersList, first + 9)
		local selected = parserSelector:getSelected()
		for i = first, last do
			local parser = parsersList[i]
			UI.listCard(y - 70, y - 3, slider.ItemID == i or selected == i)
			local favourite = Settings.FavouriteParsers[parser.ID]
			local badge = parser.isNew and "New" or (parser.isUpdated and "Updated" or "")
			local nameWidth = 560 - (favourite and 24 or 0) - (parser.NSFW and 54 or 0) - (badge ~= "" and Font.getTextWidth(FONT16, badge) + 10 or 0)
			local name = FitText(FONT26, parser.Name, nameWidth)
			Font.print(FONT26, 229, y - 64, name, COLOR_FONT)
			local lang_text = parser.Custom and "Your site" or (Language[Settings.Language].PARSERS[parser.Lang] or parser.Lang or "")
			lang_text = FitText(FONT16, lang_text, 130)
			Font.print(FONT16, 931 - Font.getTextWidth(FONT16, lang_text), y - 29, lang_text, COLOR_SUBFONT)
			local width = Font.getTextWidth(FONT26, name)
			if favourite then
				Graphics.drawImage(235 + width, y - 56, MiniStarIcon.e, UI.color("SELECTOR"))
				width = width + 24
			end
			if parser.NSFW then
				Font.print(FONT16, 235 + width, y - 56, "NSFW", UI.color("SELECTOR"))
				width = width + 54
			end
			if badge ~= "" then
				Font.print(FONT16, 235 + width, y - 56, badge, UI.color("DANGER"))
			end
			local version = FitText(FONT16, "v" .. tostring(parser.Version or ""), 130)
			Font.print(FONT16, 931 - Font.getTextWidth(FONT16, version), y - 59, version, COLOR_SUBFONT)
			local link_text = FitText(FONT16, (parser.Link or ""):gsub("/+$", ""), 550)
			Font.print(FONT16, 229, y - 29, link_text, COLOR_SUBFONT)
			y = y + 75
		end
		local elementsCount = #parsersList
		if elementsCount > 7 then
			scrollHeight = elementsCount * 75 / 524
		end
		item = parserSelector:getSelected()
	elseif status == "PCSOURCES" then
		if #pcSources == 0 then
			if pcSync then
				centerScreenMessage = "Loading sources from the PC..."
			else
				centerScreenMessage = (pcSyncMessage or "No sources yet") .. "\n\nPress Circle to type a site address\nPress Triangle to refresh"
			end
		end
		local first = max(1, floor((slider.Y - 10) / 75))
		local y = first * 75 - slider.Y
		for i = first, min(#pcSources, first + 9) do
			local src = pcSources[i]
			UI.listCard(y - 70, y - 3, slider.ItemID == i or pcSelector:getSelected() == i)
			Font.print(FONT26, 229, y - 64, FitText(FONT26, src.Name or src.Site or "", 550), COLOR_FONT)
			local info = src.Manual and "" or ((src.Count or 0) .. " added")
			Font.print(FONT16, 931 - Font.getTextWidth(FONT16, info), y - 59, info, COLOR_SUBFONT)
			local hint = (src.Manual and "Added here" or "From your PC") .. "  ·  " .. (src.Site or "")
			Font.print(FONT16, 229, y - 29, FitText(FONT16, hint, 690), COLOR_SUBFONT)
			y = y + 75
		end
		if #pcSources > 7 then
			scrollHeight = #pcSources * 75 / 524
		end
		item = pcSelector:getSelected()
	elseif status == "IMPORT" then
		local list = Import.listDir()
		local start = max(1, floor((slider.Y - 10) / 75))
		local y = start * 75 - slider.Y
		for i = start, min(#list, start + 9) do
			local object = list[i]
			UI.listCard(y - 70, y - 3, slider.ItemID == i or importSelector:getSelected() == i)
			if object.active then
				Font.print(FONT26, 229, y - 64, FitText(FONT26, object.name, 610), COLOR_FONT)
			elseif object.directory then
				Font.print(FONT26, 229, y - 64, FitText(FONT26, Language[Settings.Language].IMPORT.EXTERNAL_MEMORY, 610), UI.color("SELECTOR"))
			else
				Font.print(FONT26, 229, y - 64, FitText(FONT26, object.name, 610), COLOR_SUBFONT)
			end
			local textDis = object.name == "..." and Language[Settings.Language].IMPORT.GOBACK or object.directory and (object.active and Language[Settings.Language].IMPORT.FOLDER or Language[Settings.Language].IMPORT.DRIVE .. ' "' .. object.name .. '"') or object.active and Language[Settings.Language].IMPORT.FILE or Language[Settings.Language].IMPORT.UNSUPFILE
			Font.print(FONT16, 229, y - 29, FitText(FONT16, textDis, 610), COLOR_SUBFONT)
			if object.active and object.name ~= "..." then
				Graphics.fillRect(865, 866, y - 58, y - 15, COLOR_SUBFONT)
				Graphics.drawImage(897, y - 49, ImportIcon.e, COLOR_ICON_EXTRACT)
			end
			y = y + 75
		end
		local elementsCount = #list
		if elementsCount > 7 then
			scrollHeight = elementsCount * 75 / 524
		end
		item = importSelector:getSelected()
	elseif status == "DOWNLOAD" then
		local list = ChapterSaver.getDownloadingList()
		if #list > 0 then
			local start = max(1, floor((slider.Y - 10) / 75))
			local y = start * 75 - slider.Y
			for i = start, min(#list, start + 9) do
				local task = list[i]
				local pageCount = task.page_count or 0
				local page = task.page or 0
				UI.listCard(y - 70, y - 3, slider.ItemID == i or downloadSelector:getSelected() == i)
				Font.print(FONT20, 229, y - 65, FitText(FONT20, task.MangaName, 690), COLOR_FONT)
				Font.print(FONT16, 229, y - 42, FitText(FONT16, task.ChapterName, 690), COLOR_SUBFONT)
				if task.Saved then
					Font.print(FONT16, 229, y - 23, "Downloaded", UI.color("SELECTOR"))
				elseif pageCount > 0 then
					local textCounter = math.ceil(page) .. "/" .. pageCount
					local w = Font.getTextWidth(FONT16, textCounter)
					downloadBarValue = max(0, min(1, page / pageCount))
					local left = min(915, 241 + w)
					UI.roundRect(left, 931, y - 17, y - 11, COLOR_SELECTED)
					if downloadBarValue > 0 then
						UI.roundRect(left, left + (931 - left) * downloadBarValue, y - 17, y - 11, UI.color("SELECTOR"))
					end
					Font.print(FONT16, 229, y - 23, textCounter, UI.color("SELECTOR"))
				else
					Font.print(FONT16, 229, y - 23, i == 1 and "Preparing download…" or "Queued", COLOR_SUBFONT)
				end
				y = y + 75
			end
		else
			centerScreenMessage = Language[Settings.Language].MESSAGE.NO_DOWNLOADING_MANGA
		end
		local elementsCount = #list
		if elementsCount > 7 then
			scrollHeight = elementsCount * 75 / 524
		end
		item = downloadSelector:getSelected()
	elseif status == "SETTINGS" then
		local list = Settings.list()
		local start = max(1, floor((slider.Y - 10) / 75))
		local y = start * 75 - slider.Y
		for i = start, min(#list, start + 9) do
			local task = list[i]
			local extraHeight = task == "Translators" and 145 or 0
			-- Settings use three text lines; the taller credits card keeps its existing extent.
			UI.listCard(y - 73, y - 2 + extraHeight, slider.ItemID == i or settingSelector:getSelected() == i)
			if type(task) == "table" then
				if Settings.getTab() == "DonatorsList" then
					if i == 1 then
						Font.print(FONT26, (215 + 945) / 2 - Font.getTextWidth(FONT26, task.name) / 2, y - 45 - Font.getTextHeight(FONT26, task.name) / 2, task.name, UI.color("DANGER"))
					else
						Font.print(FONT26, (215 + 945) / 2 - Font.getTextWidth(FONT26, task.name) / 2, y - 45 - Font.getTextHeight(FONT26, task.name) / 2, task.name, COLOR_FONT)
					end
				else
					Font.print(FONT20, 225, y - 70, task.name, COLOR_FONT)
					if task.type == "savedChapter" then
						Font.print(FONT16, 225, y - 44, task.info, COLOR_SUBFONT)
					end
				end
			else
				if task == "DonatorsList" then
					Font.print(FONT20, 225, y - 70, Language[Settings.Language].SETTINGS[task] or task, Color.new(136, 0, 255))
					if Language[Settings.Language].SETTINGS_DESCRIPTION[task] then
						Font.print(FONT16, 225, y - 44, Language[Settings.Language].SETTINGS_DESCRIPTION[task], UI.color("SELECTOR"))
					end
				else
					Font.print(FONT20, 225, y - 70, FitText(FONT20, Language[Settings.Language].SETTINGS[task] or task, 710), COLOR_FONT)
					local rowDescription = Language[Settings.Language].SETTINGS_DESCRIPTION[task]
					if rowDescription then
						if Settings.isTab(task) then
							-- sub menus have no value line, the description takes it
							Font.print(FONT16, 225, y - 44, FitText(FONT16, rowDescription, 710), COLOR_SUBFONT)
						elseif task == "DeleteAddedSources" then
							-- the "press again" warning replaces the description (they used to be drawn on top of each other)
							if sure_delete_sources == 0 then
								Font.print(FONT16, 225, y - 44, FitText(FONT16, rowDescription, 710), COLOR_SUBFONT)
							end
						else
							-- options that show a value on the 2nd line get their description on the 3rd line
							Font.print(FONT16, 225, y - 24, FitText(FONT16, rowDescription, 710), COLOR_SUBFONT)
						end
					end
				end
				if task == "Language" then
					Font.print(FONT16, 225, y - 44, LanguageNames[Settings.Language][Settings.Language], COLOR_FONT)
				elseif task == "ClearChapters" then
					if chaptersFolderSize == nil then
						chaptersFolderSize = 0
						local function getDirectorySize(dir)
							local d = listDirectory(dir) or {}
							for k = 1, #d do
								if d[k].directory then
									getDirectorySize(dir .. "/" .. d[k].name)
								else
									chaptersFolderSize = chaptersFolderSize + d[k].size
								end
							end
						end
						getDirectorySize("ux0:data/noboru/chapters")
						if doesDirExist("uma0:data/noboru/chapters") then
							getDirectorySize("uma0:data/noboru/chapters")
						end
					end
					Font.print(FONT16, 225, y - 44, BytesToStr(chaptersFolderSize), COLOR_SUBFONT)
					if sure_clear_chapters > 0 then
						Font.print(FONT16, 225, y - 24, Language[Settings.Language].SETTINGS.PressAgainToAccept, UI.color("DANGER"))
					end
				elseif task == "ReaderMode" then
					Font.print(FONT16, 225, y - 44, Language[Settings.Language].READER[Settings.ReaderMode] or Settings.ReaderMode, COLOR_SUBFONT)
				elseif task == "ReaderOrientation" then
					Font.print(FONT16, 225, y - 44, Language[Settings.Language].READER[Settings.Orientation], COLOR_SUBFONT)
				elseif task == "PreferredCatalogLanguage" then
					Font.print(FONT16, 225, y - 44, Language[Settings.Language].PARSERS[Settings.ParserLanguage] or Settings.ParserLanguage or "error_type", COLOR_SUBFONT)
				elseif task == "ShowNSFW" then
					Font.print(FONT16, 225, y - 44, Language[Settings.Language].NSFW[Settings.NSFW], Settings.NSFW and UI.color("DANGER") or UI.color("SELECTOR"))
				elseif task == "HideInOffline" then
					Font.print(FONT16, 225, y - 44, Language[Settings.Language].YORN[Settings.HideInOffline], UI.color("SELECTOR"))
				elseif task == "SkipFontLoading" then
					Font.print(FONT16, 225, y - 44, Language[Settings.Language].YORN[Settings.SkipFontLoad], UI.color("SELECTOR"))
				elseif task == "ZoomReader" then
					Font.print(FONT16, 225, y - 44, Language[Settings.Language].READER[Settings.ZoomReader], COLOR_SUBFONT)
				elseif task == "DoubleTapReader" then
					Font.print(FONT16, 225, y - 44, Language[Settings.Language].YORN[Settings.DoubleTapReader], UI.color("SELECTOR"))
				elseif task == "RefreshLibAtStart" then
					Font.print(FONT16, 225, y - 44, Language[Settings.Language].YORN[Settings.RefreshLibAtStart], UI.color("SELECTOR"))
				elseif task == "UISoundDirections" or task == "UISoundCross" or task == "UISoundCircle" or task == "UISoundSquare" then
					Font.print(FONT16, 225, y - 44, Language[Settings.Language].YORN[Settings[task] ~= false], UI.color("SELECTOR"))
				elseif task == "SilentDownloads" then
					Font.print(FONT16, 225, y - 44, Language[Settings.Language].YORN[Settings.SilentDownloads], UI.color("SELECTOR"))
				elseif task == "ChangeUI" then
					Font.print(FONT16, 225, y - 44, Language[Settings.Language].THEME[Settings.Theme] or Settings.Theme, COLOR_SUBFONT)
				elseif task == "LibrarySorting" then
					Font.print(FONT16, 225, y - 44, Settings.LibrarySorting, COLOR_SUBFONT)
				elseif task == "GridDisplay" then
					Font.print(FONT16, 225, y - 44, Settings.GridDisplay, UI.color("SELECTOR"))
				elseif task == "GridColumns" then
					Font.print(FONT16, 225, y - 44, tostring(Settings.GridColumns), UI.color("SELECTOR"))
				elseif task == "ChapterSorting" then
					Font.print(FONT16, 225, y - 44, Settings.ChapterSorting, COLOR_SUBFONT)
				elseif task == "ConnectionTime" then
					Font.print(FONT16, 225, y - 44, Settings.ConnectionTime, UI.color("SELECTOR"))
				elseif task == "WebpConvert" then
					Font.print(FONT16, 225, y - 44, string.upper(Settings.WebpConvert), UI.color("SELECTOR"))
				elseif task == "FastImages" then
					Font.print(FONT16, 225, y - 44, Language[Settings.Language].YORN[Settings.FastImages ~= false], UI.color("SELECTOR"))
				elseif task == "VitaSurfBridge" then
					Font.print(FONT16, 225, y - 44, Language[Settings.Language].YORN[Settings.VitaSurfBridge ~= false], UI.color("SELECTOR"))
				elseif task == "SiteProfiles" then
					Font.print(FONT16, 225, y - 44, Language[Settings.Language].YORN[Settings.SiteProfiles ~= false], UI.color("SELECTOR"))
				elseif task == "ReaderClock" then
					local clockNames = { off = "OFF", time = "TIME", date = "DATE", both = "TIME + DATE" }
					Font.print(FONT16, 225, y - 44, clockNames[Settings.ReaderClock or "off"] or "OFF", UI.color("SELECTOR"))
				elseif task == "ReaderClockPos" then
					Font.print(FONT16, 225, y - 44, Settings.ReaderClockPos == "right" and "TOP RIGHT" or "TOP LEFT", UI.color("SELECTOR"))
				elseif task == "ReaderClock24h" then
					Font.print(FONT16, 225, y - 44, Language[Settings.Language].YORN[Settings.ReaderClock24h == true], UI.color("SELECTOR"))
				elseif task == "CFCheck" then
					Font.print(FONT16, 225, y - 44, Language[Settings.Language].YORN[Settings.CFCheck ~= false], UI.color("SELECTOR"))
				elseif task == "CFBridge" then
					Font.print(FONT16, 225, y - 44, string.upper(Settings.CFBridge or "auto"), UI.color("SELECTOR"))
				elseif task == "UseProxy" then
					Font.print(FONT16, 225, y - 44, Language[Settings.Language].YORN[Settings.UseProxy], UI.color("SELECTOR"))
				elseif task == "ProxyIP" then
					Font.print(FONT16, 225, y - 44, Settings.ProxyIP, COLOR_SUBFONT)
				elseif task == "ProxyPort" then
					Font.print(FONT16, 225, y - 44, Settings.ProxyPort, COLOR_SUBFONT)
				elseif task == "UseProxyAuth" then
					Font.print(FONT16, 225, y - 44, Language[Settings.Language].YORN[Settings.UseProxyAuth], UI.color("SELECTOR"))
				elseif task == "SkipCacheChapterChecking" then
					Font.print(FONT16, 225, y - 44, Language[Settings.Language].YORN[Settings.SkipCacheChapterChecking], UI.color("SELECTOR"))
				elseif task == "PressEdgesToChangePage" then
					Font.print(FONT16, 225, y - 44, Language[Settings.Language].YORN[Settings.PressEdgesToChangePage], UI.color("SELECTOR"))
				elseif task == "ProxyAuth" then
					Font.print(FONT16, 225, y - 44, Settings.ProxyAuth, COLOR_SUBFONT)
				elseif task == "ChapterSorting" then
					Font.print(FONT16, 225, y - 44, Settings.ChapterSorting, COLOR_SUBFONT)
				elseif task == "LeftStickDeadZone" then
					local x = 0
					for n = 1, #DeadZoneValues do
						Font.print(FONT16, 225 + x, y - 44, DeadZoneValues[n], DeadZoneValues[n] == Settings.LeftStickDeadZone and UI.color("DANGER") or COLOR_SUBFONT)
						x = x + Font.getTextWidth(FONT16, DeadZoneValues[n]) + 5
					end
				elseif task == "LeftStickSensitivity" then
					local x = 0
					for n = 1, #SensitivityValues do
						Font.print(FONT16, 225 + x, y - 44, SensitivityValues[n], SensitivityValues[n] == Settings.LeftStickSensitivity and UI.color("DANGER") or COLOR_SUBFONT)
						x = x + Font.getTextWidth(FONT16, SensitivityValues[n]) + 5
					end
				elseif task == "RightStickDeadZone" then
					local x = 0
					for n = 1, #DeadZoneValues do
						Font.print(FONT16, 225 + x, y - 44, DeadZoneValues[n], DeadZoneValues[n] == Settings.RightStickDeadZone and UI.color("DANGER") or COLOR_SUBFONT)
						x = x + Font.getTextWidth(FONT16, DeadZoneValues[n]) + 5
					end
				elseif task == "RightStickSensitivity" then
					local x = 0
					for n = 1, #SensitivityValues do
						Font.print(FONT16, 225 + x, y - 44, SensitivityValues[n], SensitivityValues[n] == Settings.RightStickSensitivity and UI.color("DANGER") or COLOR_SUBFONT)
						x = x + Font.getTextWidth(FONT16, SensitivityValues[n]) + 5
					end
				elseif task == "ChangingPageButtons" then
					Font.print(FONT16, 225, y - 44, Language[Settings.Language].PAGINGCONTROLS[Settings.ChangingPageButtons], COLOR_SUBFONT)
				elseif task == "Translators" then
					Font.print(
						FONT16,
						225,
						y - 44,
						("@SamuEDL :- Spanish \n@nguyenmao2101 :- Vietnamese \n@theheroGAC :- Italian \n@Cimmerian_Iter :- French \n@kemalsanli :- Turkish \n@rutantan :- PortugueseBR \n@Qingyu510 :- SimplifiedChinese &- TraditionalChinese \n@tmihai20 :- Romanian \n@tof4 :- Polish \n@lukrynka :- German \n@newplicyvimeo :- Japanese "):gsub(
							"%- (.-) ",
							function(a)
								return " " .. (LanguageNames[Settings.Language][a] or a) .. " "
							end
						),
						UI.color("SELECTOR")
					)
				elseif task == "DeleteAddedSources" then
					if sure_delete_sources > 0 then
						Font.print(FONT16, 225, y - 44, Language[Settings.Language].SETTINGS.PressAgainToAccept, UI.color("DANGER"))
					end
				elseif task == "ClearLibrary" then
					if sure_clear_library > 0 then
						Font.print(FONT16, 225, y - 44, Language[Settings.Language].SETTINGS.PressAgainToAccept, UI.color("DANGER"))
					end
				elseif task == "ClearCache" then
					if sure_clear_cache > 0 then
						Font.print(FONT16, 225, y - 44, Language[Settings.Language].SETTINGS.PressAgainToAccept, UI.color("DANGER"))
					end
				elseif task == "ClearAllCache" then
					if cacheFolderSize == nil then
						cacheFolderSize = 0
						local function getDirectorySize(dir)
							local d = listDirectory(dir) or {}
							for j = 1, #d do
								local f = d[j]
								if f.directory then
									getDirectorySize(dir .. "/" .. f.name)
								else
									cacheFolderSize = cacheFolderSize + f.size
								end
							end
						end
						getDirectorySize("ux0:data/noboru/cache")
					end
					Font.print(FONT16, 225, y - 44, BytesToStr(cacheFolderSize), COLOR_SUBFONT)
					if sure_clear_all_cache > 0 then
						Font.print(FONT16, 225, y - 24, Language[Settings.Language].SETTINGS.PressAgainToAccept, UI.color("DANGER"))
					end
				elseif task == "ShowAuthor" then
					Font.print(FONT16, 225, y - 44, "Claude AI (assistant)", COLOR_SUBFONT)
					Font.print(FONT16, 225, y - 24, "Fork of Creckeryop/NOBORU", UI.color("SELECTOR"))
				elseif task == "SupportDev" then
					Font.print(FONT16, 225, y - 44, "github.com/Creckeryop/NOBORU", COLOR_SUBFONT)
				elseif task == "ShowVersion" then
					Font.print(FONT16, 225, y - 44, Settings.Version, COLOR_SUBFONT)
				elseif task == "ReaderDirection" then
					Font.print(FONT16, 225, y - 44, Language[Settings.Language].READER[Settings.ReaderDirection], COLOR_SUBFONT)
				elseif task == "SwapXO" then
					Font.print(FONT16, 225, y - 44, Language[Settings.Language].SETTINGS[Settings.KeyType], COLOR_SUBFONT)
				elseif task == "CheckUpdate" then
					Font.print(FONT16, 225, y - 44, Language[Settings.Language].SETTINGS.LatestVersion .. Settings.LateVersion, tonumber(Settings.LateVersion) > tonumber(Settings.Version) and UI.color("SELECTOR") or COLOR_SUBFONT)
				elseif task == "SaveDataPath" then
					Font.print(FONT16, 225, y - 44, Settings.SaveDataPath, COLOR_SUBFONT)
				elseif task == "AnimatedGif" then
					Font.print(FONT16, 225, y - 44, Language[Settings.Language].YORN[Settings.AnimatedGif], COLOR_SUBFONT)
				elseif task == "LoadSummary" then
					Font.print(FONT16, 225, y - 44, Language[Settings.Language].YORN[Settings.LoadSummary], COLOR_SUBFONT)
				end
			end
			y = y + 75
		end
		local elementsCount = #list
		if elementsCount > 7 then
			scrollHeight = elementsCount * 75 / 524
		end
		item = settingSelector:getSelected()
		itemHeight = list[item] == "Translators" and 145 or 0
	elseif status == "MANGA" or status == "LIBRARY" or status == "HISTORY" then
		if #currentMangaList ~= 0 then
			local layout = Grid.layout()
			local start = Grid.first(slider.Y)
			for i = start, min(#currentMangaList, start + Grid.capacity() - 1) do
				local x = Grid.x(i)
				local y = gridY(i)
				DrawManga(x + layout.width / 2, y + layout.height / 2, currentMangaList[i], layout.width, layout.height, layout.coverOnly, layout.titlesBelow)
				UI.roundCorners(x, x + layout.width, y, y + layout.height, 10, COLOR_BACK)
				UI.roundBorder(x, x + layout.width, y, y + layout.height, 10, 1, UI.color("BORDER"))
				if status == "LIBRARY" and not layout.coverOnly and currentMangaList[i].Counter then
					local c = currentMangaList[i].Counter
					if c > 0 then
						UI.roundRect(x + 6, x + Font.getTextWidth(BONT16, c) + 22, y + 6, y + 30, UI.color("PRIMARY", 0.94))
						Font.print(BONT16, x + 14, y + 8, tostring(c), UI.color("ON_PRIMARY"))
					end
				end
			end
			local item = mangaSelector:getSelected()
			if item ~= 0 then
				local x, y = Grid.x(item), gridY(item)
				UI.focusBorder(x, x + layout.width, y, y + layout.height, 10)
			end
		else
			if status == "LIBRARY" then
				centerScreenMessage = Language[Settings.Language].MESSAGE.NO_LIBRARY_MANGA
			elseif status == "MANGA" then
				if not ParserManager.check(currentMangaList) and manga_load_status == 1 then
					centerScreenMessage = Language[Settings.Language].MESSAGE.NO_CATALOG_MANGA
				end
			elseif status == "HISTORY" then
				centerScreenMessage = Language[Settings.Language].MESSAGE.NO_HISTORY_MANGA
			end
		end
	end
	if centerScreenMessage then
		local lines = ToLines(centerScreenMessage)
		local height = 0
		for i, line in ipairs(lines) do
			local newLine = {}
			newLine.Height = Font.getTextHeight(FONT16, line)
			newLine.Width = Font.getTextWidth(FONT16, line)
			newLine.Text = line
			lines[i] = newLine
			height = height + newLine.Height + 4
		end
		local dy = 0
		for _, line in ipairs(lines) do
			Font.print(FONT16, 582 - math.floor(line.Width / 2), 272 - math.floor(height / 2) + dy, line.Text, Themes[Settings.Theme].COLOR_SUBFONT)
			dy = dy + line.Height + 4
		end
		if isGrid() then
			Graphics.drawImage(570, 192 - floor(height / 2), status == "HISTORY" and HistoryIcon.e or status == "MANGA" and SearchIcon.e or StarIcon.e, UI.color("SELECTOR"))
		elseif smile then
			Font.print(FONT26, 582 - math.floor(Font.getTextWidth(FONT26, smile) / 2), 272 - math.floor(height / 2) + dy + 6, smile, Themes[Settings.Theme].COLOR_SUBFONT)
		end
	end
	if item and item ~= 0 then
		local y = item * 75 - slider.Y
		if status == "CATALOGS" or status == "IMPORT" or status == "PCSOURCES" or status == "DOWNLOAD" then
			UI.focusBorder(215, 945, y - 70, y - 3, 10)
		elseif status == "SETTINGS" then
			UI.focusBorder(215, 945, y - 73, y - 2 + itemHeight, 10)
		end
	end
	if isGrid() then
		-- Paint the fixed header after the covers to clip their scrolling edge.
		Graphics.fillRect(205, 960, 0, 58, COLOR_BACK)
		Graphics.fillRect(221, 945, 57, 58, Color.new(Color.getR(COLOR_FONT), Color.getG(COLOR_FONT), Color.getB(COLOR_FONT), 30))
		local title = status == "MANGA" and (currentParser and currentParser.Name or Language[Settings.Language].APP.CATALOGS) or Language[Settings.Language].APP[status]
		Font.print(FONT26, 223, 15, FitText(FONT26, title, 650), COLOR_FONT)
		local count = tostring(#currentMangaList)
		local width = Font.getTextWidth(FONT20, count)
		UI.roundRect(929 - width, 945, 15, 43, COLOR_SELECTED)
		Font.print(FONT20, 937 - width, 18, count, COLOR_FONT)
		Graphics.fillRect(952, 960, 58, 544, COLOR_BACK)
		Graphics.fillRect(205, 960, 524, 544, COLOR_BACK)
		local limit = gridLimit()
		if limit > 0 then
			local track = 460
			local thumb = max(28, track * track / (limit + track))
			local top = 64 + (track - thumb) * max(0, min(1, slider.Y / limit))
			UI.roundRect(955, 959, top, top + thumb, COLOR_SUBFONT)
		end
	elseif status == "CATALOGS" or status == "IMPORT" or status == "SETTINGS" or status == "PCSOURCES" or status == "DOWNLOAD" then
		Graphics.fillRect(952, 960, 0, 544, COLOR_BACK)
		Graphics.fillRect(205, 960, 524, 544, COLOR_BACK)
		local content = (status == "IMPORT" and #Import.listDir() or status == "SETTINGS" and #Settings.list() or status == "PCSOURCES" and #pcSources or status == "DOWNLOAD" and #ChapterSaver.getDownloadingList() or #parsersList) * 75
		if status == "SETTINGS" and Settings.getTab() == "About" then content = content + 140 end
		if content > 504 then
			local thumb = max(28, 504 * 504 / content)
			local top = 10 + (504 - thumb) * max(0, min(1, (slider.Y + 10) / (content - 504)))
			UI.roundRect(955, 959, top, top + thumb, COLOR_SUBFONT)
		end
	else
		Graphics.fillRect(955, 960, 0, 544, COLOR_BACK)
		if scrollHeight then
			Graphics.fillRect(955, 960, slider.Y / scrollHeight, (slider.Y + 524) / scrollHeight, COLOR_FONT)
		else
			Graphics.fillRect(955, 960, 0, 524, COLOR_FONT)
		end
	end
end

---Frees all images loaded in catalog
function Catalogs.shrink()
	for _, i in ipairs(downloadedImages) do
		freeMangaImage(currentMangaList[i])
	end
	collectgarbage("collect")
	ParserManager.remove(currentMangaList)
	Loading.setStatus("NONE")
end

function Catalogs.terminate()
	Catalogs.shrink()
	downloadedImages = {}
	currentMangaList = {}
	page = 1
	slider.Y = -100
	slider.V = 0
	TOUCH_MODES.MODE = TOUCH_MODES.NONE
	mangaSelector:resetSelected()
	parserSelector:resetSelected()
	downloadSelector:resetSelected()
	settingSelector:resetSelected()
	importSelector:resetSelected()
	pcSelector:resetSelected()
	if pcSync then
		Threads.remove(pcSync)
		pcSync = nil
	end
end

---@param newStatus string | '"CATALOGS"' | '"MANGA"' | '"LIBRARY"' | '"DOWNLOAD"'
function Catalogs.setStatus(newStatus)
	status = newStatus
	chaptersFolderSize = nil
	cacheFolderSize = nil
	sure_clear_library = 0
	sure_clear_chapters = 0
	sure_clear_cache = 0
	manga_load_status = 0
	sure_clear_all_cache = 0
	sure_delete_sources = 0
	local smileIdx = math.random(1, #smilesList)
	if smilesList[smileIdx] then
		smile = smilesList[smileIdx]
	end
	Catalogs.terminate()
	if newStatus ~= "MANGA" then
		fromPcSources = false
		VitaServerSite = nil
	end
	if newStatus == "PCSOURCES" then
		loadPcSources()   -- show the saved sources at once; the PC refreshes the list if it answers
		startPcSync()
	end
end
