---Table of Loading functions
Loading = {}

local status = "NONE"
local PI = math.pi
local loadingCenter = {x = 480, y = 272}

CircleIcon = Image:new(Graphics.loadImage("app0:assets/icons/circle.png"))

local loadingAnimationTimer = Timer.new()

---@param newStatus string | '"NONE"' | '"WHITE"' | '"BLACK"'
---@param x number
---@param y number
---Sets Loading mode
function Loading.setStatus(newStatus, x, y)
	if status == newStatus then
		return
	end
	status = newStatus
	if status ~= "NONE" then
		loadingCenter.x = x or 480
		loadingCenter.y = y or 272
	end
	Timer.reset(loadingAnimationTimer)
end

---Draws Loading circles
function Loading.draw()
	local time = Timer.getTime(loadingAnimationTimer) / 200
	time = math.min(math.max(status == "NONE" and 1 - time or time, 0), 1)
	for i = 1, 4 do
		local a = math.max(math.sin(Timer.getTime(GlobalTimer) / 500 * PI + i * PI / 2), 0)
		Graphics.drawImage(loadingCenter.x + (i - 3) * 13, loadingCenter.y - 1 - 16 * a, CircleIcon.e, UI.color("FONT", (127 + 128 * a) / 255 * time))
	end
end
