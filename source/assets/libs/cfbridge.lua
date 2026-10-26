-- cfbridge.lua : Cloudflare bridge for NOBORU
--
-- The Vita can't pass a Cloudflare check. vitaserver.py on your PC can (CFBridge.exe saves the
-- cookies), so requests to Cloudflare-protected sites are sent through the PC:
--     http://<pc>:8080/api/fetch?url=<encoded link>
--
-- * Sites listed in ux0:data/noboru/cfbridge.lua (pushed by the PC server) go through the PC at once.
-- * Any other site that answers with a Cloudflare check page is learned automatically and retried
--   through the PC (and remembered).
-- * Settings > Network > Cloudflare via PC:  AUTO (default) / OFF.
-- The PC address is the same one the "PC Server" source uses (ux0:data/noboru/vitaserver.lua).

local SYS = RK_SYS
local ADDR_PATH = "ux0:data/noboru/vitaserver.lua"
local HOSTS_PATH = "ux0:data/noboru/cfbridge.lua"

local hosts = {}
local base = nil
local loaded = false

local function urlenc(s)
	return (tostring(s):gsub("[^%w%-_%.~]", function(c)
		return string.format("%%%02X", c:byte())
	end))
end

local function hostOf(link)
	local h = link:match("^https?://([^/:%?#]+)")
	if not h then
		return nil
	end
	h = h:lower()
	return (h:gsub("^www%.", ""))
end

local function readTable(path)
	if SYS.doesFileExist(path) then
		local ok, t = pcall(dofile, path)
		if ok and type(t) == "table" then
			return t
		end
	end
	return nil
end

local function saveHosts()
	local parts = {}
	for h in pairs(hosts) do
		parts[#parts + 1] = string.format("%q", h)
	end
	table.sort(parts)
	local s = "return {hosts={" .. table.concat(parts, ",") .. "}}"
	if SYS.doesFileExist(HOSTS_PATH) then
		SYS.deleteFile(HOSTS_PATH)
	end
	local fh = SYS.openFile(HOSTS_PATH, FCREATE)
	SYS.writeFile(fh, s, #s)
	SYS.closeFile(fh)
end

---Re-reads the PC address and the site list from the Vita's storage
function CFBridgeReload()
	base = nil
	local a = readTable(ADDR_PATH)
	if a and type(a.url) == "string" and a.url:match("^http://") then
		base = (a.url:gsub("/+$", ""))
	end
	local h = readTable(HOSTS_PATH)
	hosts = {}
	if h and type(h.hosts) == "table" then
		for _, name in ipairs(h.hosts) do
			if type(name) == "string" then
				hosts[name:lower():gsub("^www%.", "")] = true
			end
		end
	end
	loaded = true
end

local function enabled()
	return Settings and Settings.CFBridge ~= "off"
end

local function isCfHost(host)
	if not host then
		return false
	end
	while host do
		if hosts[host] then
			return true
		end
		host = host:match("^[^%.]+%.(.+%..+)$") -- try the parent domain
	end
	return false
end

---@param link string  plain (unescaped) link
---@param method any   HttpMethod of the request
---@param post string  POST data
---@param ctype string POST content type
---@param force boolean skip the host check (used after a Cloudflare page was seen)
---@return string | nil  link on the PC server, or nil when the request should go out normally
function CFBridgeRewrite(link, method, post, ctype, force)
	if not loaded then
		CFBridgeReload()
	end
	if not base or not enabled() or type(link) ~= "string" then
		return nil
	end
	if link:sub(1, #base) == base then
		return nil -- already talking to the PC
	end
	local host = hostOf(link)
	if not host or not (force or isCfHost(host)) then
		return nil
	end
	local out = base .. "/api/fetch?url=" .. urlenc(link)
	if post and post ~= "" then
		out = out .. "&post=" .. urlenc(post)
		if ctype and ctype ~= "" then
			out = out .. "&ct=" .. urlenc(ctype)
		end
	end
	return out
end

---True when a downloaded page is a Cloudflare "checking your browser" page
function CFBridgeIsChallenge(body)
	if type(body) ~= "string" or #body == 0 or #body > 80000 then
		return false
	end
	if body:find("Just a moment...", 1, true) or body:find("cf-browser-verification", 1, true)
		or body:find("challenge-platform", 1, true) or body:find("cf_chl_opt", 1, true)
		or body:find("Attention Required! | Cloudflare", 1, true) then
		return true
	end
	return false
end

---Remembers a host as Cloudflare-protected (saved on the Vita)
function CFBridgeLearn(link)
	local host = hostOf(link or "")
	if host and not hosts[host] then
		hosts[host] = true
		saveHosts()
		if Notifications and Notifications.push then
			Notifications.push("Cloudflare site: using PC for " .. host)
		end
	end
end

---Is the PC address known? (for messages)
function CFBridgeReady()
	if not loaded then
		CFBridgeReload()
	end
	return base ~= nil and enabled()
end

-- setting label in every language
for _, lang in pairs(Language) do
	if lang.SETTINGS then
		lang.SETTINGS.CFBridge = "Cloudflare via PC"
	end
end
