-- uisound.lua  --  menu button sounds (turn each one on/off in Settings > Controls)
--   D-pad + left stick directions -> navigation.wav
--   Cross  -> prompt_enter.wav      Circle -> prompt_back.wav      Square -> navigation_back.wav
UISound = {}

local FILES = {
	nav = "app0:assets/sounds/navigation.wav",
	enter = "app0:assets/sounds/prompt_enter.wav",
	back = "app0:assets/sounds/prompt_back.wav",
	alt = "app0:assets/sounds/navigation_back.wav"
}
local pool = {}
local loaded, failed = false, false

local function load()
	if loaded then
		return not failed
	end
	loaded = true
	local ok = pcall(function()
		if Sound.init then
			Sound.init()
		end
		for k, path in pairs(FILES) do
			pool[k] = {Sound.open(path), Sound.open(path)}
		end
	end)
	if not ok then
		failed = true
	end
	return ok
end

local function play(key)
	if not load() then
		return
	end
	pcall(function()
		local p = pool[key]
		for i = 1, #p do
			if p[i] and not Sound.isPlaying(p[i]) then
				Sound.play(p[i], false)
				return
			end
		end
	end)
end

local STICK_DEAD = 45
local heldDir, heldFrames = nil, 0

local function directionNow(pad)
	if Controls.check(pad, SCE_CTRL_UP) then
		return SCE_CTRL_UP
	elseif Controls.check(pad, SCE_CTRL_DOWN) then
		return SCE_CTRL_DOWN
	elseif Controls.check(pad, SCE_CTRL_LEFT) then
		return SCE_CTRL_LEFT
	elseif Controls.check(pad, SCE_CTRL_RIGHT) then
		return SCE_CTRL_RIGHT
	end
	local ok, lx, ly = pcall(Controls.readLeftAnalog)
	if ok and lx and ly then
		local dx, dy = lx - 127, ly - 127
		if math.abs(dy) >= math.abs(dx) then
			if dy < -STICK_DEAD then
				return SCE_CTRL_UP
			elseif dy > STICK_DEAD then
				return SCE_CTRL_DOWN
			end
		else
			if dx < -STICK_DEAD then
				return SCE_CTRL_LEFT
			elseif dx > STICK_DEAD then
				return SCE_CTRL_RIGHT
			end
		end
	end
	return nil
end

local function pressed(oldpad, pad, button)
	return Controls.check(pad, button) and not Controls.check(oldpad, button)
end

---Call once per frame while a menu is on screen
function UISound.update(oldpad, pad)
	if Settings.UISoundDirections ~= false then
		local dir = directionNow(pad)
		if dir ~= heldDir then
			heldDir, heldFrames = dir, 0
			if dir then
				play("nav")
			end
		elseif dir then
			heldFrames = heldFrames + 1
			-- list keeps scrolling while held: tick along with it
			if heldFrames >= 24 and (heldFrames - 24) % 7 == 0 then
				play("nav")
			end
		end
	else
		heldDir = nil
	end
	if Settings.UISoundCross ~= false and pressed(oldpad, pad, SCE_CTRL_CROSS) then
		play("enter")
	end
	if Settings.UISoundCircle ~= false and pressed(oldpad, pad, SCE_CTRL_CIRCLE) then
		play("back")
	end
	if Settings.UISoundSquare ~= false and pressed(oldpad, pad, SCE_CTRL_SQUARE) then
		play("alt")
	end
end

-- names for the settings (every language falls back to English)
local NAMES = {
	UISoundDirections = "Sound: D-pad / left stick",
	UISoundCross = "Sound: Cross button",
	UISoundCircle = "Sound: Circle button",
	UISoundSquare = "Sound: Square button"
}
for _, L in pairs(Language) do
	if type(L) == "table" and type(L.SETTINGS) == "table" then
		for k, v in pairs(NAMES) do
			L.SETTINGS[k] = L.SETTINGS[k] or v
		end
	end
end
