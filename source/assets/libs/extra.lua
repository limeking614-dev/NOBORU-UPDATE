Extra = {}

local status = "END"
local selectedManga
local chaptersList = {}
local selectedExtraMenu = {}
local selectedPage = nil
local customSettings = {}

local writeFile = System.writeFile
local closeFile = System.closeFile
local deleteFile = System.deleteFile
local openFile = System.openFile
local doesFileExist = System.doesFileExist
local callUri = System.executeUri
local extractZip = System.extractFromZip
local copyFile = CopyFile

local slider = CreateSlider()

local TOUCH_MODES = TOUCH_MODES
local DEFAULT_MAX_EXTRA_MENU_WIDTH = 512
local EXTRA_MENU_NORMAL = {"DownloadAll", "RemoveAll", "CancelAll", "ClearBookmarks", "ResetCover"}
local EXTRA_MENU_NORMAL_WITH_BROWSER = {"OpenMangaInBrowser", "DownloadAll", "RemoveAll", "CancelAll", "ClearBookmarks", "ResetCover"}
local EXTRA_MENU_IMPORTED = {"ClearBookmarks"}
local EXTRA_MENU_READER = {"OpenInBrowser", "ReaderWebtoon", "ReaderOrientation", "ReaderDirection", "ZoomReader", "SetPageAsCover", "DownloadImageToMemory"}
local EXTRA_MENU_READER_IMPORTED = {--[["OpenInBrowser",]] "ReaderWebtoon", "ReaderOrientation", "ReaderDirection", "ZoomReader", "DownloadImageToMemory"}

local fade = 0
local fadeFrom = 0
local maxExtraMenuWidth = 0
local extraMenuYDrawStart = 0

local fadeAnimationTimer = Timer.new()

local was_bookmarks_updated = false

local extraSelector =
	Selector:new(
	-1,
	1,
	0,
	0,
	function()
		return math.floor((slider.Y + extraMenuYDrawStart) / 64)
	end
)

---Updates scrolling movement
local function updateScrolling()
	local selectedItem = extraSelector.getSelected()
	if selectedItem ~= 0 then
		slider.Y = UI.approach(slider.Y, selectedItem * 64 - 272, UI.motion.scroll)
	end
	local decay = math.pow(1 / 1.12, UI.dt / (1000 / 60))
	slider.Y = slider.Y + slider.V * (1 - decay) / (1 - 1 / 1.12)
	slider.V = slider.V * decay
	if math.abs(slider.V) < 0.1 then
		slider.V = 0
	end
	if slider.Y < 0 then
		slider.Y = 0
		slider.V = 0
	elseif slider.Y > #selectedExtraMenu * 64 - 544 then
		slider.Y = math.max(0, #selectedExtraMenu * 64 - 544)
		slider.V = 0
	end
end

---Updates animation of fade in or out
local function animationUpdate()
	if status == "START" then
		fade = UI.transition(fadeFrom, 1, fadeAnimationTimer, UI.motion.enter)
	elseif status == "WAIT" then
		fade = UI.transition(fadeFrom, 0, fadeAnimationTimer, UI.motion.exit)
		if fade == 0 then status = "END" end
	end
end

local mode = ""

function Extra.setChapters(manga, chapters, page)
	if manga then
		mode = "setChapters"
		selectedManga = manga
		selectedPage = page
		chaptersList = chapters
		status = "START"
		was_bookmarks_updated = false

		slider.Y = -50
		slider.V = 0
		TOUCH_MODES.MODE = TOUCH_MODES.NONE
		if page then
			if manga.ParserID == "IMPORTED" then
				selectedExtraMenu = EXTRA_MENU_READER_IMPORTED
			else
				selectedExtraMenu = EXTRA_MENU_READER
			end
			selectedPage = page
			customSettings = CuSettings.load(selectedManga)
		elseif manga.ParserID == "IMPORTED" then
			selectedExtraMenu = EXTRA_MENU_IMPORTED
		else
			if selectedManga.BrowserLink then
				selectedExtraMenu = EXTRA_MENU_NORMAL_WITH_BROWSER
			else
				selectedExtraMenu = EXTRA_MENU_NORMAL
			end
		end
		extraSelector:resetSelected()
		fadeFrom = fade
		Timer.reset(fadeAnimationTimer)
		extraMenuYDrawStart = 272 - #selectedExtraMenu * 64 / 2 + 12
		maxExtraMenuWidth = DEFAULT_MAX_EXTRA_MENU_WIDTH
		for i = 1, #selectedExtraMenu do
			local extraOptionTextWidth = Font.getTextWidth(BONT16, Language[Settings.Language].EXTRA[selectedExtraMenu[i]] or selectedExtraMenu[i]) + 40
			if extraOptionTextWidth > maxExtraMenuWidth then
				maxExtraMenuWidth = math.min(720, extraOptionTextWidth)
			end
		end
	end
end

local langToCode = {}

function updateLanguagePick()
	selectedExtraMenu = {}
	langToCode = {}
	local langNames = {}
	for k, _ in pairs(Language) do
		if k ~= "Default" then
			langNames[#langNames + 1] = k
		end
	end
	table.sort(langNames)
	table.insert(langNames, 1, "Default")
	for _, k in ipairs(langNames) do
		if LanguageNames.English[k] then
			langToCode[#langToCode + 1] = k
			if k == Settings.Language then
				selectedExtraMenu[#selectedExtraMenu + 1] = ">> " .. LanguageNames[k][k] .. " (" .. LanguageNames.English[k] .. ") <<"
			else
				selectedExtraMenu[#selectedExtraMenu + 1] = LanguageNames[k][k] .. " (" .. LanguageNames.English[k] .. ")"
			end
		end
	end
end

function Extra.setLanguage()
	mode = "setLanguage"
	selectedExtraMenu = {}
	langToCode = {}
	status = "START"
	slider.Y = -50
	updateLanguagePick()
	extraSelector:resetSelected()
	fadeFrom = fade
	Timer.reset(fadeAnimationTimer)
	extraMenuYDrawStart = 0
	maxExtraMenuWidth = DEFAULT_MAX_EXTRA_MENU_WIDTH
end

local getTime = System.getTime
local getDate = System.getDate
local getImageFormat = System.getImageFormat
local rename = System.rename
local last_unique = nil

local function pressOption(id)
	if mode == "setChapters" then
		if selectedExtraMenu[id] == "DownloadAll" then
			Cache.addManga(selectedManga)
			Cache.makeHistory(selectedManga)
			for i = 1, #chaptersList do
				local chapter = chaptersList[i]
				if not ChapterSaver.is_downloading(chapter) and not ChapterSaver.check(chapter) then
					ChapterSaver.downloadChapter(chapter, true)
				end
			end
		elseif selectedExtraMenu[id] == "RemoveAll" then
			ChapterSaver.stopList(chaptersList, true)
			for i = 1, #chaptersList do
				ChapterSaver.delete(chaptersList[i], true)
			end
		elseif selectedExtraMenu[id] == "CancelAll" then
			ChapterSaver.stopList(chaptersList, true)
		elseif selectedExtraMenu[id] == "ClearBookmarks" then
			Cache.clearBookmarks(selectedManga)
			was_bookmarks_updated = true
		elseif selectedExtraMenu[id] == "OpenInBrowser" then
			if doesFileExist("ux0:data/noboru/temp/image.html") then
				deleteFile("ux0:data/noboru/temp/image.html")
			end
			local file = openFile("ux0:data/noboru/temp/image.html", FCREATE)
			if type(selectedPage) == "table" then
				if selectedManga.ParserID == "IMPORTED" then
					extractZip("ux0:data/noboru/" .. selectedPage.Path, selectedPage.Extract, "ux0:data/noboru/temp/page.image")
					selectedPage = "file:///ux0:data/noboru/temp/page.image"
				elseif selectedPage.Path then
					selectedPage = "file:///ux0:data/noboru/" .. selectedPage.Path
				elseif type(selectedPage.Link) == "string" then
					if selectedPage.Link:find("^http") then
						selectedPage = selectedPage.Link
					else
						selectedPage = "http://" .. selectedPage.Link
					end
				elseif type(selectedPage.Link) == "table" then
					local image = {}
					Threads.insertTask(
						image,
						{
							Type = "FileDownload",
							Link = selectedPage.Link,
							Table = image
						}
					)
					while Threads.check(image) do
						Threads.update()
					end
					selectedPage = "file:///ux0:data/noboru/temp/cache.image"
				else
					return
				end
			end
			local content = ([[<html><head><title>%s</title></head><body style="background-color: black;"><div style="text-align: center;"><img src="%s" width="100%%"></div></body></html>]]):format("NOBORU: " .. selectedManga.Name .. " | " .. chaptersList.Name, selectedPage)
			writeFile(file, content, #content)
			closeFile(file)
			callUri("webmodal: file:///ux0:data/noboru/temp/image.html")
		elseif selectedExtraMenu[id] == "ReaderWebtoon" then
			CuSettings.changeView(selectedManga)
			customSettings = CuSettings.load(selectedManga)
			Reader.setViewMode()
		elseif selectedExtraMenu[id] == "ReaderOrientation" then
			CuSettings.changeOrientation(selectedManga)
			Reader.updateSettings()
			customSettings = CuSettings.load(selectedManga)
		elseif selectedExtraMenu[id] == "ReaderDirection" then
			CuSettings.changeDirection(selectedManga)
			Reader.updateSettings()
			customSettings = CuSettings.load(selectedManga)
		elseif selectedExtraMenu[id] == "ZoomReader" then
			CuSettings.changeZoom(selectedManga)
			Reader.updateSettings()
			customSettings = CuSettings.load(selectedManga)
		elseif selectedExtraMenu[id] == "OpenMangaInBrowser" then
			callUri("webmodal: " .. selectedManga.BrowserLink)
		elseif selectedExtraMenu[id] == "ResetCover" then
			if selectedManga and selectedManga.ParserID ~= "IMPORTED" then
				local coverPath = "ux0:data/noboru/cache/" .. Cache.getKey(selectedManga) .. "/cover.image"
				if doesFileExist(coverPath) then
					deleteFile(coverPath)
				end
				local customCoverPath = "ux0:data/noboru/cache/" .. Cache.getKey(selectedManga) .. "/custom_cover.image"
				if doesFileExist(customCoverPath) then
					deleteFile(customCoverPath)
				end
				CustomCovers.setMangaCover(selectedManga, nil)
				selectedManga.ImageDownload = nil
				collectgarbage("collect")
				Notifications.push(Language[Settings.Language].NOTIFICATIONS.COVER_SET_COMPLETED)
			end
		elseif selectedExtraMenu[id] == "SetPageAsCover" then
			local page = Reader.getCurrentPageImageLink()
			if page then
				local cacheKey = Cache.getKey(selectedManga)
				if cacheKey == nil then
					Cache.addManga(selectedManga)
					cacheKey = Cache.getKey(selectedManga)
					if cacheKey == nil then
						return
					end
					Cache.save()
				end
				local tempTable = {}
				if page.Extract then
				elseif page.Path then
					CustomCovers.setMangaCover(selectedManga, page)
					copyFile(page.Path:find("^...?0:") and page.Path or ("ux0:data/noboru/" .. page.Path), "ux0:data/noboru/cache/" .. cacheKey .. "/custom_cover.image")
					Notifications.push(Language[Settings.Language].NOTIFICATIONS.COVER_SET_COMPLETED)
				elseif page.ParserID then
					CustomCovers.setMangaCover(selectedManga, page)
					Threads.insertTask(
						tempTable,
						{
							Type = "function",
							OnComplete = function()
								ParserManager.getPageImage(page.ParserID, page.Link, tempTable)
								while (ParserManager.check(tempTable)) do
									coroutine.yield(false)
								end
								Threads.insertTask(
									tempTable,
									{
										Type = "FileDownload",
										Link = tempTable.Link,
										Path = "ux0:data/noboru/cache/" .. cacheKey .. "/custom_cover.image",
										OnComplete = function()
											Notifications.push(Language[Settings.Language].NOTIFICATIONS.COVER_SET_COMPLETED)
										end
									}
								)
							end
						}
					)
				elseif page.Link then
					CustomCovers.setMangaCover(selectedManga, page)
					Threads.insertTask(
						tempTable,
						{
							Type = "FileDownload",
							Link = page.Link,
							Path = "ux0:data/noboru/cache/" .. cacheKey .. "/custom_cover.image",
							OnComplete = function()
								Notifications.push(Language[Settings.Language].NOTIFICATIONS.COVER_SET_COMPLETED)
							end
						}
					)
				else
					return
				end
			end
		elseif selectedExtraMenu[id] == "DownloadImageToMemory" then
			local page = Reader.getCurrentPageImageLink()
			if page then
				local drive = Settings.SaveDataPath
				local tempTable = {}
				local h, mn, s = getTime()
				local _, d, mo, y = getDate()
				if #tostring(d) == 1 then
					d = "0" .. tostring(d)
				end
				if #tostring(mo) == 1 then
					mo = "0" .. tostring(mo)
				end
				if #tostring(h) == 1 then
					h = "0" .. tostring(h)
				end
				if #tostring(mn) == 1 then
					mn = "0" .. tostring(mn)
				end
				if #tostring(s) == 1 then
					s = "0" .. tostring(s)
				end
				local unique_name = y .. "." .. mo .. "." .. d .. "-" .. h .. "." .. mn .. "." .. s
				if unique_name ~= last_unique then
					last_unique = unique_name
					if page.Extract then
					elseif page.Path then
						copyFile(page.Path:find("^...?0:") and page.Path or ("ux0:data/noboru/" .. page.Path), drive .. ":data/noboru/pictures/" .. unique_name .. ".image")
						local f = getImageFormat(drive..":data/noboru/pictures/" .. unique_name .. ".image")
						if f ~= nil then
							rename(drive .. ":data/noboru/pictures/" .. unique_name .. ".image", drive .. ":data/noboru/pictures/" .. unique_name .. "." .. f)
							Notifications.push(string.format(Language[Settings.Language].NOTIFICATIONS.END_DOWNLOAD, "image", drive .. ":data/noboru/pictures/" .. unique_name .. "." .. f), 1000)
						end
					elseif page.ParserID then
						Threads.insertTask(
							tempTable,
							{
								Type = "function",
								OnComplete = function()
									ParserManager.getPageImage(page.ParserID, page.Link, tempTable)
									while (ParserManager.check(tempTable)) do
										coroutine.yield(false)
									end
									Threads.insertTask(
										tempTable,
										{
											Type = "FileDownload",
											Link = tempTable.Link,
											Path = drive .. ":data/noboru/pictures/" .. unique_name .. ".image",
											OnComplete = function()
												if doesFileExist(drive .. ":data/noboru/pictures/" .. unique_name .. ".image") then
													local f = getImageFormat(drive .. ":data/noboru/pictures/" .. unique_name .. ".image")
													if f ~= nil then
														rename(drive .. ":data/noboru/pictures/" .. unique_name .. ".image", drive .. ":data/noboru/pictures/" .. unique_name .. "." .. f)
													end
													Notifications.push(string.format(Language[Settings.Language].NOTIFICATIONS.END_DOWNLOAD, "image", drive .. ":data/noboru/pictures/" .. unique_name .. "." .. f), 1000)
												end
											end
										}
									)
								end
							}
						)
					elseif page.Link then
						Threads.insertTask(
							tempTable,
							{
								Type = "FileDownload",
								Link = page.Link,
								Path = drive .. ":data/noboru/pictures/" .. unique_name .. ".image",
								OnComplete = function()
									if doesFileExist(drive .. ":data/noboru/pictures/" .. unique_name .. ".image") then
										local f = getImageFormat(drive .. ":data/noboru/pictures/" .. unique_name .. ".image")
										if f ~= nil then
											rename(drive .. ":data/noboru/pictures/" .. unique_name .. ".image", drive .. ":data/noboru/pictures/" .. unique_name .. "." .. f)
										end
										Notifications.push(string.format(Language[Settings.Language].NOTIFICATIONS.END_DOWNLOAD, "image", drive .. ":data/noboru/pictures/" .. unique_name .. "." .. f), 1000)
									end
								end
							}
						)
					else
						return
					end
				end
			end
		end
	elseif mode == "setLanguage" then
		if langToCode[id] then
			Settings.Language = langToCode[id]
			GenPanels()
			Settings.save()
		end
	end
end

function Extra.doesBookmarksUpdate()
	local a = was_bookmarks_updated
	was_bookmarks_updated = false
	return a
end

function Extra.input(oldPad, pad, oldTouch, touch)
	if status == "START" then
		if TOUCH_MODES.MODE == TOUCH_MODES.NONE and oldTouch.x and touch.x and touch.x > 480 - maxExtraMenuWidth / 2 then
			TOUCH_MODES.MODE = TOUCH_MODES.READ
			slider.TouchY = touch.y
		elseif TOUCH_MODES.MODE ~= TOUCH_MODES.NONE and not touch.x then
			if TOUCH_MODES.MODE == TOUCH_MODES.READ and oldTouch.x then
				if oldTouch.x > 480 - maxExtraMenuWidth / 2 and oldTouch.x < 480 + maxExtraMenuWidth / 2 and oldTouch.y > extraMenuYDrawStart and oldTouch.y < extraMenuYDrawStart + #selectedExtraMenu * 64 then
					local id = math.floor((slider.Y + oldTouch.y - extraMenuYDrawStart) / 64) + 1
					pressOption(id)
					if mode == "setLanguage" then
						if mode == "setLanguage" then
							updateLanguagePick()
						end
					end
				elseif mode == "setChapters" and oldTouch.x > 480 - maxExtraMenuWidth / 2 and oldTouch.x < 480 + maxExtraMenuWidth / 2 and oldTouch.y >= extraMenuYDrawStart + #selectedExtraMenu * 64 and oldTouch.y <= extraMenuYDrawStart + #selectedExtraMenu * 64 + 28 then
					status = "WAIT"
					fadeFrom = fade
					Timer.reset(fadeAnimationTimer)
				end
			end
			TOUCH_MODES.MODE = TOUCH_MODES.NONE
		end
		extraSelector:input(#selectedExtraMenu, oldPad, pad, touch.x)
		if Controls.check(pad, SCE_CTRL_CROSS) and not Controls.check(oldPad, SCE_CTRL_CROSS) then
			local id = extraSelector.getSelected()
			pressOption(id)
			if mode == "setLanguage" then
				updateLanguagePick()
			end
		elseif Controls.check(pad, SCE_CTRL_CIRCLE) and not Controls.check(oldPad, SCE_CTRL_CIRCLE) then
			status = "WAIT"
			fadeFrom = fade
			Timer.reset(fadeAnimationTimer)
		elseif Controls.check(pad, SCE_CTRL_START) and not Controls.check(oldPad, SCE_CTRL_START) then
			status = "WAIT"
			fadeFrom = fade
			Timer.reset(fadeAnimationTimer)
		elseif touch.x ~= nil and oldTouch.x == nil then
			if touch.x > 480 - maxExtraMenuWidth / 2 and touch.x < 480 + maxExtraMenuWidth / 2 and touch.y > (mode == "setChapters" and extraMenuYDrawStart - 52 or extraMenuYDrawStart) and touch.y < extraMenuYDrawStart + 64 * #selectedExtraMenu + (mode == "setChapters" and 28 or 0) then
			else
				status = "WAIT"
				fadeFrom = fade
				Timer.reset(fadeAnimationTimer)
			end
		end
		local newItemID = 0
		if TOUCH_MODES.MODE == TOUCH_MODES.READ then
			if math.abs(slider.V) > 0.1 or math.abs(touch.y - slider.TouchY) > 10 then
				TOUCH_MODES.MODE = TOUCH_MODES.SLIDE
			else
				if oldTouch.x > 480 - maxExtraMenuWidth / 2 and oldTouch.x < 480 + maxExtraMenuWidth / 2 then
					local id = math.floor((slider.Y + oldTouch.y - extraMenuYDrawStart) / 64) + 1
					if selectedExtraMenu[id] then
						newItemID = id
					end
				end
			end
		elseif TOUCH_MODES.MODE == TOUCH_MODES.SLIDE then
			if touch.x and oldTouch.x then
				slider.V = (oldTouch.y - touch.y) * (1000 / 60) / UI.dt
			end
		end
		if slider.ItemID > 0 and newItemID > 0 and slider.ItemID ~= newItemID then
			TOUCH_MODES.MODE = TOUCH_MODES.SLIDE
		else
			slider.ItemID = newItemID
		end
	end
end

function Extra.update()
	if status ~= "END" then
		animationUpdate()
		updateScrolling()
	end
end

function Extra.draw()
	if status == "END" then return end
	local M = fade
	local shift = (1 - M) * 20
	local count = #selectedExtraMenu
	local width = math.min(720, math.max(DEFAULT_MAX_EXTRA_MENU_WIDTH, maxExtraMenuWidth))
	local left, right = 480 - width / 2, 480 + width / 2
	local top = mode == "setChapters" and extraMenuYDrawStart - 52 or 0
	local bottom = mode == "setChapters" and extraMenuYDrawStart + count * 64 + 28 or 544
	Graphics.fillRect(0, 960, 0, 544, UI.color("OVERLAY", 0.6 * M))
	UI.fillRoundRect(left - 8, right + 8, top + shift, bottom + shift, 14, UI.color("SURFACE", M))
	UI.roundBorder(left - 8, right + 8, top + shift, bottom + shift, 14, 1, UI.color("BORDER", M))
	local start = math.max(1, math.floor(slider.Y / 64) + 1)
	local selected = extraSelector:getSelected()
	for i = start, math.min(count, start + 9) do
		local y = extraMenuYDrawStart + (i - 1) * 64 - slider.Y + shift
		if y >= 544 then break end
		local option = selectedExtraMenu[i]
		local label = Language[Settings.Language].SETTINGS[option] or Language[Settings.Language].EXTRA[option] or option
		if option == "ReaderWebtoon" then
			label = label .. ": " .. (Language[Settings.Language].READER[customSettings.ReaderView or "Default"] or customSettings.ReaderView)
		elseif option == "ReaderOrientation" then
			label = label .. ": " .. Language[Settings.Language].READER[customSettings.Orientation]
		elseif option == "ReaderDirection" then
			label = label .. ": " .. Language[Settings.Language].READER[customSettings.ReaderDirection]
		elseif option == "ZoomReader" then
			label = label .. ": " .. Language[Settings.Language].READER[customSettings.ZoomReader]
		end
		local active = selected == i or slider.ItemID == i
		UI.fillRoundRect(left + 8, right - 8, y + 5, y + 59, 10, UI.color(active and "SELECTED" or "BACK", M))
		local dangerous = option == "RemoveAll" or option == "ClearBookmarks" or option == "CancelAll"
		Font.print(BONT16, left + 26, y + 32 - Font.getTextHeight(BONT16, label) / 2, FitText(BONT16, label, width - 64), UI.color(dangerous and "DANGER" or "FONT", M))
		if selected == i then UI.focusBorder(left + 8, right - 8, y + 5, y + 59, 10, M) end
	end
	if mode == "setChapters" then
		UI.fillRoundRect(left - 8, right + 8, top + shift, extraMenuYDrawStart + shift - 2, 14, UI.color("SURFACE", M))
		local heading = selectedPage and "reader options" or "chapter options"
		Font.print(FONT20, left + 18, top + 7 + shift, UI.capitalize(heading), UI.color("FONT", M))
		Font.print(FONT16, left + 18, top + 32 + shift, FitText(FONT16, UI.capitalize(selectedManga.Name), width - 36), UI.color("SUBFONT", M))
		Graphics.fillRect(left + 18, right - 18, extraMenuYDrawStart + shift - 2, extraMenuYDrawStart + shift - 1, UI.color("BORDER", M))
		local button = Settings.KeyType == "JP" and ButtonsIcons.Cross or ButtonsIcons.Circle
		Graphics.drawImage(left + 18, bottom - 20 + shift, button.e, Color.new(255, 255, 255, 255 * M))
		Font.print(FONT16, left + 42, bottom - 22 + shift, UI.capitalize(Language[Settings.Language].PANEL.BACK or "back"), UI.color("SUBFONT", M))
		local closeX = right - 18 - Font.getTextWidth(FONT16, "close")
		Graphics.drawImage(closeX - 10 - ButtonsIcons.Start.Width, bottom - 20 + shift, ButtonsIcons.Start.e, Color.new(255, 255, 255, 255 * M))
		Font.print(FONT16, closeX, bottom - 22 + shift, "Close", UI.color("SUBFONT", M))
	end
	if count * 64 > 544 then
		local thumb = 544 * 544 / (count * 64)
		local y = (544 - thumb) * slider.Y / (count * 64 - 544)
		UI.roundRect(right + 2, right + 6, y, y + thumb, UI.color("SUBFONT", M))
	end
end

function Extra.getStatus()
	return status
end

function Extra.getFade()
	return fade
end
