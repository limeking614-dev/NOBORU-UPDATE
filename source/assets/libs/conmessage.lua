ConnectMessage = {}

local yOffset = 544
local yFinal = 0
local str

local animationTimer = Timer.new()
local connectionTimer = Timer.new()
local visibility, from = 0, 0
local wasActive = false

local is_active = false

function ConnectMessage.show()
	str = Language[Settings.Language].MESSAGE.LOST_CONNECTION
	is_active = true
	yFinal = 544 / 2 - (Font.getTextHeight(FONT20, str) + 20) / 2
	Timer.reset(animationTimer)
end

function ConnectMessage.input(pad)
	if Controls.check(pad, SCE_CTRL_REAL_CROSS) and is_active and yOffset == yFinal then
		ChapterSaver.clearDownloadingList()
		is_active = false
		return SCE_CTRL_REAL_CROSS
	end
end

function ConnectMessage.update()
	if is_active then
		if Timer.getTime(connectionTimer) > 1000 then
			if Threads.netActionUnSafe(Network.isWifiEnabled) then
				is_active = false
			end
			Timer.reset(connectionTimer)
		end
	else
		Timer.reset(connectionTimer)
	end
	if wasActive ~= is_active then
		from, wasActive = visibility, is_active
		Timer.reset(animationTimer)
	end
	visibility = UI.transition(from, is_active and 1 or 0, animationTimer, is_active and UI.motion.dialog or UI.motion.exit)
	yOffset = yFinal + (544 - yFinal) * (1 - visibility)
end

function ConnectMessage.draw()
	if str and yOffset < 544 then
		Graphics.fillRect(60, 900, yOffset, yOffset + Font.getTextHeight(FONT20, str) + 27, UI.color("SURFACE"))
		Font.print(FONT20, 80, yOffset + 10, str, UI.color("FONT"))
	end
end

function ConnectMessage.isActive()
	return is_active
end
