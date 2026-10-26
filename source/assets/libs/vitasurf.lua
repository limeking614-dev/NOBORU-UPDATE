-- vitasurf.lua : bridge to the VitaSurf browser (NetSurf + QuickJS for the PS Vita, title id VSRF00001)
--
--  Sites that sit behind a Cloudflare check ("Just a moment...") can't be passed by the Vita's plain
--  network code. VitaSurf is a real browser engine with JavaScript, so:
--    1. Noboru writes the site as VitaSurf's start page (ux0:data/VitaSurf/Choices) and launches it
--    2. you let the page load / pass the check in VitaSurf, then quit it (Select + Start) and open Noboru
--    3. Noboru reads VitaSurf's cookie file (ux0:data/VitaSurf/Cookies), finds the site's cf_clearance
--       cookie and sends it, with the same user agent, on every request to that site
--  The same bridge can hand ANY site to VitaSurf (Triangle on the "Couldn't read the site" screen).
--
--  Needs VitaSurf installed (title id VSRF00001). Nothing is changed in VitaSurf itself: only its user
--  options file ("homepage_url", "user_agent") is edited, and the old start page is put back afterwards.
VitaSurf = {}

local SYS = RK_SYS
local launchApp = System.launchApp -- main.lua replaces System after the libs load, so keep it here

local TITLE_ID = "VSRF00001"
local APP_EBOOT = "ux0:app/VSRF00001/eboot.bin"
local DIR = "ux0:data/VitaSurf/"
local CHOICES = DIR .. "Choices"
local COOKIES = DIR .. "Cookies"
local SAVED_HOME = "ux0:data/noboru/vitasurf_home.txt" -- the start page VitaSurf had before we changed it

local function readAll(path)
	if not SYS.doesFileExist(path) then
		return nil
	end
	local fh = SYS.openFile(path, FREAD)
	local size = SYS.sizeFile and SYS.sizeFile(fh) or 65536
	local text = SYS.readFile(fh, size)
	SYS.closeFile(fh)
	return text
end

local function writeAll(path, text)
	if SYS.doesFileExist(path) then
		SYS.deleteFile(path)
	end
	local fh = SYS.openFile(path, FCREATE)
	SYS.writeFile(fh, text, #text)
	SYS.closeFile(fh)
end

---@return boolean
function VitaSurf.installed()
	return SYS.doesFileExist(APP_EBOOT)
end

local function setOption(text, name, value)
	local line = name .. ":" .. value
	local found = false
	local out = {}
	text = text:gsub("%s+$", "")
	for l in (text .. "\n"):gmatch("(.-)\r?\n") do
		if l:match("^%s*" .. name .. "%s*:") then
			if not found then
				out[#out + 1] = line
				found = true
			end
		else
			out[#out + 1] = l
		end
	end
	if not found then
		table.insert(out, line)
	end
	return (table.concat(out, "\n"):gsub("\n+$", "")) .. "\n"
end

local function getOption(text, name)
	return (text or ""):match("\n?%s*" .. name .. "%s*:%s*([^\r\n]*)")
end

---The user agent VitaSurf sends. Noboru asks for it to be the same Chrome user agent it uses itself, so a
---cookie VitaSurf earns is valid for Noboru's requests too.
function VitaSurf.userAgent()
	local text = readAll(CHOICES)
	local ua = getOption(text, "user_agent")
	if ua and ua ~= "" then
		return ua
	end
	return BROWSER_USERAGENT
end

---Starts VitaSurf on `url`.
---@return boolean, string  started, message
function VitaSurf.open(url)
	if not VitaSurf.installed() then
		return false, "VitaSurf is not installed (title id " .. TITLE_ID .. ")"
	end
	if type(launchApp) ~= "function" then
		return false, "This build can't start other apps"
	end
	local text = readAll(CHOICES) or ""
	-- remember the old start page and user agent once, so they can be put back
	if not SYS.doesFileExist(SAVED_HOME) then
		writeAll(SAVED_HOME, (getOption(text, "homepage_url") or "") .. "\n" .. (getOption(text, "user_agent") or "") .. "\n")
	end
	text = setOption(text, "homepage_url", url)
	text = setOption(text, "user_agent", BROWSER_USERAGENT)
	writeAll(CHOICES, text)
	launchApp(TITLE_ID)
	return true, ""
end

---Puts VitaSurf's own start page back (done at start-up and after the cookie was read)
function VitaSurf.restoreHome()
	if not SYS.doesFileExist(SAVED_HOME) then
		return
	end
	local saved = readAll(SAVED_HOME) or ""
	local oldHome, oldUA = saved:match("^([^\r\n]*)\r?\n([^\r\n]*)")
	local text = readAll(CHOICES)
	if text then
		for _, o in ipairs({{"homepage_url", oldHome}, {"user_agent", oldUA}}) do
			if o[2] and o[2] ~= "" then
				text = setOption(text, o[1], o[2])
			else
				text = text:gsub("\n?%s*" .. o[1] .. "%s*:[^\r\n]*", "")
			end
		end
		writeAll(CHOICES, text)
	end
	SYS.deleteFile(SAVED_HOME)
end

local function looksLikeClearance(v)
	return type(v) == "string" and #v >= 30 and v:match("^[%w_%-%.]+$") ~= nil
end

---Reads VitaSurf's cookie file and returns the cookies of `host` as a "a=b; c=d" line (or nil).
---Only counts when the cf_clearance cookie is in it: that is the Cloudflare "passed" cookie.
---NetSurf's jar is tab separated; the name / value columns are found by content so a different column
---order doesn't matter.
---@param host string  e.g. "manhuaus.com"
---@return string | nil
function VitaSurf.cookieLine(host)
	local text = readAll(COOKIES)
	if not text or text == "" then
		return nil
	end
	local bare = host:lower():gsub("^www%.", "")
	local pairsFound, order = {}, {}
	local clearance = nil
	for line in (text .. "\n"):gmatch("(.-)\r?\n") do
		if line ~= "" and line:sub(1, 1) ~= "#" then
			local f = {}
			for c in (line .. "\t"):gmatch("(.-)\t") do
				f[#f + 1] = c
			end
			local domainOk = false
			for i = 1, #f do
				local d = f[i]:lower():gsub("^%.", ""):gsub("^www%.", "")
				if d ~= "" and (d == bare or bare:sub(-#d - 1) == "." .. d or d:sub(-#bare - 1) == "." .. bare) and d:find("%.") then
					domainOk = true
				end
			end
			if domainOk then
				for i = 1, #f do
					if f[i] == "cf_clearance" then
						local v = f[i + 1]
						if not looksLikeClearance(v) then
							v = f[i - 1]
						end
						if looksLikeClearance(v) then
							clearance = v
						end
					elseif f[i] == "__cf_bm" or f[i] == "cf_chl_rc_m" then
						-- short lived Cloudflare helper cookies are not needed
					end
				end
			end
		end
	end
	if clearance then
		return "cf_clearance=" .. clearance
	end
	return nil
end

-- labels
for _, lang in pairs(Language) do
	if lang.SETTINGS then
		lang.SETTINGS.VitaSurfBridge = "VitaSurf for Cloudflare sites"
		lang.SETTINGS_DESCRIPTION = lang.SETTINGS_DESCRIPTION or {}
		lang.SETTINGS_DESCRIPTION.VitaSurfBridge = "Triangle on a failed site check opens VitaSurf; its Cloudflare cookie is used afterwards"
	end
end
