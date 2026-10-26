-- siteprofile.lua : "site profiles" - what the app learns about a site when it is added / checked
--
--  1. ENGINE   the site's page is fingerprinted (Madara, MangaThemesia / MangaReader, Next.js ...) and the
--              source then tries that engine's list / search / chapter layouts FIRST, so it loads better.
--  2. ONLINE   the Aidoku community source list on GitHub (and any other source-list URLs you put in
--              ux0:data/noboru/profile_sources.txt, one per line) is read, in the app, to find the site:
--              its proper name, language and content rating are filled in.
--
-- Aidoku sources themselves are compiled WebAssembly, which the Vita can't run - only the published
-- list DATA is used. Profiles are saved on the Vita (ux0:data/noboru/siteprofiles.lua), so the web is
-- only asked once per site (Cross on the check screen asks again).
SiteProfile = {}

local SYS = RK_SYS
local PATH = "ux0:data/noboru/siteprofiles.lua"
local LISTS_PATH = "ux0:data/noboru/profile_sources.txt"
local DEFAULT_LISTS = {
	"https://aidoku-community.github.io/sources/index.min.json"
}
local ONLINE_TIMEOUT = 15000 -- ms per list

local profiles = nil

local function normHost(host)
	host = tostring(host or ""):lower():gsub("^https?://", ""):gsub("^www%.", ""):gsub("[/?#].*$", "")
	return host
end

local function load()
	if profiles then
		return
	end
	profiles = {}
	if SYS.doesFileExist(PATH) then
		local ok, t = pcall(dofile, PATH)
		if ok and type(t) == "table" then
			profiles = t
		end
	end
end

local function save()
	local parts = {}
	for host, p in pairs(profiles) do
		local f = {}
		for _, k in ipairs({"engine", "name", "lang", "id"}) do
			if type(p[k]) == "string" and p[k] ~= "" then
				f[#f + 1] = string.format("%s=%q", k, p[k])
			end
		end
		if p.rating then
			f[#f + 1] = "rating=" .. tostring(tonumber(p.rating) or 0)
		end
		if p.online then
			f[#f + 1] = "online=true"
		end
		if p.aidoku then
			f[#f + 1] = "aidoku=true"
		end
		parts[#parts + 1] = string.format("[%q]={%s}", host, table.concat(f, ","))
	end
	table.sort(parts)
	local s = "return {" .. table.concat(parts, ",") .. "}"
	if SYS.doesFileExist(PATH) then
		SYS.deleteFile(PATH)
	end
	local fh = SYS.openFile(PATH, FCREATE)
	SYS.writeFile(fh, s, #s)
	SYS.closeFile(fh)
end

---@return table | nil
function SiteProfile.get(host)
	load()
	return profiles[normHost(host)]
end

---Names / language from a profile go onto the parser object
function SiteProfile.apply(parser, p)
	if not parser or not p then
		return
	end
	parser.Engine = p.engine
	if p.name and p.name ~= "" then
		parser.Name = p.name
	end
end

---@param body string  front page of the site
---@return string  "madara" | "themesia" | "nextjs" | "unknown"
function SiteProfile.engineOf(body)
	local l = tostring(body or ""):lower()
	if l:find("wp-manga", 1, true) or l:find("manga_get_chapters", 1, true) or l:find("themes/madara", 1, true) or l:find("madara", 1, true) then
		return "madara"
	end
	if l:find("ts_reader", 1, true) or l:find("themesia", 1, true) or l:find("class=\"listupd", 1, true) or l:find("mangareader", 1, true) or l:find("class=\"bsx", 1, true) then
		return "themesia"
	end
	if l:find("__next_data__", 1, true) or l:find("/_next/static", 1, true) then
		return "nextjs"
	end
	return "unknown"
end

---Fingerprints the site and remembers it. Returns the engine name.
function SiteProfile.detect(host, body, parser)
	load()
	host = normHost(host)
	local p = profiles[host] or {}
	p.engine = SiteProfile.engineOf(body)
	profiles[host] = p
	save()
	SiteProfile.apply(parser, p)
	return p.engine
end

---Forget what the web said, so the next check asks it again
function SiteProfile.forgetOnline(host)
	load()
	local p = profiles[normHost(host)]
	if p then
		p.online = nil
	end
end

local function fetchText(url)
	local t = {}
	local timer = Timer.new()
	Threads.insertTask(t, {Type = "StringRequest", Link = url, Table = t, Index = "string"})
	while Threads.check(t) do
		if Timer.getTime(timer) > ONLINE_TIMEOUT then
			Threads.remove(t)
			Timer.destroy(timer)
			return ""
		end
		coroutine.yield()
	end
	Timer.destroy(timer)
	return t.string or ""
end

local function field(obj, key)
	return obj:match('"' .. key .. '"%s*:%s*"([^"]*)"')
end

local function squash(s)
	return (tostring(s or ""):lower():gsub("[^%w]", ""))
end

---Looks `host` up in one downloaded source list. Returns {name, lang, id, rating} or nil.
local function findIn(text, host)
	local label = squash(host:match("^([^%.]+)") or host)
	local arr = text:match('"sources"%s*:%s*(%b[])')
	local function read(obj)
		local name = field(obj, "name")
		local base = (field(obj, "baseURL") or ""):lower()
		local id = field(obj, "id") or ""
		local hit = base:find(host, 1, true) ~= nil or obj:lower():find(host, 1, true) ~= nil
		if not hit and #label >= 4 then
			local sn, si = squash(name), squash(id)
			hit = sn == label or si == label or si:sub(-#label) == label
		end
		if hit and name then
			return {
				name = name,
				id = id,
				lang = obj:match('"languages"%s*:%s*%[%s*"([^"]*)"') or field(obj, "lang") or "",
				rating = tonumber(obj:match('"contentRating"%s*:%s*(%d+)'))
			}
		end
		return nil
	end
	if arr then
		for obj in arr:sub(2, -2):gmatch("%b{}") do
			local r = read(obj)
			if r then
				return r
			end
		end
		return nil
	end
	-- an unknown list layout: look at the text around the first mention of the host
	local at = text:lower():find(host, 1, true)
	if at then
		local from = text:sub(1, at):match(".*(){") or math.max(1, at - 300)
		return read(text:sub(from, at + 400))
	end
	return nil
end

---Reads the online source lists. Runs inside the checker's coroutine (it yields while downloading).
---@param step function  called with the text to show on the check screen
---@return table | nil  the profile
function SiteProfile.online(host, parser, step)
	load()
	host = normHost(host)
	local p = profiles[host] or {}
	profiles[host] = p
	if p.online or Settings.SiteProfiles == false then
		return p
	end
	local lists = {}
	for i = 1, #DEFAULT_LISTS do
		lists[#lists + 1] = DEFAULT_LISTS[i]
	end
	if SYS.doesFileExist(LISTS_PATH) then
		local fh = SYS.openFile(LISTS_PATH, FREAD)
		local text = SYS.readFile(fh, SYS.sizeFile and SYS.sizeFile(fh) or 4096) or ""
		SYS.closeFile(fh)
		for line in text:gmatch("[^\r\n]+") do
			line = line:match("^%s*(.-)%s*$")
			if line:match("^https://") then
				lists[#lists + 1] = line
			end
		end
	end
	local reached = false
	for i = 1, #lists do
		if step then
			step("Looking up the site online (" .. i .. "/" .. #lists .. ")")
		end
		local text = fetchText(lists[i])
		if text ~= "" then
			reached = true
			local okFind, r = pcall(findIn, text, host)
			if not okFind then
				r = nil
			end
			text = nil
			if r then
				p.name, p.lang, p.id, p.rating, p.aidoku = r.name, r.lang, r.id, r.rating, true
				break
			end
		end
	end
	if reached then
		p.online = true -- (a list that could not be reached is tried again next time)
	end
	save()
	SiteProfile.apply(parser, p)
	return p
end

---@return string  short text for the check screen, e.g. "Madara, Aidoku: Manhuaus (en)"
function SiteProfile.summary(host)
	local p = SiteProfile.get(host)
	if not p then
		return ""
	end
	local parts = {}
	if p.engine and p.engine ~= "unknown" then
		local names = {madara = "Madara", themesia = "MangaThemesia", nextjs = "Next.js"}
		parts[#parts + 1] = names[p.engine] or p.engine
	end
	if p.aidoku and p.name then
		parts[#parts + 1] = "Aidoku list: " .. p.name .. (p.lang and p.lang ~= "" and (" (" .. p.lang .. ")") or "")
	end
	return table.concat(parts, ", ")
end

for _, lang in pairs(Language) do
	if lang.SETTINGS then
		lang.SETTINGS.SiteProfiles = "Online site profiles (Aidoku list)"
		lang.SETTINGS_DESCRIPTION = lang.SETTINGS_DESCRIPTION or {}
		lang.SETTINGS_DESCRIPTION.SiteProfiles = "When a site is checked, read online source lists to identify it and load it better"
	end
end
