-- rokuru.lua : WebP conversion helpers + built-in sources (VortexScans, Madara sites) for NOBORU
-- captured now, because main.lua replaces the global System table with a restricted one
RK_SYS = {
	openFile = System.openFile,
	closeFile = System.closeFile,
	readFile = System.readFile,
	writeFile = System.writeFile,
	doesFileExist = System.doesFileExist,
	deleteFile = System.deleteFile,
	sizeFile = System.sizeFile
}
RK_DIR = "app0:assets/parsers/"

local sub = RK_SUB or string.sub

---@param path string
---@return boolean
---True when the file really is a WebP image (checks the header, not the name)
function RK_IsWebpFile(path)
	if not RK_SYS.doesFileExist(path) then
		return false
	end
	local fh = RK_SYS.openFile(path, FREAD)
	local head = RK_SYS.readFile(fh, 12) or ""
	RK_SYS.closeFile(fh)
	return sub(head, 1, 4) == "RIFF" and sub(head, 9, 12) == "WEBP"
end

local function urlenc(s)
	return (tostring(s):gsub("[^%w%-_%.~]", function(c)
		return string.format("%%%02X", c:byte())
	end))
end

---@param link string | table
---@param force boolean | nil convert even if the name doesn't end with .webp
---@param isPic boolean | nil the link is a page / cover picture (extension-less links are converted too)
---@return string | table
---Rewrites an image link into a smaller link served by the wsrv.nl image service.
---FAST mode (Settings.FastImages, default on): PNG, JPG and WebP pages become resized JPEGs,
---which are several times smaller and load much faster (fixes slow "tap to retry" pages).
---Otherwise only WebP is converted, using Settings.WebpConvert = "png" | "jpg" | "off".
---Only public https pictures are converted (never LAN / PC bridge links).
function WebpProxyLink(link, force, isPic, isCover)
	local fast = Settings and Settings.FastImages ~= false
	local mode = fast and "jpg" or (Settings and Settings.WebpConvert)
	if mode ~= "png" and mode ~= "jpg" then
		return link
	end
	local url = link
	if type(link) == "table" then
		url = link.Link
	end
	if type(url) ~= "string" or url:find("wsrv%.nl", 1) or url:find("^file:") or url:find("^[a-z]+0:") then
		return link
	end
	if not url:find("^https://") or url:find("/api/fetch", 1, true) then
		return link
	end
	if not force then
		local ext = (url:gsub("[?#].*$", "")):match("%.(%w+)$")
		ext = ext and ext:lower()
		local convert = false
		if ext == "webp" then
			convert = true
		elseif fast then
			if isPic or ext == "png" or ext == "jpg" or ext == "jpeg" or ext == "gif" or ext == "avif" or ext == "bmp" then
				convert = true -- every manga picture and every chapter cover becomes a JPEG
			end
		end
		if not convert then
			return link
		end
	end
	local width = fast and (isCover and "360" or "800") or "960"
	local newLink = "https://wsrv.nl/?url=" .. urlenc(url) .. "&output=" .. mode .. "&w=" .. width .. "&we" .. (mode == "jpg" and (fast and (isCover and "&q=75" or "&q=80") or "&q=88") or "")
	if type(link) == "table" then
		local t = {}
		for k, v in pairs(link) do
			t[k] = v
		end
		t.Link = newLink
		t.Header1, t.Header2, t.Header3, t.Header4 = nil, nil, nil, nil
		return t
	end
	return newLink
end

---@param link string | table  the ORIGINAL picture link
---@param width number         width of the picture that was downloaded
---@return string | nil
---The PS Vita GPU stores pictures in rows of 8 pixels. A picture whose width is not a multiple of 8
---is drawn with slanted lines / stretched from the right. This returns a link to the same picture
---resized by the wsrv.nl service to the nearest smaller multiple of 8 (nil when that isn't possible).
function AlignedImageLink(link, width)
	local url = link
	if type(link) == "table" then
		url = link.Link
	end
	width = tonumber(width)
	if type(url) ~= "string" or not width or width < 16 or width % 8 == 0 then
		return nil
	end
	if not url:find("^https://") or url:find("wsrv%.nl", 1) or url:find("/api/fetch", 1, true) then
		return nil
	end
	local w = width - width % 8
	return "https://wsrv.nl/?url=" .. urlenc(url) .. "&output=jpg&w=" .. w .. "&q=85"
end

local STATUS_PATH = "ux0:data/noboru/rokuru_status.lua"
RK_PARSERS = {}

local function loadStatus()
	if RK_SYS.doesFileExist(STATUS_PATH) then
		local ok, t = pcall(dofile, STATUS_PATH)
		if ok and type(t) == "table" then
			return t
		end
	end
	return {}
end

local function saveStatus(t)
	local parts = {}
	for k, v in pairs(t) do
		parts[#parts + 1] = string.format("[%q]=%s", k, v and "true" or "false")
	end
	local s = "return {" .. table.concat(parts, ",") .. "}"
	if RK_SYS.doesFileExist(STATUS_PATH) then
		RK_SYS.deleteFile(STATUS_PATH)
	end
	local fh = RK_SYS.openFile(STATUS_PATH, FCREATE)
	RK_SYS.writeFile(fh, s, #s)
	RK_SYS.closeFile(fh)
end

---Loads (or reloads) every source bundled in assets/parsers.
---Sources that failed the last Refresh check stay hidden until the next Refresh.
function LoadBuiltinParsers()
	local okIndex, index = pcall(dofile, RK_DIR .. "index.lua")
	if not okIndex or type(index) ~= "table" then
		Console.error("Can't read parser list: " .. tostring(index))
		return
	end
	local status = loadStatus()
	RK_PARSERS = {}
	-- remember every parser object the bundled files create
	local origNew = Parser.new
	Parser.new = function(self, ...)
		local p = origNew(self, ...)
		RK_PARSERS[#RK_PARSERS + 1] = p
		return p
	end
	for _, name in ipairs(index) do
		local suc, err = pcall(dofile, RK_DIR .. name .. ".lua")
		if not suc then
			Console.error("Can't load source " .. name .. ": " .. tostring(err))
		end
	end
	Parser.new = origNew
	-- (the old "failed the last check -> stay hidden" memory is ignored: with only a couple of
	-- sources left, a single bad network moment must never hide them)
	ChangeNSFW()
	-- the sites you added with the circle button come back into the catalog list
	if SyncCustomSites then
		pcall(SyncCustomSites)
	end
end

---Refresh check: a source "works" when its first page of titles isn't empty.
---Adult sources are left alone. Runs inside the ParserManager task coroutine.
function RK_CheckParsers()
	local st = loadStatus()
	local total, okCount, checked = 0, 0, 0
	for _, p in ipairs(RK_PARSERS) do
		if not p.NSFW then
			total = total + 1
		end
	end
	if Notifications and Notifications.push then
		Notifications.push("Checking " .. total .. " sources...")
	end
	local oldTime = Settings.ConnectionTime
	pcall(Network.setConnectionTime, 5)
	for _, p in ipairs(RK_PARSERS) do
		if not p.NSFW then
			local dt = {}
			-- each probe runs in its own coroutine so one dead site can't hang the whole check
			local co = coroutine.create(function()
				p:getLatestManga(1, dt)
			end)
			local timer = Timer.new()
			local suc = true
			while coroutine.status(co) ~= "dead" do
				local resumed = coroutine.resume(co)
				if not resumed then
					suc = false
					break
				end
				if Timer.getTime(timer) > 12000 then
					suc = false
					break
				end
				coroutine.yield(false)
			end
			local ok = suc and #dt > 0
			p.Disabled = not ok
			st[p.ID] = ok
			checked = checked + 1
			if ok then
				okCount = okCount + 1
			end
			ChangeNSFW()
			coroutine.yield(false)
		end
	end
	pcall(Network.setConnectionTime, oldTime or 10)
	saveStatus(st)
	if Notifications and Notifications.push then
		Notifications.push(okCount .. " of " .. checked .. " sources working")
	end
end

-- UI text (added to every language so the settings list never shows a blank name)
for _, lang in pairs(Language) do
	if lang.SETTINGS then
		lang.SETTINGS.WebpConvert = "WebP conversion format (PNG / JPG / OFF)"
		lang.SETTINGS.FastImages = "All pages + covers to JPEG"
		lang.SETTINGS_DESCRIPTION = lang.SETTINGS_DESCRIPTION or {}
		lang.SETTINGS_DESCRIPTION.FastImages = "Every manga picture and chapter cover is loaded as a small JPEG (faster)"
	end
end
