Details = {}

local status = "END"
local selectedManga = nil

local slider = CreateSlider()
local deleteFile = System.deleteFile
local doesFileExist = System.doesFileExist

local descriptionString = nil
local descriptionWordList = {}

local TOUCH_MODES = TOUCH_MODES
local HEADER_HEIGHT, CONTENT_TOP = 64, 76
local POSTER_LEFT, POSTER_RIGHT = 30, 250
local SUMMARY_LEFT, DESCRIPTION_WIDTH = 294, 635
local LINE_HEIGHT = 22

local chaptersMaxHeightOffset = 0
local descriptionMaxHeightOffset = 0
local summaryTouch, summaryDragged = false, false
local summaryTouchY = 0

local function summaryScrollLimit()
	local viewport = math.max(0, chaptersMaxHeightOffset - 84)
	local last = descriptionWordList[#descriptionWordList]
	local height = last and ((#descriptionWordList - 1) * LINE_HEIGHT + Font.getTextHeight(FONT16, last)) or 0
	return math.max(0, height - viewport)
end

local function chapterY(index)
	return index * 80 + CONTENT_TOP - 95 - slider.Y + chaptersMaxHeightOffset
end

local function chapterAt(y)
	return math.floor((slider.Y + y - CONTENT_TOP + 95 - chaptersMaxHeightOffset) / 80)
end

local fade = 0
local fadeFrom = 0

local crossIcon = Image:new(Graphics.loadImage("app0:assets/icons/cross.png"))
local menuIcon = Image:new(Graphics.loadImage("app0:assets/icons/menu.png"))
local sortIcons = {
	["N->1"] = Image:new(Graphics.loadImage("app0:assets/icons/sort-9-1.png")),
	["1->N"] = Image:new(Graphics.loadImage("app0:assets/icons/sort-1-9.png"))
}

local fadeTimer = Timer.new()

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
		local target = selectedItem * 80 - 289 + chaptersMaxHeightOffset / 2
		slider.Y = UI.approach(slider.Y, math.max(-15, math.min(target, #chaptersList * 80 - 483 + chaptersMaxHeightOffset)), 90)
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
	elseif slider.Y > (#chaptersList * 80 - 483 + chaptersMaxHeightOffset) then
		slider.Y = math.max(-15, #chaptersList * 80 - 483 + chaptersMaxHeightOffset)
		slider.V = 0
	end
end

---Updates animation of fade in or out
local function updateAnimations()
	if status == "START" then
		fade = UI.transition(fadeFrom, 1, fadeTimer, UI.motion.enter)
	elseif status == "WAIT" then
		fade = UI.transition(fadeFrom, 0, fadeTimer, UI.motion.exit)
		if fade == 0 then status = "END" end
	end

	if ParserManager.check(chaptersList) then
		Loading.setStatus("WHITE", 580, 250)
	else
		Loading.setStatus("NONE")
	end
end

---Updates `chaptersMaxHeightOffset` depending on if description is expanded
local function updateMangaDescriptionMaxHeight()
	if #descriptionWordList == 0 then chaptersMaxHeightOffset = 0; return end
	local lines = is_description_expanded and #descriptionWordList or math.min(2, #descriptionWordList)
	local toggle = #descriptionWordList > 2
	local target = math.min(448, lines * LINE_HEIGHT + (toggle and 84 or 52))
	chaptersMaxHeightOffset = UI.approach(chaptersMaxHeightOffset, target, 65)
	if not is_description_expanded then
		descriptionMaxHeightOffset = UI.approach(descriptionMaxHeightOffset, 0, 65)
	else
		descriptionMaxHeightOffset = math.min(descriptionMaxHeightOffset, summaryScrollLimit())
	end
end

-- Wrap once when the summary arrives; keep a natural, left-aligned word spacing.
local function updateMangaDescription(newDescription)
	descriptionString = (newDescription or ""):gsub("\r", ""):gsub("^%s+", ""):gsub("%s+$", "")
	local lines, line = {}, ""
	local function append(word)
		local candidate = line == "" and word or line .. " " .. word
		if Font.getTextWidth(FONT16, candidate) <= DESCRIPTION_WIDTH then line = candidate; return end
		if line ~= "" then lines[#lines + 1], line = line, "" end
		if Font.getTextWidth(FONT16, word) <= DESCRIPTION_WIDTH then line = word; return end
		-- Long words and CJK paragraphs wrap at complete UTF-8 characters.
		for char in it_utf8(word) do
			if line ~= "" and Font.getTextWidth(FONT16, line .. char) > DESCRIPTION_WIDTH then
				lines[#lines + 1], line = line, ""
			end
			line = line .. char
		end
	end
	for paragraph in (descriptionString .. "\n"):gmatch("(.-)\n") do
		for word in paragraph:gmatch("%S+") do append(word) end
		if line ~= "" then lines[#lines + 1], line = line, "" end
	end
	descriptionWordList = lines
	LINE_HEIGHT = 22
	for _, text in ipairs(lines) do LINE_HEIGHT = math.max(LINE_HEIGHT, Font.getTextHeight(FONT16, text) + 4) end
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
			local chapter = continueChapterNumber > 0 and continueChapterNumber or 1
			detailsSelector:setSelected(Settings.ChapterSorting == "N->1" and #chaptersList - chapter + 1 or chapter)
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
		slider.Y = -50
		slider.V = 0
		chaptersMaxHeightOffset = 0
		TOUCH_MODES.MODE = TOUCH_MODES.NONE


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
		summaryTouch, summaryDragged = false, false

		fadeFrom = fade
		Timer.reset(fadeTimer)
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
		-- The expanded summary owns drags within its body; chapter scrolling stays separate.
		if is_description_expanded and touch.x and not oldTouch.x and touch.x >= 278 and touch.x <= 945
			and touch.y >= CONTENT_TOP + 38 and touch.y < CONTENT_TOP + chaptersMaxHeightOffset - 46 then
			summaryTouch, summaryDragged, summaryTouchY = true, false, touch.y
			slider.V, slider.ItemID = 0, 0
			TOUCH_MODES.MODE = TOUCH_MODES.NONE
		end
		if summaryTouch then
			if touch.x and oldTouch.x then
				if math.abs(touch.y - summaryTouchY) > 8 then summaryDragged = true end
				if summaryDragged then
					descriptionMaxHeightOffset = math.max(0, math.min(summaryScrollLimit(), descriptionMaxHeightOffset + oldTouch.y - touch.y))
				end
			elseif not touch.x then
				if not summaryDragged then is_description_expanded = false end
				summaryTouch = false
			end
			return
		end
		local oldTouchMode = TOUCH_MODES.MODE
		if TOUCH_MODES.MODE == TOUCH_MODES.NONE and oldTouch.x and touch.x and touch.x > 240 then
			TOUCH_MODES.MODE = TOUCH_MODES.READ
			slider.TouchY = touch.y
		elseif TOUCH_MODES.MODE ~= TOUCH_MODES.NONE and not touch.x then
			if TOUCH_MODES.MODE == TOUCH_MODES.READ and oldTouch.x then
				if oldTouch.x > 270 and oldTouch.x < 955 and oldTouch.y > CONTENT_TOP + chaptersMaxHeightOffset then
					local id = chapterAt(oldTouch.y)
					if Settings.ChapterSorting == "N->1" then
						id = #chaptersList - id + 1
					end
					if oldTouch.x < 866 or selectedManga.ParserID == "IMPORTED" then
						readChapter(id)
					else
						downloadChapter(id)
					end
				elseif oldTouch.x > 270 and oldTouch.x < 960 and oldTouch.y >= CONTENT_TOP and oldTouch.y <= CONTENT_TOP + chaptersMaxHeightOffset then
					is_description_expanded = not is_description_expanded
				end
			end
			TOUCH_MODES.MODE = TOUCH_MODES.NONE
		end
		local is_description_scrollable = not (is_description_expanded and summaryScrollLimit() > 0)
		if is_description_scrollable then
			detailsSelector:input(#chaptersList, oldPad, pad, touch.x)
		else
			if Controls.check(pad, SCE_CTRL_UP) then
				descriptionMaxHeightOffset = math.max(descriptionMaxHeightOffset - UI.dt * 0.3, 0)
			elseif Controls.check(pad, SCE_CTRL_DOWN) then
				descriptionMaxHeightOffset = math.min(descriptionMaxHeightOffset + UI.dt * 0.3, summaryScrollLimit())
			end
		end
		if oldTouch.x and not touch.x then
			if oldTouch.x > POSTER_LEFT and oldTouch.x < POSTER_RIGHT and oldTouch.y > 480 and oldTouch.y < 528 then
				addToLibrary()
			elseif oldTouch.x > POSTER_LEFT and oldTouch.x < POSTER_RIGHT and oldTouch.y > 420 and oldTouch.y < 468 then
				if continueChapterNumber then
					readChapter(continueChapterNumber > 0 and continueChapterNumber or 1)
				end
			elseif oldTouch.x > 960 - 88 and oldTouch.y < HEADER_HEIGHT and is_chapter_list_ready and oldTouchMode == TOUCH_MODES.READ then
				Extra.setChapters(selectedManga, chaptersList)
			elseif isVitaServerManga() and oldTouch.x > 960 - 88 * 3 and oldTouch.x <= 960 - 88 * 2 and oldTouch.y < HEADER_HEIGHT and oldTouchMode == TOUCH_MODES.READ then
				if deleteArmed and Timer.getTime(deleteTimer) < 3000 then
					deleteArmed = false
					if vitaServerDelete(selectedManga) then
						status = "WAIT"
						Loading.setStatus("NONE")
						ParserManager.remove(chaptersList)
						fadeFrom = fade
						Timer.reset(fadeTimer)
					end
				else
					deleteArmed = true
					Timer.reset(deleteTimer)
					Notifications.push("Tap Delete again to remove this from the PC server")
				end
			elseif oldTouch.x > 960 - 88 - 88 and oldTouch.y < HEADER_HEIGHT and oldTouchMode == TOUCH_MODES.READ then
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
		elseif Controls.check(pad, SCE_CTRL_CIRCLE) and not Controls.check(oldPad, SCE_CTRL_CIRCLE) or (touch.x and not oldTouch.x and touch.x < 88 and touch.y < HEADER_HEIGHT) then
			status = "WAIT"
			Loading.setStatus("NONE")
			ParserManager.remove(chaptersList)
			fadeFrom = fade
			Timer.reset(fadeTimer)
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
				if oldTouch.x > 270 and oldTouch.x < 955 and oldTouch.y > CONTENT_TOP + chaptersMaxHeightOffset then
					local id = chapterAt(oldTouch.y)
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
	local M = fade
	local shift = (1 - M) * 24
	local backgroundColor = UI.color("BACK", M)
	local textColor = UI.color("FONT", M)
	local secondTextColor = UI.color("SUBFONT", M)
	local accentColor = UI.color("SELECTOR", M)
	Graphics.fillRect(0, 960, 0, 544, backgroundColor)
	-- Poster and primary CTA share these exact 220-pixel edges.
	UI.fillRoundRect(28, 252, 76 + shift, 410 + shift, 13, UI.color("SURFACE", M))
	DrawDetailsManga(140, 243 + shift, selectedManga, 330 / MANGA_HEIGHT)
	UI.roundCorners(POSTER_LEFT, POSTER_RIGHT, 78 + shift, 408 + shift, 12, UI.color("SURFACE", M))
	UI.roundBorder(POSTER_LEFT, POSTER_RIGHT, 78 + shift, 408 + shift, 12, 1, UI.color("BORDER", M))
	local following = Database.check(selectedManga)
	UI.fillRoundRect(POSTER_LEFT, POSTER_RIGHT, 480 + shift, 528 + shift, 10, UI.color("SURFACE", M))
	Graphics.drawImage(43, 492 + shift, StarIcon.e, following and accentColor or secondTextColor)
	Graphics.drawImage(224, 496 + shift, ButtonsIcons.Triangle.e, secondTextColor)
	local libraryLabel = Language[Settings.Language].DETAILS[following and "REMOVE_FROM_LIBRARY" or "ADD_TO_LIBRARY"]
	libraryLabel = FitText(FONT16, UI.capitalize(libraryLabel), 140)
	Font.print(FONT16, 75, 504 + shift - Font.getTextHeight(FONT16, libraryLabel) / 2, libraryLabel, textColor)
	local listCount = #chaptersList
	if continueChapterNumber and listCount > 0 then
		UI.fillRoundRect(POSTER_LEFT, POSTER_RIGHT, 420 + shift, 468 + shift, 10, UI.color("PRIMARY", M))
		UI.playIcon(43, 432 + shift, 24, UI.color("ON_PRIMARY", M))
		local hintX = POSTER_RIGHT - 12 - ButtonsIcons.Select.Width
		Graphics.drawImage(hintX, 444 + shift - ButtonsIcons.Select.Height / 2, ButtonsIcons.Select.e, UI.color("ON_PRIMARY", M))
		local index = continueChapterNumber > 0 and continueChapterNumber or 1
		local chapter = chaptersList[index]
		local bookmark = chapter and Cache.getBookmark(chapter)
		local resume = continueChapterNumber > 0 and (index ~= 1 or bookmark)
		local buttonText = Language[Settings.Language].DETAILS[resume and "CONTINUE" or "START"]
		buttonText = FitText(FONT16, UI.capitalize(buttonText), hintX - 87)
		Font.print(FONT16, 75, 444 + shift - Font.getTextHeight(FONT16, buttonText) / 2, buttonText, UI.color("ON_PRIMARY", M))
	end

	local start = math.max(1, math.floor(slider.Y / 80) + 1)
	local selected = detailsSelector:getSelected()
	for n = start, math.min(listCount, start + 8) do
		local y = shift + chapterY(n)
		if y > 544 then break end
		if y + 80 > CONTENT_TOP + chaptersMaxHeightOffset then
			local i = Settings.ChapterSorting ~= "N->1" and n or listCount - n + 1
			local chapter = chaptersList[i]
			local bookmark = Cache.getBookmark(chapter)
			local active = selected == n or slider.ItemID == i
			UI.fillRoundRect(278, 945, y + 3, y + 77, 10, UI.color(active and "SELECTED" or "SURFACE", M))
			UI.roundBorder(278, 945, y + 3, y + 77, 10, 1, UI.color("BORDER", M))
			local name = FitText(BONT16, chapter.Name or ("Chapter " .. i), selectedManga.ParserID == "IMPORTED" and 620 or 550)
			local titleColor = bookmark == true and secondTextColor or textColor
			Font.print(BONT16, 294, y + (bookmark ~= nil and 16 or 29), name, titleColor)
			if bookmark ~= nil then
				local progress = bookmark == true and Language[Settings.Language].DETAILS.DONE or Language[Settings.Language].DETAILS.PAGE .. tostring(bookmark)
				Font.print(FONT16, 294, y + 44, FitText(FONT16, progress, 550), secondTextColor)
			end
			if selectedManga.ParserID ~= "IMPORTED" then
				Graphics.fillRect(865, 866, y + 17, y + 63, UI.color("BORDER", 0.5 * M))
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
	if #descriptionWordList > 0 and chaptersMaxHeightOffset > 30 then
		local bottom = CONTENT_TOP + chaptersMaxHeightOffset - 10
		local toggle = #descriptionWordList > 2
		local bodyTop = CONTENT_TOP + 38
		local bodyBottom = bottom - (toggle and 36 or 12)
		-- Mask the chapter list behind the fixed summary panel.
		Graphics.fillRect(270, 952, CONTENT_TOP, bottom + 10, backgroundColor)
		UI.fillRoundRect(278, 945, CONTENT_TOP, bottom, 12, UI.color("SURFACE", M))
		UI.roundBorder(278, 945, CONTENT_TOP, bottom, 12, 1, UI.color("BORDER", M))
		Font.print(BONT16, SUMMARY_LEFT, CONTENT_TOP + 12, Language[Settings.Language].DETAILS.SUMMARY, textColor)
		local count = is_description_expanded and #descriptionWordList or math.min(2, #descriptionWordList)
		for i = 1, count do
			local y = bodyTop + (i - 1) * LINE_HEIGHT - descriptionMaxHeightOffset
			if y >= bodyTop - 0.01 and y + Font.getTextHeight(FONT16, descriptionWordList[i]) <= bodyBottom + 0.01 then
				Font.print(FONT16, SUMMARY_LEFT, y, descriptionWordList[i], secondTextColor)
			end
		end
		if is_description_expanded and bodyBottom > bodyTop and summaryScrollLimit() > 0 then
			local viewport = bodyBottom - bodyTop
			local thumb = math.min(viewport, math.max(24, viewport * viewport / (viewport + summaryScrollLimit())))
			local top = bodyTop + (viewport - thumb) * descriptionMaxHeightOffset / summaryScrollLimit()
			UI.roundRect(936, 940, top, top + thumb, secondTextColor)
		end
		if toggle then
			local label = Language[Settings.Language].DETAILS[is_description_expanded and "SHRINK" or "EXPAND"]
			local right = 929
			Font.print(BONT16, right - 34 - Font.getTextWidth(BONT16, label), bottom - 26, label, accentColor)
			Graphics.drawImage(right - 24, bottom - 26, ButtonsIcons.L.e, secondTextColor)
		end
	end
	-- The fixed header masks chapter rows and summary text while they scroll.
	Graphics.fillRect(0, 960, 0, HEADER_HEIGHT, UI.color("HEADER", M))
	Graphics.fillRect(0, 960, HEADER_HEIGHT - 1, HEADER_HEIGHT, UI.color("BORDER", M))
	UI.fillRoundRect(16, 72, 8, 56, 12, UI.color("SELECTED", M))
	Graphics.drawImage(32, 20, BackIcon.e, textColor)
	local titleRight = isVitaServerManga() and 682 or 770
	Font.print(BONT30, 94, 4 + shift, FitText(BONT30, UI.capitalize(selectedManga.Name), titleRight - 94), textColor)
	local parser = GetParserByID(selectedManga.ParserID)
	local sourceName = parser and parser.Name or (selectedManga.ParserID == "IMPORTED" and Language[Settings.Language].APP.IMPORT or selectedManga.ParserID or "")
	local subtitle = sourceName .. " · " .. tostring(listCount) .. " chapters"
	Font.print(FONT16, 94, 40 + shift, FitText(FONT16, subtitle, titleRight - 94), secondTextColor)
	if isVitaServerManga() then
		UI.fillRoundRect(706, 774, 8, 56, 12, UI.color("DANGER", M))
		local label = (deleteArmed and Timer.getTime(deleteTimer) < 3000) and "Sure?" or "Delete"
		Font.print(BONT16, 740 - Font.getTextWidth(BONT16, label) / 2, 24, label, UI.color("ON_DANGER", M))
	end
	UI.fillRoundRect(794, 862, 8, 56, 12, UI.color("SELECTED", M))
	if sortIcons[Settings.ChapterSorting] then
		Graphics.drawImage(816, 23, sortIcons[Settings.ChapterSorting].e, textColor)
		Graphics.drawImage(799, 10, ButtonsIcons.R.e, secondTextColor)
	end
	if is_chapter_list_ready then
		UI.fillRoundRect(882, 950, 8, 56, 12, UI.color("SELECTED", M))
		Graphics.drawImage(904, 23, menuIcon.e, textColor)
		Graphics.drawImage(887, 10, ButtonsIcons.Start.e, secondTextColor)
	end
	Graphics.fillRect(952, 960, HEADER_HEIGHT, 544, backgroundColor)
	local viewport = 544 - CONTENT_TOP - chaptersMaxHeightOffset
	local content = listCount * 80
	if viewport > 0 and content > viewport then
		local thumb = math.max(28, viewport * viewport / content)
		thumb = math.min(viewport, thumb)
		local top = CONTENT_TOP + chaptersMaxHeightOffset + (viewport - thumb) * math.max(0, math.min(1, (slider.Y + 15) / (content - viewport)))
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
	return fade
end

---@return table
---Gives `seletctedManga` loaded in Details menu
function Details.getManga()
	return selectedManga
end
