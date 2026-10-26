-- DF_VitaServer.lua  --  "PC Server" source for NOBORU / Rokuru
--
-- Talks to vitaserver.py running on your own PC over plain HTTP (no TLS on the Vita).
-- The PC does all the heavy lifting: it fetches the pages, shrinks them and sends
-- ready-to-show JPEGs, so the Vita only downloads small images.
--
-- Server address is stored in ux0:data/noboru/vitaserver.lua. You can set it by:
--   1) letting vitaserver.py push it to the Vita over VitaShell FTP, or
--   2) opening this source, pressing Search and typing the address shown on the PC
--      (for example  192.168.1.5:8080 ).

local VS = Parser:new("PC Server", "http://pc.server", "DIF", "VITASERVER", 1)

local CFG_PATH = "ux0:data/noboru/vitaserver.lua"
local HEADER = "X-Vita-Reader: 1"
local SETUP_LINK = "vitaserver_setup"
local HELP =
	"1) Run vitaserver.py on your PC (same Wi-Fi as the Vita).\n" ..
	"2) In the PC window press 'Find Vita' and 'Send address', or press Search here and type the address shown on the PC, e.g. 192.168.1.5:8080\n" ..
	"3) Paste any manga link into the PC window and it shows up under this source.\n" ..
	"4) To delete an added site: press Search and type  delete https://vortexscans.org  (or delete <title>, delete all). Or open a manga and tap Delete at the top."

local base = nil

---------------------------------------------------------------- helpers

local function trim(s)
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function urlenc(s)
	return (tostring(s):gsub("[^%w%-_%.~]", function(c)
		return string.format("%%%02X", c:byte())
	end))
end

-- the app hands search text over with "%%XX" escapes and "+" for spaces
local function decodeQuery(q)
	q = q:gsub("%%%%(%x%x)", function(h)
		return string.char(tonumber(h, 16))
	end)
	q = q:gsub("%+", " ")
	return trim(q)
end

---Turns "192.168.1.5", "192.168.1.5:9000" or "http://host:8080/" into "http://host:port".
---Returns nil when the text doesn't look like a server address.
local function parseAddress(q)
	q = trim(q)
	local rest = q:match("^http://(.+)$")
	local explicit = rest ~= nil
	rest = (rest or q):gsub("/+$", "")
	local host, port = rest:match("^(%d+%.%d+%.%d+%.%d+):?(%d*)$")
	if not host and explicit then
		host, port = rest:match("^([%w%.%-]+):?(%d*)$")
	end
	if not host then
		return nil
	end
	if port == "" then
		port = "8080"
	end
	return "http://" .. host .. ":" .. port
end

local function loadBase()
	base = nil
	if RK_SYS.doesFileExist(CFG_PATH) then
		local ok, t = pcall(dofile, CFG_PATH)
		if ok and type(t) == "table" and type(t.url) == "string" and t.url:match("^http://") then
			base = (t.url:gsub("/+$", ""))
		end
	end
	if CFBridgeReload then
		CFBridgeReload()
	end
end

local function saveBase(url)
	local s = "return {url=" .. string.format("%q", url) .. "}"
	if RK_SYS.doesFileExist(CFG_PATH) then
		RK_SYS.deleteFile(CFG_PATH)
	end
	local fh = RK_SYS.openFile(CFG_PATH, FCREATE)
	RK_SYS.writeFile(fh, s, #s)
	RK_SYS.closeFile(fh)
end

local function notify(msg)
	if Notifications and Notifications.push then
		Notifications.push(msg)
	end
end

---Plain-text GET through the app's network queue (must run inside a task coroutine)
local function request(path)
	local t = {}
	Threads.insertTask(t, {
		Type = "StringRequest",
		Link = base .. path,
		Table = t,
		Index = "text",
		Header1 = HEADER
	})
	while Threads.check(t) do
		coroutine.yield(false)
	end
	return t.text or ""
end

---Splits "a<TAB>b<TAB>c" lines
local function eachLine(text, fn)
	for line in text:gmatch("[^\r\n]+") do
		local a, b, c = line:match("^([^\t]*)\t([^\t]*)\t?([^\t]*)")
		if a then
			fn(a, b, c)
		end
	end
end

local function listManga(path, p, page, paged)
	p.NoPages = true
	loadBase()
	if not base then
		if page == 1 then
			p[#p + 1] = CreateManga("[!] Server not set - press Search and type your PC address", SETUP_LINK, "", VS.ID, "")
		end
		return
	end
	local text = request(path)
	local count = 0
	eachLine(text, function(id, title, cover)
		if id ~= "" and id:sub(1, 1) ~= "#" then
			p[#p + 1] = CreateManga(title, id, cover ~= "" and (base .. cover) or "", VS.ID, "")
			count = count + 1
			coroutine.yield(false)
		end
	end)
	if count == 0 and text == "" and page == 1 then
		p[#p + 1] = CreateManga("[!] PC server not reachable - is vitaserver.py running?", SETUP_LINK, "", VS.ID, "")
	end
	if count > 0 and paged then
		p.NoPages = false
	end
end

---------------------------------------------------------------- Parser API

function VS:getPopularManga(page, p)
	listManga("/api/popular?page=" .. (page - 1), p, page, true)
end

---"Latest" = links you pasted on the PC (newest first)
function VS:getLatestManga(page, p)
	-- opened from the PC SOURCES menu: browse that whole site like a normal catalog
	-- (/api/catalog on the PC server). If the PC server has no catalog endpoint yet,
	-- fall back to the manga added from that site.
	local site = ""
	if VitaServerSite and VitaServerSite ~= "" then
		site = "&site=" .. urlenc(VitaServerSite)
		loadBase()
		if base then
			local text = request("/api/catalog?page=" .. (page - 1) .. site)
			local count = 0
			eachLine(text, function(id, title, cover)
				if id ~= "" and id:sub(1, 1) ~= "#" then
					p[#p + 1] = CreateManga(title, id, cover ~= "" and (base .. cover) or "", VS.ID, "")
					count = count + 1
					coroutine.yield(false)
				end
			end)
			if count > 0 then
				p.NoPages = false
				return
			end
			if page > 1 then
				p.NoPages = true
				return
			end
		end
	end
	listManga("/api/latest?page=0" .. site, p, page, false)
end

function VS:searchManga(query, page, p)
	local q = decodeQuery(query)
	local addr = parseAddress(q)
	if addr then
		if page == 1 then
			saveBase(addr)
			notify("PC server set to " .. addr)
		end
		return listManga("/api/latest?page=0", p, page, false)
	end
	loadBase()
	-- "delete https://vortexscans.org" / "delete <title>" / "delete all" removes it from the PC server
	local dq = q:match("^[Dd][Ee][Ll][Ee][Tt][Ee]%s+(.+)$") or q:match("^[Rr][Mm]%s+(.+)$")
	if dq then
		if page == 1 and base then
			local r = request("/api/delete?q=" .. urlenc(trim(dq)))
			local n, names = r:match("^ok\t(%d+)\t(.*)")
			if n then
				notify("Deleted " .. n .. ": " .. names)
			else
				notify("Nothing deleted (not found, or delete is off on the PC)")
			end
		end
		return listManga("/api/latest?page=0", p, page, false)
	end
	if q:match("^https?://") then
		-- a link typed on the Vita: hand it to the PC
		if page == 1 and base then
			request("/api/add?url=" .. urlenc(q))
		end
		return listManga("/api/latest?page=0", p, page, false)
	end
	listManga("/api/search?q=" .. urlenc(q) .. "&page=" .. (page - 1), p, page, true)
end

function VS:getChapters(manga, p)
	loadBase()
	if manga.Link == SETUP_LINK or not base then
		p.Description = HELP
		return
	end
	local text = request("/api/chapters?id=" .. urlenc(manga.Link))
	eachLine(text, function(id, label)
		if id == "#desc" then
			p.Description = label:gsub("\\n", "\n")
		elseif id ~= "" and id:sub(1, 1) ~= "#" then
			p[#p + 1] = { Name = label, Link = id, Pages = {}, Manga = manga }
		end
	end)
end

function VS:prepareChapter(chapter, p)
	loadBase()
	if not base then
		return
	end
	local text = request("/api/pages?id=" .. urlenc(chapter.Link))
	for line in text:gmatch("[^\r\n]+") do
		if line:sub(1, 1) == "/" then
			p[#p + 1] = base .. line
		end
	end
end

function VS:loadChapterPage(link, p)
	p.Link = link
end
