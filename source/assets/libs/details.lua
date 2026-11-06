Details = {}

local status = "END"
local selectedManga = nil

local slider = CreateSlider()
local deleteFile = System.deleteFile
local doesFileExist = System.doesFileExist
local isCJK = IsCJK

local descriptionString = nil
local descriptionWordList = {}

local MANGA_COVER_CENTER_POINT = CreatePoint(140, 326 / 2 + 85)
local TOUCH_MODES = TOUCH_MODES
local DESCRIPTION_WIDTH = 670
local LINE_HEIGHT = 22

local chaptersMaxHeightOffset = 0
local descriptionMaxHeightOffset = 0

local fade = 0
local oldFade = 1

local crossIcon = Image:new(Graphics.loadImage("app0:assets/icons/cross.png"))
local menuIcon = Image:new(Graphics.loadImage("app0:assets/icons/menu.png"))
local sortIcons = {
	["N->1"] = Image:new(Graphics.loadImage("app0:assets/icons/sort-9-1.png")),
	["1->N"] = Image:new(Graphics.loadImage("app0:assets/icons/sort-1-9.png"))
}

local maxMangaNameTickerTimeMs = 0
local maxMangaNameOffset = 0
local maxChapterNameTickerTimeMs = 0
local maxChapterNameOffset = 0

local fadeTimer = Timer.new()
local mangaNameTickerTimer = Timer.new()
local chapterNameTickerTimer = Timer.new()

local is_notification_showed = false
local is_description_expanded = false
local is_chapter_list_loaded_offline = false
local is_chapter_list_ready = false

local chaptersList = {}
local continueChapterNumber
local detailsSelector =
	Selector:new(
	-1,
	1,
	-3,
	3,
	function()
		return math.max(1, math.floor((slider.Y + 95) / 80))
	end
)

---Updates scrolling movement
local function updateScrolling()
	local selectedItem = detailsSelector.getSelected()
	if selectedItem ~= 0 then
		local target = selectedItem * 80 - (544 - chaptersMaxHeightOffset) / 2
		slider.Y = UI.approach(slider.Y, math.max(-15, math.min(target, #chaptersList * 80 - 464 + chaptersMaxHeightOffset)), 90)
	end
	local decay = math.pow(1 / 1.12, UI.dt / (1000 / 60))
	slider.Y = slider.Y + slider.V * (1 - decay) / (1 - 1 / 1.12)
	slider.V = slider.V * decay
	if math.abs(slider.V) < 0.1 then
		slider.V = 0
	end
	if slider.Y < -15 then
		slider.Y = -15
		slider.V = 0
	elseif slider.Y > (#chaptersList * 80 - 464 + chaptersMaxHeightOffset) then
		slider.Y = math.max(-15, #chaptersList * 80 - 464 + chaptersMaxHeightOffset)
		slider.V = 0
	end
end

local easingFunction = EaseInOutCubic

---Updates animation of fade in or out
local function updateAnimations()
	if status == "START" then
		fade = easingFunction(math.min((Timer.getTime(fadeTimer) / 250), 1))
	elseif status == "WAIT" then
		if fade == 0 then
			status = "END"
		end
		fade = 1 - easingFunction(math.min((Timer.getTime(fadeTimer) / 250), 1))
	end
	if Timer.getTime(mangaNameTickerTimer) > 3500 + maxMangaNameTickerTimeMs then
		Timer.reset(mangaNameTickerTimer)
	end
	if Timer.getTime(chapterNameTickerTimer) > 3500 + maxChapterNameTickerTimeMs then
		Timer.reset(chapterNameTickerTimer)
	end
	if ParserManager.check(chaptersList) then
		Loading.setStatus("WHITE", 580, 250)
	else
		Loading.setStatus("NONE")
	end
end

---Updates `chaptersMaxHeightOffset` depending on if description is expanded
local function updateMangaDescriptionMaxHeight()
	if #descriptionWordList > 0 then
		local linesCount = is_description_expanded and #descriptionWordList or math.min(2, #descriptionWordList)
		local finalOffset = linesCount * LINE_HEIGHT + LINE_HEIGHT + 10
		if linesCount ~= #descriptionWordList or linesCount > 2 then
			finalOffset = finalOffset + LINE_HEIGHT
			chaptersMaxHeightOffset = math.max(LINE_HEIGHT * 4 + 10, math.min(chaptersMaxHeightOffset + (math.min(LINE_HEIGHT * (linesCount + 2) + 10, 544 - 95) - chaptersMaxHeightOffset) / 8, math.min(LINE_HEIGHT * (#descriptionWordList + 2) + 10, 544 - 95)))
			if not is_description_expanded then
				descriptionMaxHeightOffset = descriptionMaxHeightOffset - descriptionMaxHeightOffset / 8
			end
		else
			chaptersMaxHeightOffset = finalOffset
		end
	else
		chaptersMaxHeightOffset = 0
	end
end

---@param newDescription string
---Updates `descriptionString` and `descriptionWordList`
---This function analizing `newDescription` and creates data to make something like `align-text:justify` on css
local function updateMangaDescription(newDescription)
	descriptionString = (newDescription or ""):gsub("^%s+", ""):gsub("%s+$", "")
	local wordList = {}
	for word in descriptionString:gmatch("[^ ]+") do
		local newWord = ""
		for i = 1, #word do
			local s = string.sub(word, i, 1)
			if s ~= "" and isCJK(s) or s == "\n" then
				if newWord ~= "" then
					wordList[#wordList + 1] = newWord
					newWord = ""
				end
				wordList[#wordList + 1] = s
			else
				if s:match("[%.,]") then
					newWord = newWord .. s
					wordList[#wordList + 1] = newWord
					newWord = ""
				else
					newWord = newWord .. s
				end
			end
		end
		if newWord ~= "" then
			wordList[#wordList + 1] = newWord
		end
	end
	local lines = {}
	if #wordList > 0 then
		local w = 0
		lines[1] = {}
		for n = 1, #wordList do
			local word = wordList[n]
			local wordWidth = Font.getTextWidth(FONT16, word)
			if word == "\n" then
				w = 0
				lines[#lines].SpaceWidth = 4
				lines[#lines + 1] = {}
			elseif w + wordWidth + 4 > DESCRIPTION_WIDTH then
				w = wordWidth
				local spaceWidth = 0
				for i = 1, #lines[#lines] do
					spaceWidth = spaceWidth + lines[#lines][i].Width
				end
				spaceWidth = (DESCRIPTION_WIDTH - spaceWidth) / #lines[#lines]
				lines[#lines].SpaceWidth = spaceWidth
				lines[#lines + 1] = {}
			else
				w = w + wordWidth + 4
			end
			if word ~= "\n" then
				lines[#lines][#lines[#lines] + 1] = {Word = word, Width = wordWidth}
			end
		end
		lines[#lines].SpaceWidth = 4
	end
	descriptionWordList = lines
end

---Updates `chaptersList` when it's ready
local function updateChaptersList()
	if not is_chapter_list_loaded_offline and not ParserManager.check(chaptersList) then
		if #chaptersList > 0 then
			if Cache.isCached(chaptersList[1].Manga) then
				is_chapter_list_loaded_offline = true
				Cache.saveChapters(chaptersList[1].Manga, chaptersList)
			end
			local manga = chaptersList[1].Manga
			if manga.NewImageLink and not CustomCovers.hasCustomCover(manga) and manga.NewImageLink ~= selectedManga.ImageLink then
				local cover_path = "ux0:data/noboru/cache/" .. Cache.getKey(selectedManga) .. "/cover.image"
				if doesFileExist(cover_path) then
					deleteFile(cover_path)
				end
				selectedManga.ImageLink = manga.NewImageLink
				selectedManga.ImageDownload = nil
				collectgarbage("collect")
			end
		end
	end
	if not is_chapter_list_ready and not ParserManager.check(chaptersList) then
		is_chapter_list_ready = true
		if Settings.LoadSummary then
			updateMangaDescription(chaptersList.Description or "")
		else
			updateMangaDescription("")
		end
	end
end

---Sets Continue button to latest read chapter in given `Manga`
local function updateContinueChapterNumber()
	if AppMode == MENU and not continueChapterNumber and not ParserManager.check(chaptersList) then
		continueChapterNumber = 0
		if #chaptersList > 0 then
			chaptersList[1].Manga.Counter = #chaptersList
			local latestChapter = Cache.getLatestBookmark(selectedManga)
			for i = 1, #chaptersList do
				local key = chaptersList[i].Link:gsub("%p", "")
				if latestChapter == key then
					local bookmark = Cache.getBookmark(chaptersList[i])
					if bookmark == true then
						continueChapterNumber = i + 1
						if not chaptersList[continueChapterNumber] then
							continueChapterNumber = i
						end
						chaptersList[1].Manga.Counter = #chaptersList - i
					else
						continueChapterNumber = i
						chaptersList[1].Manga.Counter = #chaptersList - i + 1
					end
					break
				end
			end
			if continueChapterNumber > 0 then
				local continueChapterName = chaptersList[continueChapterNumber].Name or ("Chapter " .. continueChapterNumber)
				maxChapterNameTickerTimeMs = 25 * string.len(continueChapterName)
				maxChapterNameOffset = math.max(Font.getTextWidth(FONT16, continueChapterName) - 220, 0)
				Timer.reset(chapterNameTickerTimer)
			end
		end
	end
	if Extra.doesBookmarksUpdate() then
		continueChapterNumber = nil
	end
end

---@param manga table
---Sets `manga` to details
function Details.setManga(manga)
	if manga then
		selectedManga = manga
		status = "START"
		oldFade = 1
		slider.Y = -50
		slider.V = 0
		chaptersMaxHeightOffset = 0
		TOUCH_MODES.MODE = TOUCH_MODES.NONE

		maxMangaNameTickerTimeMs = 50 * string.len(manga.Name)
		maxMangaNameOffset = math.max(Font.getTextWidth(BONT30, manga.Name) - 960 + 88 + 88 + 88, 0)

		chaptersList = {}
		detailsSelector:resetSelected()

		if Cache.isCached(selectedManga) and not Cache.BookmarksLoaded(selectedManga) then
			Cache.loadBookmarks(selectedManga)
		elseif Database.check(selectedManga) then
			Cache.addManga(selectedManga, chaptersList)
		end

		continueChapterNumber = nil

		if Threads.netActionUnSafe(Network.isWifiEnabled) and GetParserByID(manga.ParserID) then
			ParserManager.getChaptersAsync(manga, chaptersList)
			is_chapter_list_loaded_offline = false
		else
			chaptersList = Cache.loadChapters(manga)
			is_chapter_list_loaded_offline = true
		end
		is_chapter_list_ready = false
		is_notification_showed = false
		is_description_expanded = false

		descriptionWordList = {}
		descriptionMaxHeightOffset = 0

		Timer.reset(fadeTimer)
		Timer.reset(mangaNameTickerTimer)
	end
end

---PC Server (vitaserver.py): asks the PC to delete this added manga / site
local deleteTimer = Timer.new()
local deleteArmed = false

local function isVitaServerManga()
	return selectedManga and selectedManga.ParserID == "VITASERVER" and selectedManga.Link ~= "vitaserver_setup"
end

local function vitaServerDelete(manga)
	local base
	local cfg = "ux0:data/noboru/vitaserver.lua"
	if doesFileExist(cfg) then
		local ok, t = pcall(dofile, cfg)
		if ok and type(t) == "table" and type(t.url) == "string" then
			base = (t.url:gsub("/+$", ""))
		end
	end
	if not base then
		Notifications.push("PC server address not set")
		return false
	end
	local q = tostring(manga.Link):gsub("[^%w%-_%.~]", function(c)
		return string.format("%%%02X", c:byte())
	end)
	local t = {}
	Threads.insertTask(t, {
		Type = "StringRequest",
		Link = base .. "/api/delete?q=" .. q,
		Table = t,
		Index = "text",
		Header1 = "X-Vita-Reader: 1"
	})
	Notifications.push("Delete sent to PC server - refresh Latest")
	return true
end

---Adds / Removes Manga from library
local function addToLibrary()
	if Database.check(selectedManga) then
		Database.removeManga(selectedManga)
		Notifications.push(Language[Settings.Language].NOTIFICATIONS.REMOVED_FROM_LIBRARY)
	else
		Database.addManga(selectedManga)
		Cache.addManga(selectedManga)
		Notifications.push(Language[Settings.Language].NOTIFICATIONS.ADDED_TO_LIBRARY)
	end
end

---@param item integer
---Download / Stop Download / Delete `chapterList[item]` Chapter
local function downloadChapter(item)
	local is_wifi_enabled = Threads.netActionUnSafe(Network.isWifiEnabled)
	item = chaptersList[item]
	if item then
		Cache.addManga(selectedManga, chaptersList)
		Cache.makeHistory(selectedManga)
		if not ChapterSaver.check(item) then
			if ChapterSaver.is_downloading(item) then
				ChapterSaver.stop(item)
			elseif is_wifi_enabled then
				ChapterSaver.downloadChapter(item)
			else
				Notifications.pushUnique(Language[Settings.Language].SETTINGS.NoConnection)
			end
		else
			ChapterSaver.delete(item)
		end
	end
end

---@param item integer
---Opens Reader and loads `chapterList` and `item` chapter in
local function readChapter(item)
	if chaptersList[item] then
		Catalogs.shrink()
		Cache.addManga(selectedManga, chaptersList)
		Cache.makeHistory(selectedManga)
		Reader.load(chaptersList, item)
		AppMode = READER
		continueChapterNumber = nil
	end
end

---@param oldPad table
---@param pad table
---@param oldTouch table
---@param touch table
---Updates input for Details menu
function Details.input(oldPad, pad, oldTouch, touch)
	if status == "START" then
		local oldTouchMode = TOUCH_MODES.MODE
		if TOUCH_MODES.MODE == TOUCH_MODES.NONE and oldTouch.x and touch.x and touch.x > 240 then
			TOUCH_MODES.MODE = TOUCH_MODES.READ
			slider.TouchY = touch.y
		elseif TOUCH_MODES.MODE ~= TOUCH_MODES.NONE and not touch.x then
			if TOUCH_MODES.MODE == TOUCH_MODES.READ and oldTouch.x then
				if oldTouch.x > 270 and oldTouch.x < 955 and oldTouch.y > 95 + chaptersMaxHeightOffset then
					local id = math.floor((slider.Y + oldTouch.y - chaptersMaxHeightOffset) / 80)
					if Settings.ChapterSorting == "N->1" then
						id = #chaptersList - id + 1
					end
					if oldTouch.x < 866 or selectedManga.ParserID == "IMPORTED" then
						readChapter(id)
					else
						downloadChapter(id)
					end
				elseif oldTouch.x > 270 and oldTouch.x < 960 and oldTouch.y > 90 and oldTouch.y <= 90 + chaptersMaxHeightOffset then
					is_description_expanded = not is_description_expanded
				end
			end
			TOUCH_MODES.MODE = TOUCH_MODES.NONE
		end
		local is_description_scrollable = not (is_description_expanded and #descriptionWordList >= 13)
		if is_description_scrollable then
			detailsSelector:input(#chaptersList, oldPad, pad, touch.x)
		else
			if Controls.check(pad, SCE_CTRL_UP) then
				descriptionMaxHeightOffset = math.max(descriptionMaxHeightOffset - 3, 0)
			elseif Controls.check(pad, SCE_CTRL_DOWN) then
				descriptionMaxHeightOffset = math.min(descriptionMaxHeightOffset + 3, math.max(0, #descriptionWordList * LINE_HEIGHT - (544 - 95 - 24 - 24 - 10)))
			end
		end
		if oldTouch.x and not touch.x then
			if oldTouch.x > 20 and oldTouch.x < 260 and oldTouch.y > 416 and oldTouch.y < 475 then
				addToLibrary()
			elseif oldTouch.x > 20 and oldTouch.x < 260 and oldTouch.y > 480 then
				if continueChapterNumber then
					readChapter(continueChapterNumber > 0 and continueChapterNumber or 1)
				end
			elseif oldTouch.x > 960 - 88 and oldTouch.y < 90 and is_chapter_list_ready and oldTouchMode == TOUCH_MODES.READ then
				Extra.setChapters(selectedManga, chaptersList)
			elseif isVitaServerManga() and oldTouch.x > 960 - 88 * 3 and oldTouch.x <= 960 - 88 * 2 and oldTouch.y < 90 and oldTouchMode == TOUCH_MODES.READ then
				if deleteArmed and Timer.getTime(deleteTimer) < 3000 then
					deleteArmed = false
					if vitaServerDelete(selectedManga) then
						status = "WAIT"
						Loading.setStatus("NONE")
						ParserManager.remove(chaptersList)
						Timer.reset(fadeTimer)
						oldFade = fade
					end
				else
					deleteArmed = true
					Timer.reset(deleteTimer)
					Notifications.push("Tap Delete again to remove this from the PC server")
				end
			elseif oldTouch.x > 960 - 88 - 88 and oldTouch.y < 90 and oldTouchMode == TOUCH_MODES.READ then
				SettingsFunctions.ChapterSorting()
				Settings.save()
			end
		elseif Controls.check(pad, SCE_CTRL_TRIANGLE) and not Controls.check(oldPad, SCE_CTRL_TRIANGLE) then
			addToLibrary()
		elseif is_description_scrollable and Controls.check(pad, SCE_CTRL_CROSS) and not Controls.check(oldPad, SCE_CTRL_CROSS) then
			local id = detailsSelector.getSelected()
			if Settings.ChapterSorting == "N->1" then
				id = #chaptersList - id + 1
			end
			readChapter(id)
		elseif Controls.check(pad, SCE_CTRL_CIRCLE) and not Controls.check(oldPad, SCE_CTRL_CIRCLE) or (touch.x and not oldTouch.x and touch.x < 88 and touch.y < 90) then
			status = "WAIT"
			Loading.setStatus("NONE")
			ParserManager.remove(chaptersList)
			Timer.reset(fadeTimer)
			oldFade = fade
		elseif is_description_scrollable and Controls.check(pad, SCE_CTRL_SQUARE) and not Controls.check(oldPad, SCE_CTRL_SQUARE) and selectedManga.ParserID ~= "IMPORTED" then
			local id = detailsSelector.getSelected()
			if Settings.ChapterSorting == "N->1" then
				id = #chaptersList - id + 1
			end
			downloadChapter(id)
		elseif Controls.check(pad, SCE_CTRL_SELECT) and not Controls.check(oldPad, SCE_CTRL_SELECT) then
			if continueChapterNumber then
				readChapter(continueChapterNumber > 0 and continueChapterNumber or 1)
			end
		elseif Controls.check(pad, SCE_CTRL_START) and not Controls.check(oldPad, SCE_CTRL_START) and is_chapter_list_ready then
			Extra.setChapters(selectedManga, chaptersList)
		elseif Controls.check(pad, SCE_CTRL_RTRIGGER) and not Controls.check(oldPad, SCE_CTRL_RTRIGGER) and is_chapter_list_ready then
			SettingsFunctions.ChapterSorting()
			Settings.save()
		elseif Controls.check(pad, SCE_CTRL_LTRIGGER) and not Controls.check(oldPad, SCE_CTRL_LTRIGGER) and is_chapter_list_ready then
			is_description_expanded = not is_description_expanded
		end
		local newItemID = 0
		if TOUCH_MODES.MODE == TOUCH_MODES.READ then
			if math.abs(slider.V) > 0.1 or math.abs(touch.y - slider.TouchY) > 10 then
				TOUCH_MODES.MODE = TOUCH_MODES.SLIDE
			else
				if oldTouch.x > 270 and oldTouch.x < 955 and oldTouch.y > 95 + chaptersMaxHeightOffset then
					local id = math.floor((slider.Y + oldTouch.y - chaptersMaxHeightOffset) / 80)
					if Settings.ChapterSorting == "N->1" then
						id = #chaptersList - id + 1
					end
					if chaptersList[id] then
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

---Updates Animations and Events for Details menu
function Details.update()
	if status ~= "END" then
		updateAnimations()
		updateMangaDescriptionMaxHeight()
		updateScrolling()
		updateChaptersList()
		updateContinueChapterNumber()
	end
end

---Draws Details menu
function Details.draw()
	if status == "END" then return end
	local M = oldFade * fade
	local Alpha = 255 * M
	local shift = (1 - M) * 24
	local backgroundColor = Color.new(14, 24, 39, Alpha)
	local textColor = Color.new(240, 246, 255, Alpha)
	local secondTextColor = Color.new(153, 174, 199, Alpha)
	local accentColor = Color.new(105, 197, 255, Alpha)
	Graphics.fillRect(0, 960, 0, 544, backgroundColor)
	Graphics.fillRect(0, 270, 90, 544, Color.new(18, 34, 54, Alpha))

	-- Cover and primary actions retain their established touch areas.
	DrawDetailsManga(140, 250 + shift, selectedManga, 300 / MANGA_HEIGHT)
	UI.roundCorners(40, 240, 100 + shift, 400 + shift, 12, Color.new(18, 34, 54, Alpha))
	UI.roundBorder(40, 240, 100 + shift, 400 + shift, 12, 1, Color.new(119, 158, 192, 100 * M))
	local following = Database.check(selectedManga)
	local label = Language[Settings.Language].DETAILS[following and "REMOVE_FROM_LIBRARY" or "ADD_TO_LIBRARY"]
	local libraryColor = following and Color.new(113, 47, 65, Alpha) or Color.new(29, 78, 126, Alpha)
	UI.fillRoundRect(20, 260, 416 + shift, 475 + shift, 12, libraryColor)
	Graphics.drawImage(30, 437 + shift, ButtonsIcons.Triangle.e, textColor)
	label = FitText(FONT20, label, 186)
	Font.print(FONT20, 153 - Font.getTextWidth(FONT20, label) / 2, 445 + shift - Font.getTextHeight(FONT20, label) / 2, label, textColor)
	local listCount = #chaptersList
	if continueChapterNumber and listCount > 0 then
		UI.fillRoundRect(20, 260, 480 + shift, 539 + shift, 12, Color.new(19, 101, 120, Alpha))
		Graphics.drawImage(30, 501 + shift, ButtonsIcons.Select.e, textColor)
		local resume = continueChapterNumber > 0 and chaptersList[continueChapterNumber] and (continueChapterNumber ~= 1 or Cache.getBookmark(chaptersList[1]))
		local buttonText = Language[Settings.Language].DETAILS[resume and "CONTINUE" or "START"]
		buttonText = FitText(FONT20, buttonText, 186)
		Font.print(FONT20, 153 - Font.getTextWidth(FONT20, buttonText) / 2, shift + (resume and 486 or 499), buttonText, textColor)
		if resume then
			local chapterName = FitText(FONT16, chaptersList[continueChapterNumber].Name or "", 186)
			Font.print(FONT16, 153 - Font.getTextWidth(FONT16, chapterName) / 2, 514 + shift, chapterName, secondTextColor)
		end
	end

	local start = math.max(1, math.floor(slider.Y / 80) + 1)
	local selected = detailsSelector:getSelected()
	for n = start, math.min(listCount, start + 8) do
		local y = shift - slider.Y + n * 80 + chaptersMaxHeightOffset
		if y > 544 then break end
		if y + 80 > 95 + chaptersMaxHeightOffset then
			local i = Settings.ChapterSorting ~= "N->1" and n or listCount - n + 1
			local chapter = chaptersList[i]
			local bookmark = Cache.getBookmark(chapter)
			local active = selected == n or slider.ItemID == i
			UI.fillRoundRect(278, 945, y + 3, y + 77, 10, active and Color.new(30, 61, 92, Alpha) or Color.new(22, 39, 59, Alpha))
			UI.roundBorder(278, 945, y + 3, y + 77, 10, 1, Color.new(103, 137, 170, 65 * M))
			local name = FitText(BONT16, chapter.Name or ("Chapter " .. i), selectedManga.ParserID == "IMPORTED" and 620 or 550)
			local titleColor = bookmark == true and secondTextColor or textColor
			Font.print(BONT16, 294, y + (bookmark ~= nil and 16 or 29), name, titleColor)
			if bookmark ~= nil then
				local progress = bookmark == true and Language[Settings.Language].DETAILS.DONE or Language[Settings.Language].DETAILS.PAGE .. tostring(bookmark)
				Font.print(FONT16, 294, y + 44, FitText(FONT16, progress, 550), secondTextColor)
			end
			if selectedManga.ParserID ~= "IMPORTED" then
				Graphics.fillRect(865, 866, y + 17, y + 63, Color.new(103, 137, 170, 45 * M))
				if ChapterSaver.check(chapter) then
					Graphics.drawImage(890, y + 28, crossIcon.e, secondTextColor)
				else
					local download = ChapterSaver.is_downloading(chapter)
					if download then
						local progress = download.page_count and download.page_count > 0 and math.min(100, math.ceil(100 * (download.page or 0) / download.page_count)) or 0
						local percent = tostring(progress) .. "%"
						Font.print(FONT20, 902 - Font.getTextWidth(FONT20, percent) / 2, y + 27, percent, accentColor)
					else
						Graphics.drawImage(890, y + 28, DownloadIcon.e, accentColor)
					end
				end
			end
			if selected == n then UI.focusBorder(278, 945, y + 3, y + 77, 10, M) end
		end
	end
	if listCount == 0 and not ParserManager.check(chaptersList) then
		local message = FitText(FONT20, Language[Settings.Language].WARNINGS.NO_CHAPTERS, 620)
		Font.print(FONT20, 608 - Font.getTextWidth(FONT20, message) / 2, 300 + shift, message, secondTextColor)
	end
		if #descriptionWordList > 0 and chaptersMaxHeightOffset > 0 then
			local descriptionLinesCount = is_description_expanded and #descriptionWordList or math.min(2, #descriptionWordList)
			if descriptionLinesCount ~= #descriptionWordList or descriptionLinesCount > 2 then
				Graphics.fillRect(260, 955, 95, 95 + chaptersMaxHeightOffset - LINE_HEIGHT - 10, backgroundColor)
			else
				Graphics.fillRect(260, 955, 95, 95 + chaptersMaxHeightOffset, backgroundColor)
			end
			local descriptionYOffset = 95 - descriptionMaxHeightOffset
			Font.print(BONT16, (270 + 940) / 2 - Font.getTextWidth(BONT16, Language[Settings.Language].DETAILS.SUMMARY) / 2, descriptionYOffset, Language[Settings.Language].DETAILS.SUMMARY, textColor)
			descriptionYOffset = descriptionYOffset + LINE_HEIGHT
			for i = 1, #descriptionWordList do
				if descriptionYOffset + LINE_HEIGHT >= 95 then
					local line = descriptionWordList[i]
					local x = 270
					for j = 1, #line do
						Font.print(FONT16, x, descriptionYOffset, line[j].Word, textColor)
						x = x + line.SpaceWidth + line[j].Width
					end
				end
				descriptionYOffset = descriptionYOffset + LINE_HEIGHT
				if descriptionLinesCount ~= #descriptionWordList or descriptionLinesCount > 2 then
					if descriptionYOffset >= 95 + chaptersMaxHeightOffset - LINE_HEIGHT - 10 then
						break
					end
				end
			end
			if descriptionLinesCount ~= #descriptionWordList or descriptionLinesCount > 2 then
				Graphics.fillRect(260, 955, 95 + chaptersMaxHeightOffset - LINE_HEIGHT - 10, 95 + chaptersMaxHeightOffset, backgroundColor)
				if descriptionLinesCount ~= #descriptionWordList then
					Font.print(BONT16, (270 + 940) / 2 - (Font.getTextWidth(BONT16, Language[Settings.Language].DETAILS.EXPAND) + 32) / 2, 95 + chaptersMaxHeightOffset - LINE_HEIGHT - 10, Language[Settings.Language].DETAILS.EXPAND, textColor)
					Graphics.drawImage(math.ceil((270 + 940) / 2 + Font.getTextWidth(BONT16, Language[Settings.Language].DETAILS.EXPAND) / 2 + 4), 95 + chaptersMaxHeightOffset - LINE_HEIGHT - 10, ButtonsIcons.L.e, textColor)
				elseif descriptionLinesCount > 2 then
					Font.print(BONT16, (270 + 940) / 2 - (Font.getTextWidth(BONT16, Language[Settings.Language].DETAILS.SHRINK) + 32) / 2, 95 + chaptersMaxHeightOffset - LINE_HEIGHT - 10, Language[Settings.Language].DETAILS.SHRINK, textColor)
					Graphics.drawImage(math.ceil((270 + 940) / 2 + Font.getTextWidth(BONT16, Language[Settings.Language].DETAILS.SHRINK) / 2 + 4), 95 + chaptersMaxHeightOffset - LINE_HEIGHT - 10, ButtonsIcons.L.e, textColor)
				end
			end
		end
	if chaptersMaxHeightOffset > 24 then
		UI.roundBorder(270, 948, 95, 95 + chaptersMaxHeightOffset, 10, 1, Color.new(103, 137, 170, 55 * M))
	end
	-- The fixed header masks chapter rows and summary text while they scroll.
	Graphics.fillRect(0, 960, 0, 90, Color.new(20, 43, 70, Alpha))
	Graphics.fillRect(0, 960, 89, 90, Color.new(132, 188, 235, 45 * M))
	UI.fillRoundRect(16, 72, 17, 73, 12, Color.new(255, 255, 255, 12 * M))
	Graphics.drawImage(32, 33, BackIcon.e, textColor)
	local titleRight = isVitaServerManga() and 682 or 770
	Font.print(BONT30, 94, 13 + shift, FitText(BONT30, selectedManga.Name, titleRight - 94), textColor)
	local subtitle = selectedManga.RawLink or ""
	if subtitle == "" then subtitle = tostring(listCount) .. " chapters" end
	Font.print(FONT16, 94, 56 + shift, FitText(FONT16, subtitle, titleRight - 94), secondTextColor)
	if isVitaServerManga() then
		UI.fillRoundRect(706, 774, 17, 73, 12, Color.new(119, 48, 65, Alpha))
		local label = (deleteArmed and Timer.getTime(deleteTimer) < 3000) and "Sure?" or "Delete"
		Font.print(BONT16, 740 - Font.getTextWidth(BONT16, label) / 2, 35, label, textColor)
	end
	UI.fillRoundRect(794, 862, 17, 73, 12, Color.new(255, 255, 255, 12 * M))
	if sortIcons[Settings.ChapterSorting] then
		Graphics.drawImage(816, 33, sortIcons[Settings.ChapterSorting].e, textColor)
		Graphics.drawImage(799, 20, ButtonsIcons.R.e, secondTextColor)
	end
	if is_chapter_list_ready then
		UI.fillRoundRect(882, 950, 17, 73, 12, Color.new(255, 255, 255, 12 * M))
		Graphics.drawImage(904, 33, menuIcon.e, textColor)
		Graphics.drawImage(887, 20, ButtonsIcons.Start.e, secondTextColor)
	end
	Graphics.fillRect(952, 960, 90, 544, backgroundColor)
	local viewport = 449 - chaptersMaxHeightOffset
	local content = listCount * 80
	if viewport > 0 and content > viewport then
		local thumb = math.max(28, viewport * viewport / content)
		thumb = math.min(viewport, thumb)
		local top = 95 + chaptersMaxHeightOffset + (viewport - thumb) * math.max(0, math.min(1, (slider.Y + 15) / (content - viewport)))
		UI.roundRect(955, 959, top, top + thumb, secondTextColor)
	end
end

---@return '"START"' | '"WAIT"' | '"END"'
---Gives status of Details menu
function Details.getStatus()
	return status
end

---@return number
---Gives fade
function Details.getFade()
	return fade * oldFade
end

---@return table
---Gives `seletctedManga` loaded in Details menu
function Details.getManga()
	return selectedManga
end
