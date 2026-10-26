-- cfcheck.lua : "Checking site" screen, shown when a manga source (site) is opened
--
--   CHECKING  spinner + "Checking site..."  - really reads the site the way a browser does:
--               1. the front page is requested with browser headers (ad / redirect pages are skipped by
--                  net.lua + adbypass.lua, Cloudflare pages go through the PC bridge when it is set up)
--               2. the source's own list is read (its first page of titles), so a source only
--                  counts as OK when manga were really found
--   OK        green check mark + "Site connected"  ->  the source opens by itself (Circle = open now)
--   FAIL      red cross + the reason  ->  Cross = check again, Circle = open the source anyway,
--             Triangle = open the site in the Vita's mini browser (solve a check there, close it, press
--             Cross), Square = cancel
--
-- Cookies the Vita browser got from Cloudflare (cf_clearance) are read from its cookie jar and sent
-- (with the browser's user agent) on every request to that site, pages and pictures included.
CFCheck = {}

local state = nil -- nil | "CHECKING" | "OK" | "FAIL"
local site, host, reason = nil, nil, ""
local onDone = nil
local probe = nil -- running Threads request (key of the table)
local co = nil -- the check itself (coroutine, resumed every frame)
local step = "" -- what the check is doing right now (shown under the title)
local info = "" -- result line shown when the check is OK
local theParser = nil
local pending = nil -- result waiting for the minimum spinner time: {ok = bool, reason = string}
local probeTimer = Timer.new()
local stateTimer = Timer.new()
local openTimer = Timer.new()

local TIMEOUT = 75000 -- ms for the whole check
local MIN_SPIN = 700 -- ms, so the spinner never just flashes

local cookies = {} -- [host] = "cf_clearance=...; ..."
local cookieUA = {} -- [host] = user agent of the browser that earned the cookie (nil = the Vita browser)

local function hostOf(link)
	local h = tostring(link or ""):match("^https?://([^/:%?#]+)")
	if not h then
		return nil
	end
	h = h:lower()
	return (h:gsub("^www%.", ""))
end

---Reads the Vita browser's cookies for `h` (only when Cloudflare gave it a cf_clearance cookie)
local function loadCookies(h)
	if Browser and Browser.getCookies then
		local ok, jar = pcall(Browser.getCookies, h)
		if ok and type(jar) == "table" and jar["cf_clearance"] and type(jar["@"]) == "string" and jar["@"] ~= "" then
			return jar["@"], nil
		end
	end
	-- the Cloudflare cookie VitaSurf earned (same user agent has to be sent with it)
	if VitaSurf and Settings.VitaSurfBridge ~= false then
		local ok, line = pcall(VitaSurf.cookieLine, h)
		if ok and line then
			return line, VitaSurf.userAgent()
		end
	end
	return nil
end

---@param link string
---@return string | nil, string | nil  cookie line and the user agent it belongs to (nil: the Vita browser's)
---Used by net.lua for every request: sites that were solved in the Vita browser
function CFCookieFor(link)
	local h = hostOf(link)
	while h do
		if cookies[h] then
			return cookies[h], cookieUA[h] or Browser.getUserAgent()
		end
		h = h:match("^[^%.]+%.(.+%..+)$")
	end
	return nil
end

function CFCheck.isActive()
	return state ~= nil
end

local function setState(newState, why)
	state = newState
	reason = why or ""
	Timer.reset(stateTimer)
end

---One request, the way every source does it (returns the page text, "" when nothing came back)
local function fetch(url)
	local t = {}
	probe = t
	Threads.insertTask(t, {Type = "StringRequest", Link = url, Table = t, Index = "string"})
	while Threads.check(t) do
		coroutine.yield()
	end
	probe = nil
	return t.string or ""
end

local function countOf(s, pat)
	local _, n = s:gsub(pat, "")
	return n
end

---The check itself. Ends by setting `pending`.
local function runCheck()
	local skippedBefore = AdBypass and AdBypass.skipped or 0
	-- 1. read the front page like a browser
	step = "Reading " .. tostring(host)
	local body = fetch(site)
	if body == "" then
		-- some sites only answer on the plain address
		local plain = site:gsub("^(https?://[^/]+).*$", "%1/")
		if plain ~= site then
			step = "Trying " .. tostring(host) .. " again"
			body = fetch(plain)
		end
	end
	local skipped = (AdBypass and AdBypass.skipped or 0) - skippedBefore
	if skipped > 0 then
		step = "Ad page skipped, reading the site"
	end
	if body == "" then
		pending = {ok = false, reason = "Can't reach the site (check the Wi-Fi, or the site is down)"}
		return
	end
	if CFBridgeIsChallenge and CFBridgeIsChallenge(body) then
		pending = {ok = false, reason = "Cloudflare is blocking the Vita (Triangle: pass the check in VitaSurf)"}
		return
	end
	if AdBypass and AdBypass.isInterstitial(body) then
		pending = {ok = false, reason = "The site only shows an ad page right now"}
		return
	end
	local lower = body:lower()
	local links = countOf(lower, "<a%s")
	local head = body:match("^%s*(.)")
	local isJson = head == "{" or head == "["
	if not isJson and links == 0 and #body < 400 then
		pending = {ok = false, reason = "The site answered with an empty page"}
		return
	end
	-- 2. learn what kind of site this is, so the source tries the right layouts first
	local p = theParser
	if SiteProfile and p and p.ID ~= "VITASERVER" then
		SiteProfile.detect(host, body, p)
	end
	-- 3. read the source's own list (this is what really opens when the source loads)
	local titles = nil
	if p and p.getLatestManga then
		step = "Reading the manga list"
		local dt = {}
		local inner = coroutine.create(function()
			p:getLatestManga(1, dt)
		end)
		local started = Timer.getTime(probeTimer)
		while coroutine.status(inner) ~= "dead" do
			local ok = coroutine.resume(inner)
			if not ok then
				break
			end
			if Timer.getTime(probeTimer) - started > 25000 then
				break
			end
			coroutine.yield()
		end
		titles = #dt
	end
	-- 4. ask the online source lists (Aidoku community list on GitHub) about this site
	if SiteProfile and p and Settings.SiteProfiles ~= false then
		SiteProfile.online(host, p, function(text)
			step = text
		end)
	end
	if titles ~= nil and titles == 0 then
		pending = {ok = false, reason = "The site opened, but no manga list could be read from it"}
		return
	end
	local parts = {}
	if titles then
		parts[#parts + 1] = titles .. " titles read"
	else
		parts[#parts + 1] = links .. " links read"
	end
	if skipped > 0 then
		parts[#parts + 1] = "ad page skipped"
	end
	local profileText = SiteProfile and SiteProfile.summary(host) or ""
	if profileText ~= "" then
		parts[#parts + 1] = profileText
	end
	info = tostring(host) .. " - " .. table.concat(parts, ", ")
	pending = {ok = true}
end

local function startProbe(retry)
	setState("CHECKING")
	pending = nil
	step = "Connecting to " .. tostring(host)
	info = ""
	if retry and SiteProfile then
		SiteProfile.forgetOnline(host) -- ask the online lists again
	end
	local ck, ckUA = loadCookies(host)
	if ck then
		cookies[host] = ck
		cookieUA[host] = ckUA
	end
	Timer.reset(probeTimer)
	co = coroutine.create(runCheck)
end

---@param parser table  the source that was selected
---@param callback function  loads the source (after the check)
---Starts the check. Sources that don't use the web (PC Server) open at once.
function CFCheck.begin(parser, callback)
	local link = parser and parser.Link
	if type(link) ~= "string" or not link:match("^https?://") or parser.ID == "VITASERVER" or Settings.CFCheck == false then
		callback()
		return
	end
	site = link
	host = hostOf(link)
	theParser = parser
	if VitaSurf then
		pcall(VitaSurf.restoreHome) -- put VitaSurf's own start page back (it was set to a site for the hand-over)
	end
	onDone = callback
	Timer.reset(openTimer)
	startProbe()
end

local function stopRequest()
	if probe and Threads.check(probe) then
		Threads.remove(probe)
	end
	probe = nil
end

local function cancel()
	stopRequest()
	co, pending, state, onDone, theParser = nil, nil, nil, nil, nil
end

local function proceed()
	local cb = onDone
	stopRequest()
	co, pending, state, onDone, theParser = nil, nil, nil, nil, nil
	if cb then
		cb()
	end
end

function CFCheck.update()
	if not state then
		return
	end
	if state == "CHECKING" then
		if co then
			if coroutine.status(co) ~= "dead" then
				local ok, err = coroutine.resume(co)
				if not ok then
					Console.error("Site check: " .. tostring(err))
					stopRequest()
					co = nil
					pending = {ok = false, reason = "The check could not finish"}
				end
			else
				co = nil
			end
			if co and Timer.getTime(probeTimer) > TIMEOUT then
				stopRequest()
				co = nil
				pending = {ok = false, reason = "The site did not answer in time"}
			end
		end
		if pending and Timer.getTime(stateTimer) >= MIN_SPIN then
			if pending.ok then
				setState("OK")
			else
				setState("FAIL", pending.reason)
			end
			pending = nil
		end
	elseif state == "OK" then
		-- the source opens by itself once the green check has been seen
		if Timer.getTime(stateTimer) >= 1100 then
			proceed()
		end
	end
end

function CFCheck.input(oldPad, pad)
	if not state then
		return
	end
	local function pressed(b)
		return Controls.check(pad, b) and not Controls.check(oldPad, b)
	end
	if state == "CHECKING" then
		if pressed(SCE_CTRL_CIRCLE) or pressed(SCE_CTRL_SQUARE) then
			cancel()
		end
	elseif state == "OK" then
		if pressed(SCE_CTRL_CIRCLE) then
			proceed()
		elseif pressed(SCE_CTRL_SQUARE) then
			cancel()
		end
	elseif state == "FAIL" then
		if pressed(SCE_CTRL_CROSS) then
			startProbe(true)
		elseif pressed(SCE_CTRL_TRIANGLE) then
			local started = false
			if VitaSurf and Settings.VitaSurfBridge ~= false and VitaSurf.installed() then
				local ok, msg = VitaSurf.open(site)
				started = ok
				if not ok then
					setState("FAIL", msg)
				end
			end
			if not started then
				-- VitaSurf not installed: the Vita's own browser does the same job
				if Browser and Browser.openPage then
					Browser.openPage(site)
				end
				setState("FAIL", "Pass the check in the browser, close it, open the source again")
			end
		elseif pressed(SCE_CTRL_CIRCLE) then
			proceed()
		elseif pressed(SCE_CTRL_SQUARE) then
			cancel()
		end
	end
end

----------------------------------------------------------------------------- drawing

local function disc(cx, cy, r, color)
	for dy = -r, r do
		local half = math.sqrt(math.max(r * r - dy * dy, 0))
		Graphics.fillRect(cx - half, cx + half, cy + dy, cy + dy + 1, color)
	end
end

local function thickLine(x1, y1, x2, y2, size, color)
	local steps = math.max(math.abs(x2 - x1), math.abs(y2 - y1))
	for i = 0, steps do
		local x = x1 + (x2 - x1) * i / steps
		local y = y1 + (y2 - y1) * i / steps
		Graphics.fillRect(x - size / 2, x + size / 2, y - size / 2, y + size / 2, color)
	end
end

local function centered(font, y, text, color)
	Font.print(font, 480 - Font.getTextWidth(font, text) / 2, y, text, color)
end

function CFCheck.draw()
	if not state then
		return
	end
	local a = math.min(1, Timer.getTime(openTimer) / 150)
	local w, h = 560, 250
	local x0, y0 = 480 - w / 2, 272 - h / 2
	Graphics.fillRect(0, 960, 0, 544, Color.new(0, 0, 0, 180 * a))
	Graphics.fillRect(x0, x0 + w, y0, y0 + h, Color.new(30, 32, 38, 255 * a))

	local accent = Color.new(65, 105, 226, 255 * a)
	local cx, cy = 480, y0 + 105
	local t = Timer.getTime(stateTimer)
	local title, sub, hint

	if state == "CHECKING" then
		accent = Color.new(65, 105, 226, 255 * a)
		local now = Timer.getTime(GlobalTimer) / 1000
		for i = 0, 9 do
			local ang = now * 6 - i * 0.55
			local alpha = (1 - i / 10) * 255 * a
			Graphics.drawImage(cx + math.cos(ang) * 26 - 6, cy + math.sin(ang) * 26 - 6, CircleIcon.e, Color.new(255, 255, 255, alpha))
		end
		title = "Checking site..."
		sub = step ~= "" and step or ("Connecting to " .. tostring(host))
		hint = "Circle: cancel"
	elseif state == "OK" then
		local green = Color.new(46, 184, 92, 255 * a)
		accent = green
		local k = math.min(1, t / 220)
		disc(cx, cy, 34 * k, green)
		if k >= 1 then
			local white = Color.new(255, 255, 255, 255 * a)
			thickLine(cx - 14, cy + 1, cx - 5, cy + 11, 6, white)
			thickLine(cx - 5, cy + 11, cx + 15, cy - 11, 6, white)
		end
		title = "Site connected"
		sub = info ~= "" and info or tostring(host)
		hint = "Opening the source...   Circle: open now"
	else
		local red = Color.new(214, 69, 69, 255 * a)
		accent = red
		local k = math.min(1, t / 220)
		disc(cx, cy, 34 * k, red)
		if k >= 1 then
			local white = Color.new(255, 255, 255, 255 * a)
			thickLine(cx - 12, cy - 12, cx + 12, cy + 12, 6, white)
			thickLine(cx + 12, cy - 12, cx - 12, cy + 12, 6, white)
		end
		title = "Couldn't read the site"
		sub = reason
		hint = "Cross: retry   Triangle: " .. ((VitaSurf and Settings.VitaSurfBridge ~= false and VitaSurf.installed()) and "VitaSurf" or "browser") .. "   Circle: open anyway   Square: cancel"
	end

	Graphics.fillRect(x0, x0 + w, y0, y0 + 4, accent)
	centered(FONT26, cy + 48, title, Color.new(255, 255, 255, 255 * a))
	centered(FONT16, cy + 84, sub or "", Color.new(170, 170, 170, 255 * a))
	centered(FONT16, y0 + h - 30, hint, Color.new(120, 160, 255, 255 * a))
end

-- settings text
for _, lang in pairs(Language) do
	if lang.SETTINGS then
		lang.SETTINGS.CFCheck = "Check site when opened"
		lang.SETTINGS_DESCRIPTION = lang.SETTINGS_DESCRIPTION or {}
		lang.SETTINGS_DESCRIPTION.CFCheck = "Read the site (like a browser) before a source opens"
	end
end
