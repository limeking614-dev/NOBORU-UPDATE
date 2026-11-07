local yOffset = 544
local yFinal = 0
local str
Changes = {}

local animationTimer = Timer.new()
local visibility, from = 0, 0
local wasActive = false

local is_active = false
local is_app_updating = false

function Changes.load(string)
	str = string .. "\n\n" .. Language[Settings.Language].MESSAGE.PRESS_TO_UPDATE
	is_active = true
	yFinal = (544 - (Font.getTextHeight(FONT20, str) + 20)) / 2
	Timer.reset(animationTimer)
end

function Changes.close(pad)
	if not is_app_updating then
		if Controls.check(pad, SCE_CTRL_REAL_CIRCLE) then
			if math.ceil(yOffset - yFinal) < 10 then
				is_active = false
				Timer.reset(animationTimer)
				return SCE_CTRL_REAL_CIRCLE
			end
		elseif Controls.check(pad, SCE_CTRL_REAL_CROSS) then
			Settings.updateApp()
			is_app_updating = true
		end
	end
end

function Changes.update()
	if is_app_updating and not Settings.isAppUpdating() then
		is_app_updating = false
		is_active = false
	end
	if wasActive ~= is_active then
		from, wasActive = visibility, is_active
		Timer.reset(animationTimer)
	end
	visibility = UI.transition(from, is_active and 1 or 0, animationTimer, is_active and UI.motion.dialog or UI.motion.exit)
	yOffset = yFinal + (544 - yFinal) * (1 - visibility)
end

function Changes.draw()
	if str and yOffset < 544 then
		Graphics.fillRect(60, 900, yOffset, yOffset + Font.getTextHeight(FONT20, str) + 20, UI.color("SURFACE"))
		local s = str
		if is_app_updating then
			s = (str:match("(.+)\n(.-)\n(.-)$") .. "\n" .. "(" .. BytesToStr(Network.getDownloadedBytes()) .. "/" .. SettingsFunctions.GetLastVpkSize() .. ") " .. Language[Settings.Language].SETTINGS.PleaseWait)
		end
		Font.print(FONT20, 80, yOffset + 10, s, UI.color("FONT"))
	end
end

function Changes.isActive()
	return is_active
end
