CatalogModes = {}
local status = "END"

local fade = 0
local fadeFrom = 0

local animationTimer = Timer.new()

local modes = {}
local Name = ""

local currentFilters = {}
local currentChecked = {}
local currentLetters = {}
local currentLettersIndex = 1
local currentFinalLetter = 1
local currentTags = {}
local currentTagsIndex = 1
local currentFinalTag = 1
local currentFinalTagsData = {}

local itemsToDraw = {}

local nowMode = 1
local TOUCH_MODES = TOUCH_MODES
local slider = CreateSlider()
local selectedIndex = 0
local controlTimer = Timer.new()
local controlInterval = 400
local searchData = ""
local PANEL_WIDTH, CONTENT_TOP, CONTENT_BOTTOM, ROW_HEIGHT = 380, 88, 504, 50

local function setFinalTags()
	local filter = {}
	for j = 1, #currentFilters do
		local f = currentFilters[j]
		if f.Type == "check" then
			local list = {}
			for i = 1, #currentChecked[j] do
				if currentChecked[j][i] then
					list[#list + 1] = f.Tags[i]
				end
			end
			filter[#filter + 1] = list
			filter[f.Name] = list
		elseif f.Type == "checkcross" then
			local include = {}
			for i = 1, #currentChecked[j] do
				if currentChecked[j][i] == true then
					include[#include + 1] = f.Tags[i]
				end
			end
			local exclude = {}
			for i = 1, #currentChecked[j] do
				if currentChecked[j][i] == "cross" then
					exclude[#exclude + 1] = f.Tags[i]
				end
			end
			filter[#filter + 1] = {
				include = include,
				exclude = exclude
			}
			filter[f.Name] = filter[#filter]
		elseif f.Type == "radio" then
			filter[#filter + 1] = f.Tags[currentChecked[j]] or ""
			filter[f.Name] = f.Tags[currentChecked[j]] or ""
		end
	end
	currentFinalTagsData = filter
end

local function updateItemsDraw()
	itemsToDraw = {}
	for k = 1, #currentFilters do
		local f = currentFilters[k]
		itemsToDraw[#itemsToDraw + 1] = {
			data = f,
			type = "filter"
		}
		if f.visible then
			for i = 1, #f.Tags do
				itemsToDraw[#itemsToDraw + 1] = {
					data = f.Tags[i],
					type = "tag",
					k = k,
					i = i,
					f = f
				}
			end
		end
	end
end

---Updates scrolling movement
local function scrollLimit()
	return math.max(0, (#modes + #itemsToDraw) * ROW_HEIGHT - (CONTENT_BOTTOM - CONTENT_TOP))
end

local function scrollUpdate()
	local decay = math.pow(1 / 1.12, UI.dt / (1000 / 60))
	slider.Y = slider.Y + slider.V * (1 - decay) / (1 - 1 / 1.12)
	slider.V = math.abs(slider.V) < 0.1 and 0 or slider.V * decay
	slider.Y = math.max(0, math.min(scrollLimit(), slider.Y))
	if slider.Y == 0 or slider.Y == scrollLimit() then slider.V = 0 end
end

local function animationUpdate()
	if status == "START" then
		fade = UI.transition(fadeFrom, 1, animationTimer, UI.motion.enter)
	elseif status == "WAIT" then
		fade = UI.transition(fadeFrom, 0, animationTimer, UI.motion.exit)
		if fade == 0 then status = "END" end
	end
end

function CatalogModes.load(parser)
	if parser and parser.ID and parser.ID ~= "IMPORTED" then
		modes = {}
		Name = parser.Name
		currentFinalLetter = 1
		currentFinalTagsData = {}
		if parser.getPopularManga then
			modes[#modes + 1] = "Popular"
		end
		if parser.getLatestManga then
			modes[#modes + 1] = "Latest"
		end
		if parser.getAZManga then
			modes[#modes + 1] = "Alphabet"
		end
		if parser.getLetterManga and type(parser.Letters) == "table" then
			modes[#modes + 1] = "ByLetter"
			currentLetters = parser.Letters
			currentLettersIndex = 1
		end
		if parser.getTagManga and type(parser.Tags) == "table" then
			modes[#modes + 1] = "ByTag"
			currentTags = parser.Tags
			currentTagsIndex = 1
		end
		if parser.searchManga then
			modes[#modes + 1] = "Search"
		end
		currentFilters = parser.Filters or {}
		currentChecked = {}
		for k = 1, #currentFilters do
			local f = currentFilters[k]
			f.visible = false
			local default = f.Default
			if f.Type == "check" or f.Type == "checkcross" then
				currentChecked[k] = {}
				for i = 1, #f.Tags do
					currentChecked[k][i] = false
				end
				if default then
					if f.Type == "checkcross" then
						for i = 1, #default.include do
							for e = 1, #f.Tags do
								if f.Tags[e] == default.include[i] then
									currentChecked[k][e] = true
								end
							end
						end
						for i = 1, #default.exclude do
							for e = 1, #f.Tags do
								if f.Tags[e] == default.exclude[i] then
									currentChecked[k][e] = "cross"
								end
							end
						end
					elseif f.Type == "check" then
						for i = 1, #default do
							for e = 1, #f.Tags do
								if f.Tags[e] == default[i] then
									currentChecked[k][e] = true
								end
							end
						end
					end
				end
			elseif f.Type == "radio" then
				currentChecked[k] = 1
				if default then
					for e = 1, #f.Tags do
						if f.Tags[e] == default then
							currentChecked[k] = e
						end
					end
				end
			end
		end
		nowMode = 1
		searchData = ""
		slider.Y, slider.V = 0, 0
		updateItemsDraw()
	end
end

---Switches to mode `modeName` (e.g. "Latest") right after `CatalogModes.load` and optionally renames the title
function CatalogModes.selectMode(modeName, title)
	for i = 1, #modes do
		if modes[i] == modeName then
			nowMode = i
		end
	end
	if title then
		Name = title
	end
end

function CatalogModes.show()
	status = "START"
	fadeFrom = fade
	Timer.reset(animationTimer)
	selectedIndex = math.max(1, nowMode)
	slider.V = 0
	TOUCH_MODES.MODE = TOUCH_MODES.NONE
end

local function setMode(id)
	if nowMode ~= id or modes[id] == "Search" or modes[id] == "ByLetter" or modes[id] == "ByTag" then
		if modes[id] == "Search" then
			Keyboard.show(Language[Settings.Language].APP.SEARCH, searchData, 128, TYPE_DEFAULT, MODE_TEXT, OPT_NO_AUTOCAP)
			setFinalTags()
		else
			nowMode = id
			currentFinalLetter = currentLettersIndex
			currentFinalTag = currentTagsIndex
			status = "WAIT"
			fadeFrom = fade
			Timer.reset(animationTimer)
			Catalogs.terminate()
		end
	end
end

local function close()
	status = "WAIT"
	fadeFrom = fade
	Timer.reset(animationTimer)
end

local function activate(index)
	if index < 1 then return end
	if index <= #modes then
		setFinalTags()
		if index == nowMode and modes[index] ~= "Search" and modes[index] ~= "ByLetter" and modes[index] ~= "ByTag" then close()
		else setMode(index) end
		return
	end
	local entry = itemsToDraw[index - #modes]
	if not entry then return end
	if entry.type == "filter" then
		entry.data.visible = not entry.data.visible
		updateItemsDraw()
	elseif entry.f.Type == "radio" then
		currentChecked[entry.k] = entry.i
	elseif entry.f.Type == "check" then
		currentChecked[entry.k][entry.i] = not currentChecked[entry.k][entry.i]
	elseif entry.f.Type == "checkcross" then
		local value = currentChecked[entry.k][entry.i]
		currentChecked[entry.k][entry.i] = value == false and true or value == true and "cross" or false
	end
	setFinalTags()
	selectedIndex = math.min(selectedIndex, #modes + #itemsToDraw)
end

local function stepChoice(direction)
	if modes[selectedIndex] == "ByLetter" and #currentLetters > 0 then
		currentLettersIndex = (currentLettersIndex - 1 + direction) % #currentLetters + 1
	elseif modes[selectedIndex] == "ByTag" and #currentTags > 0 then
		currentTagsIndex = (currentTagsIndex - 1 + direction) % #currentTags + 1
	end
end

local function rowAt(y)
	return math.floor((slider.Y + y - CONTENT_TOP) / ROW_HEIGHT) + 1
end

function CatalogModes.input(pad, oldpad, touch, oldtouch)
	if status ~= "START" then return end
	local function pressed(key) return Controls.check(pad, key) and not Controls.check(oldpad, key) end
	if pressed(SCE_CTRL_CIRCLE) or pressed(SCE_CTRL_SQUARE) then close(); return end
	local left = 960 - PANEL_WIDTH * fade
	if touch.x and not oldtouch.x then
		if touch.x < left or (touch.x >= 912 and touch.y >= 14 and touch.y < 50) or (touch.y >= CONTENT_BOTTOM and touch.x > left + PANEL_WIDTH / 2) then close(); return end
		if touch.y >= CONTENT_TOP and touch.y < CONTENT_BOTTOM then
			TOUCH_MODES.MODE = math.abs(slider.V) > 0.1 and TOUCH_MODES.SLIDE or TOUCH_MODES.READ
			slider.TouchY, slider.V = touch.y, 0
			selectedIndex = 0
		end
	elseif touch.x and oldtouch.x and TOUCH_MODES.MODE ~= TOUCH_MODES.NONE then
		if math.abs(touch.y - slider.TouchY) > 8 then TOUCH_MODES.MODE = TOUCH_MODES.SLIDE end
		if TOUCH_MODES.MODE == TOUCH_MODES.SLIDE then slider.V = (oldtouch.y - touch.y) * (1000 / 60) / UI.dt end
	elseif oldtouch.x and not touch.x then
		if TOUCH_MODES.MODE == TOUCH_MODES.READ and oldtouch.x >= left and oldtouch.y >= CONTENT_TOP and oldtouch.y < CONTENT_BOTTOM then
			local index = rowAt(oldtouch.y)
			if (modes[index] == "ByLetter" or modes[index] == "ByTag") and oldtouch.x > 850 then
				selectedIndex = index
				stepChoice(oldtouch.x > 900 and 1 or -1)
			else activate(index) end
		elseif oldtouch.y >= CONTENT_BOTTOM and oldtouch.x >= left and oldtouch.x <= left + PANEL_WIDTH / 2 then
			activate(selectedIndex)
		end
		TOUCH_MODES.MODE = TOUCH_MODES.NONE
	end
	slider.ItemID = TOUCH_MODES.MODE == TOUCH_MODES.READ and touch.y and rowAt(touch.y) or 0
	if touch.x then return end
	if pressed(SCE_CTRL_CROSS) then activate(selectedIndex); return end
	local directions = SCE_CTRL_UP + SCE_CTRL_DOWN + SCE_CTRL_LEFT + SCE_CTRL_RIGHT
	local fresh = pressed(SCE_CTRL_UP) or pressed(SCE_CTRL_DOWN) or pressed(SCE_CTRL_LEFT) or pressed(SCE_CTRL_RIGHT)
	if not Controls.check(pad, directions) then controlInterval = 400; return end
	if fresh or Timer.getTime(controlTimer) >= controlInterval then
		if selectedIndex == 0 then selectedIndex = math.max(1, rowAt(CONTENT_TOP))
		elseif Controls.check(pad, SCE_CTRL_DOWN) then selectedIndex = math.min(#modes + #itemsToDraw, selectedIndex + 1)
		elseif Controls.check(pad, SCE_CTRL_UP) then selectedIndex = math.max(1, selectedIndex - 1)
		elseif Controls.check(pad, SCE_CTRL_LEFT) then stepChoice(-1)
		elseif Controls.check(pad, SCE_CTRL_RIGHT) then stepChoice(1) end
		slider.V = 0
		controlInterval = fresh and 400 or math.max(60, controlInterval / 2)
		Timer.reset(controlTimer)
	end
end

function CatalogModes.update()
	if status ~= "END" then
		if selectedIndex > 0 then
			local top = (selectedIndex - 1) * ROW_HEIGHT
			local target = top < slider.Y and top or top + ROW_HEIGHT > slider.Y + CONTENT_BOTTOM - CONTENT_TOP and top + ROW_HEIGHT - CONTENT_BOTTOM + CONTENT_TOP or slider.Y
			slider.Y = UI.approach(slider.Y, target, 65)
		end
		animationUpdate()
		scrollUpdate()
		if Keyboard.getState() ~= RUNNING then
			if Keyboard.getState() == FINISHED then
				local data = Keyboard.getInput()
				Console.write('Searching for "' .. data .. '"')
				Catalogs.terminate()
				for i = 1, #modes do
					if modes[i] == "Search" then
						nowMode = i
						break
					end
				end
				searchData = data
				status = "WAIT"
				fadeFrom = fade
				Timer.reset(animationTimer)
				if data:gsub("%s", "") ~= "" then
					Notifications.push(string.format(Language[Settings.Language].NOTIFICATIONS.SEARCHING, data))
				end
			end
			Keyboard.clear()
		end
	end
end

function CatalogModes.draw()
	if status == "END" then return end
	local M = fade
	local left = 960 - PANEL_WIDTH * M
	local right = left + PANEL_WIDTH
	Graphics.fillRect(0, 960, 0, 544, UI.color("OVERLAY", 0.55 * M))
	UI.fillRoundRect(left, right + 16, 0, 544, 16, UI.color("SURFACE", M))
	local first = math.max(1, math.floor(slider.Y / ROW_HEIGHT) + 1)
	local icons = { Popular = HotIcon, Latest = HistoryIcon, Search = SearchIcon, Alphabet = AZIcon, ByLetter = LetterAIcon, ByTag = TagIcon }
	for index = first, math.min(#modes + #itemsToDraw, first + 9) do
		local y = CONTENT_TOP + (index - 1) * ROW_HEIGHT - slider.Y
		if y >= CONTENT_BOTTOM then break end
		local active = index == selectedIndex or index == slider.ItemID
		UI.fillRoundRect(left + 12, right - 12, y + 4, y + 46, 9, UI.color(active and "SELECTED" or "BACK", M))
		local text, icon, value, color = "", nil, nil, UI.color("FONT", M)
		local indent = 0
		if index <= #modes then
			local key = modes[index]
			text = Language[Settings.Language].MODES[key] or key
			icon = icons[key]
			if key == "Search" and searchData ~= "" then text = text .. ": " .. searchData end
			if key == "ByLetter" then value = "‹ " .. tostring(currentLetters[currentLettersIndex]) .. " ›" end
			if key == "ByTag" then value = "‹ " .. tostring(currentTags[currentTagsIndex]) .. " ›" end
			if index == nowMode and not value then value = "•" end
		else
			local entry = itemsToDraw[index - #modes]
			if entry.type == "filter" then
				text = entry.data.Name
				icon = entry.data.visible and HideIcon or ShowIcon
			else
				text, indent = entry.data, 12
				local checked = entry.f.Type == "radio" and currentChecked[entry.k] == entry.i or entry.f.Type ~= "radio" and currentChecked[entry.k][entry.i]
				if entry.f.Type == "radio" then icon = checked and RadioCheckedIcon or RadioIcon
				elseif checked == "cross" then icon, color = CheckboxCrossedIcon, UI.color("DANGER", M)
				else icon = checked and CheckboxCheckedIcon or CheckboxIcon end
			end
		end
		if icon then Graphics.drawImage(left + 24 + indent, y + 13, icon.e, color) end
		text = UI.capitalize(text)
		local available = PANEL_WIDTH - 88 - indent - (value and 76 or 0)
		Font.print(FONT16, left + 60 + indent, y + (ROW_HEIGHT - Font.getTextHeight(FONT16, text)) / 2, FitText(FONT16, text, available), color)
		if value then
			value = FitText(FONT16, value, 80)
			Font.print(FONT16, right - 28 - Font.getTextWidth(FONT16, value), y + 16, value, UI.color("SELECTOR", M))
		end
		if index == selectedIndex then UI.focusBorder(left + 12, right - 12, y + 4, y + 46, 9, M) end
	end
	-- Fixed header and footer mask scrolling rows.
	Graphics.fillRect(left, right, 0, CONTENT_TOP, UI.color("SURFACE", M))
	local title = UI.capitalize((Language[Settings.Language].PANEL or {}).FILTERS or "filters")
	Font.print(FONT26, left + 20, 16, title, UI.color("FONT", M))
	Font.print(FONT16, left + 20, 54, FitText(FONT16, UI.capitalize(Name), PANEL_WIDTH - 40), UI.color("SUBFONT", M))
	UI.fillRoundRect(right - 48, right - 12, 14, 50, 8, UI.color("SELECTED", M))
	Graphics.drawImage(right - 38, 24, ButtonsIcons.Square.e, Color.new(255, 255, 255, 255 * M))
	Graphics.fillRect(left + 20, right - 20, CONTENT_TOP - 1, CONTENT_TOP, UI.color("BORDER", M))
	Graphics.fillRect(left, right, CONTENT_BOTTOM, 544, UI.color("SURFACE", M))
	Graphics.fillRect(left + 20, right - 20, CONTENT_BOTTOM, CONTENT_BOTTOM + 1, UI.color("BORDER", M))
	local confirm = Settings.KeyType == "JP" and ButtonsIcons.Circle or ButtonsIcons.Cross
	Graphics.drawImage(left + 20, 518, confirm.e, Color.new(255, 255, 255, 255 * M))
	Font.print(FONT16, left + 44, 516, UI.capitalize((Language[Settings.Language].PANEL or {}).SELECT or "select"), UI.color("SUBFONT", M))
	Graphics.drawImage(right - 90, 518, ButtonsIcons.Square.e, Color.new(255, 255, 255, 255 * M))
	Font.print(FONT16, right - 66, 516, "close", UI.color("SUBFONT", M))
	local limit = scrollLimit()
	if limit > 0 then
		local viewport = CONTENT_BOTTOM - CONTENT_TOP
		local thumb = math.max(24, viewport * viewport / (limit + viewport))
		local y = CONTENT_TOP + (viewport - thumb) * math.min(1, slider.Y / limit)
		UI.roundRect(right - 6, right - 2, y, y + thumb, UI.color("SUBFONT", M))
	end
end

function CatalogModes.getStatus()
	return status
end

function CatalogModes.getFade()
	return fade
end

function CatalogModes.getMangaMode()
	return modes[nowMode]
end

function CatalogModes.getSearchData()
	return searchData
end

function CatalogModes.getTagsData()
	return currentFinalTagsData
end

function CatalogModes.getLetter()
	return currentLetters[currentFinalLetter] or ""
end

function CatalogModes.getTag()
	return currentTags[currentFinalTag] or ""
end
