local ffi = require("ffi")
ffi.cdef [[
    typedef struct Point {
        float x, y;
    } Point_t;
    typedef struct Slider {
        float Y;
        float V;
        float TouchY;
        int ItemID;
    } Slider;
]]

TOUCH_MODES = {
	NONE = 0,
	READ = 1,
	SLIDE = 2,
	MODE = 0
}

CreateSlider = ffi.typeof("Slider")
CreatePoint = ffi.typeof("Point_t")

LUA_GRADIENT = Image:new(Graphics.loadImage("app0:assets/images/gradient.png"))

USERAGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.36"

COLOR_WHITE = Color.new(255, 255, 255)
COLOR_BLACK = Color.new(0, 0, 0)
COLOR_GRAY = Color.new(128, 128, 128)
COLOR_DARK_GRAY = Color.new(64, 64, 64)
COLOR_LIGHT_GRAY = Color.new(192, 192, 192)
COLOR_ROYAL_BLUE = Color.new(65, 105, 226)
COLOR_CRIMSON = Color.new(137, 30, 43)

COLOR_COVER = Color.new(101, 115, 146)
COLOR_FONT = COLOR_WHITE
COLOR_SUBFONT = COLOR_GRAY
COLOR_BACK = COLOR_WHITE
COLOR_SELECTED = COLOR_WHITE
COLOR_ICON_EXTRACT = COLOR_WHITE
COLOR_PANEL = COLOR_WHITE

function COLOR_GRADIENT(colorA, colorB, a)
	if a <= 0 then
		return colorA
	elseif a >= 1 then
		return colorB
	end
	local r1, g1, b1, a1 = Color.getR(colorA), Color.getG(colorA), Color.getB(colorA), Color.getA(colorA)
	local r2, g2, b2, a2 = Color.getR(colorB), Color.getG(colorB), Color.getB(colorB), Color.getA(colorB)
	return Color.new(r1 + (r2 - r1) * a, g1 + (g2 - g1) * a, b1 + (b2 - b1) * a, a1 + (a2 - a1) * a)
end

SCE_CTRL_RIGHTPAGE = SCE_CTRL_RTRIGGER
SCE_CTRL_LEFTPAGE = SCE_CTRL_LTRIGGER

SCE_LEFT_STICK_DEADZONE = 20
SCE_LEFT_STICK_SENSITIVITY = 1
SCE_RIGHT_STICK_DEADZONE = 20
SCE_RIGHT_STICK_SENSITIVITY = 1

SCE_CTRL_REAL_CROSS = SCE_CTRL_CROSS
SCE_CTRL_REAL_CIRCLE = SCE_CTRL_CIRCLE

loadlib("fonts")

local doesDirExist = System.doesDirExist
local createDirectory = System.createDirectory
local deleteFile = System.deleteFile
local doesFileExist = System.doesFileExist

MANGA_WIDTH = 180
MANGA_HEIGHT = math.floor(MANGA_WIDTH * 1.5)

GlobalTimer = Timer.new()

if not doesDirExist("ux0:data/noboru") then
	createDirectory("ux0:data/noboru")
end

if not doesDirExist("ux0:data/noboru/chapters") then
	createDirectory("ux0:data/noboru/chapters")
end

if not doesDirExist("ux0:data/noboru/pictures") then
	createDirectory("ux0:data/noboru/pictures")
end

if not doesDirExist("ux0:data/noboru/cache") then
	createDirectory("ux0:data/noboru/cache")
end

if not doesDirExist("ux0:data/noboru/import") then
	createDirectory("ux0:data/noboru/import")
end

if not doesDirExist("ux0:data/noboru/temp") then
	createDirectory("ux0:data/noboru/temp")
end

if not doesDirExist("ux0:data/noboru/cusettings") then
	createDirectory("ux0:data/noboru/cusettings")
end

if doesFileExist("ux0:data/noboru/temp/auth.html") then
	deleteFile("ux0:data/noboru/temp/auth.html")
end

if doesFileExist("ux0:data/noboru/temp/logo.png") then
	deleteFile("ux0:data/noboru/temp/logo.png")
end

if doesDirExist("uma0:") then
	if not doesDirExist("uma0:data") then
		createDirectory("uma0:data")
	end

	if not doesDirExist("uma0:data/noboru") then
		createDirectory("uma0:data/noboru")
	end

	if not doesDirExist("uma0:data/noboru/chapters") then
		createDirectory("uma0:data/noboru/chapters")
	end

	if not doesDirExist("uma0:data/noboru/import") then
		createDirectory("uma0:data/noboru/import")
	end

	if not doesDirExist("uma0:data/noboru/pictures") then
		createDirectory("uma0:data/noboru/pictures")
	end
end

local openFile, closeFile, readFile, sizeFile, writeFile = System.openFile, System.closeFile, System.readFile, System.sizeFile, System.writeFile

---@param sourcePath string
---@param destPath string
---Copies file source_path to destPath (creates file)
---Example:
---`copyFile("ux0:data/noboru/cache.image","ux0:cover.jpeg") -> cover.jpeg appeared in ux0:`
local function copyFile(sourcePath, destPath)
	local fh1 = openFile(sourcePath, FREAD)
	local fh2 = openFile(destPath, FCREATE)
	local contentFh1 = readFile(fh1, sizeFile(fh1))
	writeFile(fh2, contentFh1, #contentFh1)
	closeFile(fh1)
	closeFile(fh2)
end

CopyFile = copyFile

copyFile("app0:assets/auth.html", "ux0:data/noboru/temp/auth.html")
copyFile("app0:assets/images/logo.png", "ux0:data/noboru/temp/logo.png")

function BytesToStr(bytes)
	local str = "Bytes"
	if bytes > 1024 then
		bytes = bytes / 1024
		str = "KB"
		if bytes > 1024 then
			bytes = bytes / 1024
			str = "MB"
			if bytes > 1024 then
				bytes = bytes / 1024
				str = "GB"
			end
		end
	end
	return string.format("%.2f %s", bytes, str)
end

---@param Name string
---@param Link string
---@param ImageLink string
---@param ParserID integer
---@param RawLink string
---Creates `Manga-Info` table
function CreateManga(Name, Link, ImageLink, ParserID, RawLink, BrowserLink)
	if Name and Link and ImageLink and ParserID then
		return {
			Name = Name,
			Link = Link,
			ImageLink = ImageLink,
			ParserID = ParserID,
			RawLink = RawLink or "",
			BrowserLink = BrowserLink,
			Data = {}
		}
	else
		return nil
	end
end

local CJK = {
	{"㌀", "㏿"},
	{"︰", "﹏"},
	{"豈", "﫿"},
	{"丽", "𯨟"},
	{"぀", "ゟ"},
	{"゠", "ヿ"},
	{"⺀", "⻿"},
	{"一", "鿿"},
	{"㐀", "䶿"},
	{"𠀀", "𪛟"},
	{"𪜀", "𫜿"},
	{"𫝀", "𫠟"},
	{"𫠠", "𬺯"}
}

function IsCJK(letter)
	for i = 1, #CJK do
		if letter >= CJK[i][1] and letter <= CJK[i][2] then
			return true
		end
	end
	return false
end

local isCJK = IsCJK

local function drawMangaName(Manga, width)
	local available = width - 16
	local chars = {}
	for char in it_utf8(Manga.Name) do chars[#chars + 1] = char end
	local lines, index = {}, 1
	for row = 1, 2 do
		local line = ""
		while index <= #chars and Font.getTextWidth(BONT16, line .. chars[index]) <= available do
			line, index = line .. chars[index], index + 1
		end
		if row == 1 and index <= #chars then
			local head, tail = line:match("^(.*)%s+([^%s]+)$")
			if head and head ~= "" then
				for _ in it_utf8(tail) do index = index - 1 end
				line = head
			end
		end
		lines[row] = line:gsub("^%s+", ""):gsub("%s+$", "")
		while chars[index] and chars[index]:match("%s") do index = index + 1 end
		if index > #chars then break end
	end
	if index <= #chars then
		local last = {}
		for char in it_utf8(lines[2] or "") do last[#last + 1] = char end
		while #last > 0 and Font.getTextWidth(BONT16, table.concat(last) .. "…") > available do last[#last] = nil end
		lines[2] = table.concat(last) .. "…"
	end
	Manga.PrintNameWidth = width
	Manga.PrintName = { f = #lines > 1 and lines[1] or nil, s = lines[#lines] or "" }
end

function DrawManga(x, y, Manga, width, height, coverOnly, titlesBelow)
	width, height = width or MANGA_WIDTH, height or MANGA_HEIGHT
	DrawDetailsManga(x, y, Manga, width / MANGA_WIDTH)
	if coverOnly then return end
	if not titlesBelow then Graphics.drawScaleImage(x - width / 2, y + height / 2 - 120, LUA_GRADIENT.e, width, 1) end
	if Manga.Name then
		if not Manga.PrintName or Manga.PrintNameWidth ~= width then pcall(drawMangaName, Manga, width) end
		if Manga.PrintName then
			local top = y + height / 2
			local firstY = titlesBelow and top + 7 or top - 47
			local secondY = titlesBelow and (Manga.PrintName.f and top + 27 or top + 7) or top - 27
			local color = titlesBelow and COLOR_FONT or COLOR_WHITE
			if Manga.PrintName.f and firstY < 544 and firstY > -16 then
				Font.print(BONT16, x - width / 2 + 8, firstY, Manga.PrintName.f, color)
			end
			if secondY < 544 and secondY > -16 then
				Font.print(BONT16, x - width / 2 + 8, secondY, Manga.PrintName.s, color)
			end
		end
	end
end

function DrawDetailsManga(x, y, Manga, M)
	M = M or 1
	if Manga.Image and Manga.Image.e then
		Graphics.fillRect(x - MANGA_WIDTH * M / 2, x + MANGA_WIDTH * M / 2, y - MANGA_HEIGHT * M / 2, y + MANGA_HEIGHT * M / 2, Color.new(0, 0, 0))
		local width, height = Manga.Image.Width, Manga.Image.Height
		local was_drawn = false
		if width < height then
			local scale = MANGA_WIDTH / width
			local h = MANGA_HEIGHT / scale
			local s_y = (height - h) / 2
			if s_y >= 0 then
				Graphics.drawImageExtended(x, y, Manga.Image.e, 0, s_y, width, h, 0, scale * M, scale * M)
				was_drawn = true
			end
		end
		if not was_drawn then
			local scale = MANGA_HEIGHT / height
			local w = MANGA_WIDTH / scale
			local s_x = (width - w) / 2
			Graphics.drawImageExtended(x, y, Manga.Image.e, s_x, 0, w, height, 0, scale * M, scale * M)
		end
	else
		Graphics.fillRect(x - MANGA_WIDTH * M / 2, x + MANGA_WIDTH * M / 2, y - MANGA_HEIGHT * M / 2, y + MANGA_HEIGHT * M / 2, COLOR_COVER)
	end
end
