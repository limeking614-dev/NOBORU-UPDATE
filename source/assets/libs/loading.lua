---Table of Loading functions
Loading = {}

local status = "NONE"
local PI = math.pi
local loadingCenter = {x = 480, y = 272}

CircleIcon = Image:new(Graphics.loadImage("app0:assets/icons/circle.png"))

local loadingAnimationTimer = Timer.new()
local fadeFrom = 0

local function visibility()
	return UI.transition(fadeFrom, status == "NONE" and 0 or 1, loadingAnimationTimer,
		status == "NONE" and UI.motion.exit or UI.motion.enter)
end

---@param newStatus string | '"NONE"' | '"WHITE"' | '"BLACK"'
---@param x number
---@param y number
---Sets Loading mode
function Loading.setStatus(newStatus, x, y)
	if status == newStatus then
		return
	end
	fadeFrom = visibility()
	status = newStatus
	if status ~= "NONE" then
		loadingCenter.x = x or 480
		loadingCenter.y = y or 272
	end
	Timer.reset(loadingAnimationTimer)
end

---Draws Loading circles
function Loading.draw()
	local time = visibility()
	if time == 0 then return end
	for i = 1, 4 do
		local a = math.max(math.sin(Timer.getTime(GlobalTimer) / 500 * PI + i * PI / 2), 0)
		Graphics.drawImage(loadingCenter.x + (i - 3) * 13, loadingCenter.y - 1 - 16 * a, CircleIcon.e, UI.color("FONT", (127 + 128 * a) / 255 * time))
	end
end
