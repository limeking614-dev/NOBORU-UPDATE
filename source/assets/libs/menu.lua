Menu = {}

local logoSmall = Image:new(Graphics.loadImage("app0:assets/images/logo-small.png"))

StarIcon = Image:new(Graphics.loadImage("app0:assets/icons/star.png"))
MiniStarIcon = Image:new(Graphics.loadImage("app0:assets/icons/mini_star.png"))
local WebIcon = Image:new(Graphics.loadImage("app0:assets/icons/web.png"))
HistoryIcon = Image:new(Graphics.loadImage("app0:assets/icons/history.png"))
ImportIcon = Image:new(Graphics.loadImage("app0:assets/icons/import.png"))
HotIcon = Image:new(Graphics.loadImage("app0:assets/icons/hot.png"))
SearchIcon = Image:new(Graphics.loadImage("app0:assets/icons/search.png"))
AZIcon = Image:new(Graphics.loadImage("app0:assets/icons/az.png"))
LetterAIcon = Image:new(Graphics.loadImage("app0:assets/icons/a.png"))
TagIcon = Image:new(Graphics.loadImage("app0:assets/icons/tag.png"))
BackIcon = Image:new(Graphics.loadImage("app0:assets/icons/back.png"))
RefreshIcon = Image:new(Graphics.loadImage("app0:assets/icons/refresh.png"))

CheckboxIcon = Image:new(Graphics.loadImage("app0:assets/icons/checkbox.png"))
CheckboxCheckedIcon = Image:new(Graphics.loadImage("app0:assets/icons/checkbox_checked.png"))
CheckboxCrossedIcon = Image:new(Graphics.loadImage("app0:assets/icons/checkbox_crossed.png"))
RadioIcon = Image:new(Graphics.loadImage("app0:assets/icons/radio.png"))
RadioCheckedIcon = Image:new(Graphics.loadImage("app0:assets/icons/radio_checked.png"))
ShowIcon = Image:new(Graphics.loadImage("app0:assets/icons/show.png"))
HideIcon = Image:new(Graphics.loadImage("app0:assets/icons/hide.png"))

DownloadIcon = Image:new(Graphics.loadImage("app0:assets/icons/download.png"))
OptionsIcon = Image:new(Graphics.loadImage("app0:assets/icons/options.png"))

---@param mode string
---Menu mode
local mode
local downloadIndicatorValue = 0

local buttonsAlpha = {}
local selectionY = 91
local sections = {
	{ "LIBRARY", 91, StarIcon },
	{ "CATALOGS", 141, WebIcon },
	{ "HISTORY", 191, HistoryIcon },
	{ "PCSOURCES", 241, WebIcon },
	{ "IMPORT", 362, ImportIcon },
	{ "DOWNLOAD", 412, DownloadIcon },
	{ "SETTINGS", 462, OptionsIcon }
}

local NEXT_MODES = {
	["LIBRARY"] = "CATALOGS",
	["CATALOGS"] = "HISTORY",
	["HISTORY"] = "PCSOURCES",
	["PCSOURCES"] = "IMPORT",
	["IMPORT"] = "DOWNLOAD",
	["DOWNLOAD"] = "SETTINGS",
	["SETTINGS"] = "SETTINGS"
}

local PREV_MODES = {
	["LIBRARY"] = "LIBRARY",
	["CATALOGS"] = "LIBRARY",
	["HISTORY"] = "CATALOGS",
	["PCSOURCES"] = "HISTORY",
	["IMPORT"] = "PCSOURCES",
	["DOWNLOAD"] = "IMPORT",
	["SETTINGS"] = "DOWNLOAD"
}

---@param newMode string | '"LIBRARY"' | '"CATALOGS"' | '"SETTINGS"' | '"DOWNLOAD"'
---Sets menu mode
function Menu.setMode(newMode)
	if mode == newMode then
		return
	end
	Catalogs.setStatus(newMode)
	mode = newMode
end

function Menu.getMode()
	return mode
end

function Menu.input(oldPad, pad, oldTouch, touch)
	if Details.getStatus() == "END" then
		if CatalogModes.getStatus() == "END" then
			if Extra.getStatus() == "END" then
				if Controls.check(pad, SCE_CTRL_RTRIGGER) and not Controls.check(oldPad, SCE_CTRL_RTRIGGER) then
					Menu.setMode(NEXT_MODES[mode])
				end
				if Controls.check(pad, SCE_CTRL_LTRIGGER) and not Controls.check(oldPad, SCE_CTRL_LTRIGGER) then
					Menu.setMode(PREV_MODES[mode])
				end
				if touch.x and not oldTouch.x and touch.x < 205 then
					for _, section in ipairs(sections) do
						if touch.y >= section[2] and touch.y < section[2] + 44 then
							Menu.setMode(section[1])
							break
						end
					end
				end
				Catalogs.input(oldPad, pad, oldTouch, touch)
			else
				Extra.input(oldPad, pad, oldTouch, touch)
			end
		else
			CatalogModes.input(pad, oldPad, touch, oldTouch)
		end
	else
		if Extra.getStatus() == "END" then
			Details.input(oldPad, pad, oldTouch, touch)
		else
			Extra.input(oldPad, pad, oldTouch, touch)
		end
	end
end

function Menu.update()
	for _, section in ipairs(sections) do
		local key = section[1]
		buttonsAlpha[key] = UI.approach(buttonsAlpha[key] or 0, key == mode and 1 or 0, 85)
		if key == mode then
			selectionY = UI.approach(selectionY, section[2], 75)
		end
	end
	downloadIndicatorValue = UI.approach(downloadIndicatorValue, ChapterSaver.is_download_running() and 1 or 0, 120)
	Catalogs.update()
	Details.update()
	CatalogModes.update()
end

function Menu.draw()
	Screen.clear(COLOR_BACK)
	UI.sidebar()
	Graphics.drawImage(0, 0, logoSmall.e)
	Graphics.fillRect(18, 187, 76, 77, Color.new(255, 255, 255, 40))
	UI.roundRect(9, 196, selectionY, selectionY + 44, Color.new(255, 255, 255, 36))
	Graphics.fillRect(10, 13, selectionY + 9, selectionY + 35, Color.new(144, 220, 255))
	Graphics.fillRect(18, 187, 344, 345, Color.new(255, 255, 255, 30))
	local labels = Language[Settings.Language].APP
	for _, section in ipairs(sections) do
		local key, y, icon = section[1], section[2], section[3]
		local active = buttonsAlpha[key] or 0
		local tint = Color.new(255, 255, 255, 165 + 90 * active)
		local offset = active * 2
		Graphics.drawImage(20 + offset, y + (44 - icon.Height) / 2, icon.e, tint)
		local label = labels[key] or (key == "PCSOURCES" and "PC SOURCES" or key)
		label = FitText(FONT16, label, (key == "DOWNLOAD" and 120 or 132) - offset)
		Font.print(FONT16, 56 + offset, y + (44 - Font.getTextHeight(FONT16, label)) / 2, label, tint)
		if key == "DOWNLOAD" and downloadIndicatorValue > 0 then
			UI.roundRect(181, 187, y + 19, y + 25, Color.new(144, 220, 255, 255 * downloadIndicatorValue))
		end
	end
	if Details.getFade() ~= 1 then
		Catalogs.draw()
	end
	CatalogModes.draw()
	Details.draw()
end
