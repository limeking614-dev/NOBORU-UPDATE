loadlib("image")
local logo = Image:new(Graphics.loadImage("app0:assets/images/logo.png"))

Graphics.initBlend()
Screen.clear()
if logo then
	Graphics.drawImage(480 - 666 / 2, 272 - 172 / 2, logo.e)
end
Graphics.termBlend()

local doesDirExist = System.doesDirExist
local listDirectory = System.listDirectory
local createDirectory = System.createDirectory
loadlib("utils")
loadlib("globals")
loadlib("browser")
loadlib("customsettings")
loadlib("customcovers")
loadlib("catalogmodes")
loadlib("changes")
loadlib("conmessage")
loadlib("selector")
loadlib("console")
loadlib("language")
loadlib("themes")
loadlib("webtoonlang")
loadlib("loading")
loadlib("adbypass")
loadlib("net")
loadlib("parserhandler")
loadlib("settings")
loadlib("database")
loadlib("parser")
loadlib("catalogs")
loadlib("extra")
loadlib("details")
loadlib("menu")
loadlib("panel")
loadlib("notifications")
loadlib("debug")
loadlib("chsaver")
loadlib("cache")
loadlib("webtoon")
loadlib("reader")
loadlib("import")
loadlib("parserchecker")
loadlib("rokuru")
loadlib("cfbridge")
loadlib("siteprofile")
loadlib("vitasurf")
loadlib("cfcheck")
loadlib("rkclock")
loadlib("uisound")

os = nil
debug = nil
package = nil
require = nil
RemoveDirectory = nil
CopyFile = nil

System = {
	getLanguage = System.getLanguage,
	extractZipAsync = System.extractZipAsync,
	getAsyncState = System.getAsyncState,
	getPictureResolution = System.getPictureResolution,
	extractFromZipAsync = System.extractFromZipAsync
}

-- Only the bundled sources (MangaTown, AsuraScans + sites you add yourself) are used.
-- Old downloaded source files from earlier versions are wiped so they can't show up again.
if doesDirExist("ux0:data/noboru/parsers") then
	pcall(ClearParsers)
else
	createDirectory("ux0:data/noboru/parsers")
end

LoadBuiltinParsers()

local fonts = {
	FONT16,
	FONT20,
	FONT26,
	BONT30,
	BONT16
}

local function preloadData()
	coroutine.yield("Loading settings")
	local suc, err = pcall(Settings.load, Settings)
	if not suc then
		Console.error(err)
	end
	if not Settings.SkipFontLoad then
		local loadFontString = '1234567890AaBbCcDdEeFf\nGgHhIiJjKkLlMmNnOoPpQqRr\nSsTtUuVvWwXxYyZzАаБб\nВвГгДдЕеЁёЖжЗзИиЙйКкЛлМм\nНнОоПпРрСсТтУуФфХхЦцЧчШшЩщ\nЫыЪъЬьЭэЮюЯя!@#$%^&*()\n_+-=[]"\\/.,{}:;\'|? №~<>`\r—'
		if Settings.Language == "Vietnamese" then
			loadFontString = loadFontString .. '\nĂăÂâĐđÊê\nÔôƠơƯư\nÁáÀàẢảÃãẠạĂăẮắẰằẲẳẴẵẶặÂâẤấẦầẨ\nẩẪẫẬậĐđÉéÈèẺẻẼẽẸẹÊêẾếỀ\nềỂểỄễỆệÍíÌìỈỉĨĩỊịÓóÒò\nỎỏÕõỌọÔôỐốỒồỔổỖỗỘộƠ\nơỚớỜờỞởỠỡỢợÚúÙùỦủ\nŨũỤụƯưỨứỪừỬửỮữỰựÝýỲỳỶỷỸ\nỹỴỵ' --to disable lag for vietnamese (very slow loading)
		end
		for langName, _ in pairs(Language) do
			loadFontString = loadFontString .. (LanguageNames and LanguageNames[langName] and LanguageNames[langName][langName] or "")
		end
		for k, v in ipairs(fonts) do
			coroutine.yield("Loading fonts " .. k .. "/" .. #fonts)
			Font.print(v, 0, 0, loadFontString, COLOR_BLACK)
		end
	end
	coroutine.yield("Loading cache, checking existing data")
	suc, err = pcall(Cache.load)
	if not suc then
		Console.error(err)
	end
	coroutine.yield("Loading history")
	suc, err = pcall(Cache.loadHistory)
	if not suc then
		Console.error(err)
	end
	coroutine.yield("Loading library")
	suc, err = pcall(Database.load)
	if not suc then
		Console.error(err)
	end
	coroutine.yield("Checking saved chapters")
	suc, err = pcall(ChapterSaver.load)
	if not suc then
		Console.error(err)
	end
	coroutine.yield("Loading custom covers")
	suc, err = pcall(CustomCovers.load)
	if not suc then
		Console.error(err)
	end
	Menu.setMode("LIBRARY")
	Panel.show()
	coroutine.yield("Checking for update")
	suc, err = pcall(SettingsFunctions.CheckDonators)
	if not suc then
		Console.error(err)
	end
end

Screen.flip()
Screen.waitVblankStart()

MENU = 0
READER = 1
AppMode = MENU

local is_touch_locked = false

local LoadingTimer = Timer.new()

local f = coroutine.create(preloadData)
while coroutine.status(f) ~= "dead" do
	Graphics.initBlend()
	Screen.clear()
	local _, text, prog
	Timer.reset(LoadingTimer)
	repeat
		_, text, prog = coroutine.resume(f)
	until Timer.getTime(LoadingTimer) > 8
	if not _ then
		Console.error(text)
	end
	if text then
		Font.print(FONT16, 960 / 2 - Font.getTextWidth(FONT16, text) / 2, 272 + 172 / 2 + 10, text, Color.new(100, 100, 100))
	end
	if prog and not Settings.SkipCacheChapterChecking then
		Graphics.fillRect(150, 150 + 660, 272 + 172 / 2 + 42, 272 + 172 / 2 + 45, Color.new(100, 100, 100))
		Graphics.fillRect(150, 150 + 660 * prog, 272 + 172 / 2 + 42, 272 + 172 / 2 + 45, COLOR_WHITE)
	end
	if logo then
		Graphics.drawImage(480 - 666 / 2, 272 - 172 / 2, logo.e)
	end
	Graphics.termBlend()
	Screen.flip()
end
Timer.destroy(LoadingTimer)

if Settings.RefreshLibAtStart then
	ParserManager.updateCounters()
end

local pad, oldPad = Controls.read()
local oldTouch, touch = {}, {}
local oldTouch2, touch2 = {}, {}

if Controls.check(pad, SCE_CTRL_SELECT) then
	Debug.upgradeDebugMenu()
end

local fade = 1

local function input()
	oldPad, pad = pad, Controls.read()
	oldTouch.x, oldTouch.y, oldTouch2.x, oldTouch2.y, touch.x, touch.y, touch2.x, touch2.y = touch.x, touch.y, touch2.x, touch2.y, Controls.readTouch()

	Debug.input()

	if Changes.isActive() then
		if touch.x or pad ~= 0 then
			oldPad = Changes.close(pad) or 0
		end
		pad = oldPad
		is_touch_locked = true
	elseif ConnectMessage.isActive() then
		if touch.x or pad ~= 0 then
			oldPad = ConnectMessage.input(pad) or 0
		end
		pad = oldPad
		is_touch_locked = true
	end

	if touch2.x and AppMode ~= READER then
		is_touch_locked = true
	elseif not touch.x then
		is_touch_locked = false
	end

	if is_touch_locked then
		touch.x = nil
		touch.y = nil
		oldTouch.x = nil
		oldTouch.y = nil
		touch2.x = nil
		touch2.y = nil
		oldTouch2.x = nil
		oldTouch2.y = nil
	end

	if CFCheck.isActive() then
		-- the "Checking Cloudflare" screen owns the buttons and the touch screen while it is open
		CFCheck.input(oldPad, pad)
		touch.x, touch.y, oldTouch.x, oldTouch.y = nil, nil, nil, nil
		touch2.x, touch2.y, oldTouch2.x, oldTouch2.y = nil, nil, nil, nil
		is_touch_locked = true
	elseif Keyboard.getState() ~= RUNNING then
		if AppMode == MENU then
			UISound.update(oldPad, pad)
			Menu.input(oldPad, pad, oldTouch, touch)
		elseif AppMode == READER then
			if Extra.getStatus() == "END" then
				Reader.input(oldPad, pad, oldTouch, touch, oldTouch2, touch2)
			else
				Extra.input(oldPad, pad, oldTouch, touch)
			end
		end
	end
end

local function update()
	Debug.update()
	if fade == 0 then
		Panel.update()
		Threads.update()
		ParserManager.update()
		ChapterSaver.update()
		ConnectMessage.update()
		Changes.update()
	end
	if fade > 0 then
		fade = fade - fade / 8
		if fade < 1 / 254 then
			fade = 0
		end
	end
	if AppMode == MENU then
		Menu.update()
		if Details.getStatus() == "END" and CatalogModes.getStatus() == "END" then
			if Extra.getStatus() == "END" then
				Panel.show()
			else
				Panel.hide()
			end
		else
			Panel.hide()
		end
	elseif AppMode == READER then
		Reader.update()
		Panel.hide()
	end
	Extra.update()
	Notifications.update()
	ParserChecker.update()
	CFCheck.update()
end

local function draw()
	Graphics.initBlend()
	if AppMode == MENU then
		Menu.draw()
	elseif AppMode == READER then
		Reader.draw()
		RKClock.draw()
	end
	Extra.draw()
	Loading.draw()
	CFCheck.draw()
	if fade > 0 then
		Graphics.fillRect(0, 960, 0, 544, Color.new(0, 0, 0, 255 * fade))
		if logo then
			Graphics.drawImage(480 - 666 / 2, 272 - 172 / 2, logo.e, Color.new(255, 255, 255, 255 * fade))
		end
	elseif logo and logo.free then
		logo:free()
		logo = nil
	else
		ConnectMessage.draw()
		Changes.draw()
	end
	Notifications.draw()
	Panel.draw()
	Debug.draw()
	Graphics.termBlend()
	Screen.flip()
	Screen.waitVblankStart()
end

LAUNCHED = true

while true do
	input()
	update()
	draw()
end
