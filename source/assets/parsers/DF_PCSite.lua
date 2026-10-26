-- DF_PCSite.lua  --  one hidden parser per site added in PC SOURCES.
-- The PC is only used to learn WHICH sites you added. Opening a source loads that site's
-- mangas straight from the site (Latest / Popular / Search), exactly like a normal catalog,
-- so the PC does not have to be running. Each site gets its own parser id (PCSITE_<host>) so
-- its lists, history and cache never mix with other sources.
local SERIES = {manga = true, mangas = true, series = true, comic = true, comics = true, webtoon = true, webtoons = true, manhwa = true, manhwas = true, manhua = true, title = true, read = true, project = true, projects = true}
local SKIP = {"logo", "icon", "avatar", "banner", "sprite", "loading", "placeholder", "spinner", "/ads/", "/ad/", "/adv/", "advert", "adsterra", "doubleclick", "googlesyndication", "popunder", "pixel", "blank", "emoji", "favicon"}
local LATEST = {
	"/manga/page/%d/?m_orderby=latest",
	"/page/%d/?s=&post_type=wp-manga&m_orderby=latest",
	"/manga/?page=%d&order=update",
	"/series/?page=%d&order=update",
	"/comics/?page=%d&order=update",
	"/browse/comics?page=%d",
	"/series?page=%d",
	"/comics?page=%d",
	"/manga?page=%d",
	"/series/page/%d/",
	"/comics/page/%d/",
	"/?page=%d"
}
local POPULAR = {
	"/manga/page/%d/?m_orderby=trending",
	"/manga/page/%d/?m_orderby=views",
	"/manga/?page=%d&order=popular",
	"/series/?page=%d&order=popular"
}

local function decode(s)
	if u8c then
		return (s:gsub("&#([^;]-);", function(c)
			local d = tonumber("0" .. c) or tonumber(c)
			return d and u8c(d) or "&#" .. c .. ";"
		end):gsub("&([^;]-);", function(c)
			return HTML_entities and HTML_entities[c] and u8c(HTML_entities[c]) or "&" .. c .. ";"
		end))
	end
	return s
end

local function request(url)
	local t = {}
	Threads.insertTask(t, {Type = "StringRequest", Link = url, Table = t, Index = "string"})
	while Threads.check(t) do
		coroutine.yield(false)
	end
	return t.string or ""
end

local function requestPost(url, data)
	if not POST_METHOD then
		return ""
	end
	local t = {}
	Threads.insertTask(t, {Type = "StringRequest", Link = url, Table = t, Index = "string", HttpMethod = POST_METHOD, PostData = data or "", ContentType = XWWW})
	while Threads.check(t) do
		coroutine.yield(false)
	end
	return t.string or ""
end

local function trim(s)
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function stripTags(s)
	return trim((s:gsub("<[^>]->", " "):gsub("%s+", " ")))
end

local function hostOf(url)
	local h = url:match("^https?://([^/?#]+)")
	if h then
		h = h:lower():gsub("^www%.", "")
	end
	return h
end

local function absolute(href, host)
	href = href:gsub("&amp;", "&")
	if href:match("^https?://") then
		return href
	elseif href:sub(1, 2) == "//" then
		return "https:" .. href
	elseif href:sub(1, 1) == "/" then
		return "https://" .. host .. href
	end
	return nil
end

local function imgSrc(tag, host)
	local src = tag:match('data%-src="([^"]+)"') or tag:match('data%-lazy%-src="([^"]+)"') or tag:match('data%-original="([^"]+)"') or tag:match('data%-cfsrc="([^"]+)"') or tag:match('data%-wpfc%-original%-src="([^"]+)"') or tag:match('data%-lazy="([^"]+)"') or tag:match('data%-orig%-file="([^"]+)"') or tag:match('src="([^"]+)"')
	if not src or src:sub(1, 5) == "data:" then
		src = tag:match('srcset="([^"%s,]+)') or tag:match('data%-srcset="([^"%s,]+)')
	end
	if src and src:sub(1, 5) == "data:" then
		src = nil
	end
	return src and absolute(src, host) or nil
end

local function skipImage(url)
	local l = url:lower()
	for i = 1, #SKIP do
		if l:find(SKIP[i], 1, true) then
			return true
		end
	end
	return false
end

-- series cards of a listing page; appends manga to t, returns how many were new
local function readCards(self, html, t, seen)
	local host = self.Host
	local order, cards = {}, {}
	for href, inner in html:gmatch('<a%s[^>]-href="([^"]-)"[^>]->(.-)</a>') do
		local full = absolute(href, host)
		if full and hostOf(full) == host then
			full = full:gsub("[?#].*$", "")
			local path = full:match("^https?://[^/]+(/.*)$") or ""
			local lp = path:lower()
			local segs = {}
			for s in path:gmatch("[^/]+") do
				segs[#segs + 1] = s
			end
			if #segs >= 2 and SERIES[segs[1]:lower()] and not lp:find("chapter", 1, true) and not lp:find("/page/", 1, true) and not segs[#segs]:match("^%d+$") then
				local key = full:gsub("/+$", "")
				local c = cards[key]
				if not c then
					c = {url = full, title = "", cover = nil}
					cards[key] = c
					order[#order + 1] = key
				end
				local img = inner:match("<img[^>]->")
				if img then
					local src = imgSrc(img, host)
					if src and not c.cover and not skipImage(src) then
						c.cover = src
					end
					if c.title == "" then
						c.title = img:match('alt="([^"]*)"') or ""
					end
				end
				if c.title == "" then
					local ti = href and trim(inner:match('title="([^"]*)"') or "")
					local text = stripTags(inner):gsub("%s+%d+%.%d+$", "")
					if #text > 2 and not text:lower():match("^chapter") then
						c.title = text
					elseif ti ~= "" then
						c.title = ti
					end
				end
			end
		end
	end
	local count = 0
	for i = 1, #order do
		local c = cards[order[i]]
		if c.cover and not seen[order[i]] then
			seen[order[i]] = true
			local title = c.title
			if title == "" then
				title = (c.url:match("([^/]+)/*$") or "?"):gsub("%-", " ")
			end
			t[#t + 1] = CreateManga(decode(title), c.url, (c.cover:gsub("%%", "%%%%")), self.ID, c.url, c.url)
			count = count + 1
			coroutine.yield(false)
		end
	end
	return count
end

-- which list layouts to try first for each kind of site (indexes into LATEST / POPULAR)
local ENGINE_FIRST = {
	madara = {latest = {1, 2}, popular = {1, 2}},
	themesia = {latest = {3, 4, 5}, popular = {3, 4}},
	nextjs = {latest = {7, 6, 8}, popular = {}}
}

local function loadListing(self, patterns, field, page, t)
	local order = {}
	if self[field] then
		order[1] = self[field]
	else
		local used = {}
		local pref = ENGINE_FIRST[self.Engine or ""]
		pref = pref and pref[patterns == LATEST and "latest" or "popular"]
		for _, i in ipairs(pref or {}) do
			if patterns[i] and not used[i] then
				used[i] = true
				order[#order + 1] = i
			end
		end
		for i = 1, #patterns do
			if not used[i] then
				order[#order + 1] = i
			end
		end
	end
	for _, idx in ipairs(order) do
		local url = "https://" .. self.Host .. patterns[idx]:format(page)
		local html = request(url)
		if html ~= "" then
			local part = {}
			local n = readCards(self, html, part, {})
			if n > 0 then
				self[field] = idx
				for i = 1, #part do
					t[#t + 1] = part[i]
				end
				t.NoPages = false
				return true
			end
		end
	end
	return false
end

PCSITE_CREATED = PCSITE_CREATED or {}
local created = PCSITE_CREATED

function PCSiteParser(host)
	host = (host or ""):lower():gsub("^https?://", ""):gsub("^www%.", ""):gsub("/.*$", "")
	if host == "" then
		return nil
	end
	if created[host] then
		return created[host]
	end
	local P = Parser:new(host, "https://" .. host, "DIF", "PCSITE_" .. host, 1)
	P.Host = host
	P.Hidden = true
	created[host] = P
	-- what the app learned about this site earlier (engine, name from the online lists)
	if SiteProfile then
		SiteProfile.apply(P, SiteProfile.get(host))
	end

	function P:getLatestManga(page, t)
		t.NoPages = true
		loadListing(self, LATEST, "latestPattern", page, t)
	end

	function P:getPopularManga(page, t)
		t.NoPages = true
		if not loadListing(self, POPULAR, "popularPattern", page, t) and page == 1 then
			loadListing(self, LATEST, "latestPattern", page, t)
		end
	end

	function P:searchManga(query, page, t)
		t.NoPages = true
		local q = query:gsub("[^%w%-_%.~%%]", function(c)
			return string.format("%%%02X", c:byte())
		end)
		local tries = {
			"/page/" .. page .. "/?s=" .. q .. "&post_type=wp-manga",
			"/page/" .. page .. "/?s=" .. q,
			"/search?q=" .. q .. "&page=" .. page,
			"/search?keyword=" .. q .. "&page=" .. page
		}
		for i = 1, #tries do
			local html = request("https://" .. self.Host .. tries[i])
			if html ~= "" and readCards(self, html, t, {}) > 0 then
				t.NoPages = false
				return
			end
		end
	end

	-- true for premium / locked / early-access entries (they can't be read without paying)
	local function isPremium(tag, inner)
		local l = (tag .. " " .. inner):lower()
		if l:find("premium", 1, true) or l:find("locked", 1, true) or l:find("early access", 1, true) or l:find("unlock", 1, true) then
			return true
		end
		return l:find("[^%a]lock[^%a]") ~= nil or l:find("%-lock%-") ~= nil or l:find("[^%a]coins?[^%a]") ~= nil
	end

	local function isChapterPath(path)
		local l = path:lower()
		if l:find("/page/", 1, true) or l:find("/feed", 1, true) or l:find("/tag/", 1, true) or l:find("/genre", 1, true) then
			return false
		end
		return l:find("chapter", 1, true) ~= nil or l:find("/ch[%-_%.]?%d") ~= nil or l:find("/episode") ~= nil or l:find("/ep[%-_%.]?%d") ~= nil or l:find("/c%d") ~= nil or l:find("/read/", 1, true) ~= nil
	end

	local function summaryOf(html)
		local candidates = {}
		local after = html:match("[Ss]ynopsis%s*</h%d>%s*(.-)<h%d") or html:match("[Ss]ummary%s*</h%d>%s*(.-)<h%d")
		if after then
			candidates[#candidates + 1] = after
		end
		for _, pat in ipairs({
			'class="[^"]-summary__content[^"]-"[^>]*>(.-)</div>',
			'class="[^"]-description%-summary[^"]-"[^>]*>(.-)</div>',
			'class="[^"]-manga%-excerpt[^"]-"[^>]*>(.-)</div>',
			'itemprop="description"[^>]*>(.-)</div>',
			'id="description"[^>]*>(.-)</div>',
			'id="synopsis"[^>]*>(.-)</div>',
			'class="[^"]-synopsis[^"]-"[^>]*>(.-)</div>',
			'class="[^"]-description[^"]-"[^>]*>(.-)</div>',
			'class="[^"]-summary[^"]-"[^>]*>(.-)</div>'
		}) do
			local m = html:match(pat)
			if m then
				candidates[#candidates + 1] = m
			end
		end
		for _, tag in ipairs({'property="og:description"', 'name="description"', 'name="twitter:description"'}) do
			local m = html:match('<meta[^>]-' .. tag .. '[^>]-content="([^"]*)"') or html:match('<meta[^>]-content="([^"]*)"[^>]-' .. tag)
			if m then
				candidates[#candidates + 1] = m
			end
		end
		for i = 1, #candidates do
			local text = decode(stripTags(candidates[i]))
			if #text > 25 then
				return text
			end
		end
		return ""
	end

	-- chapters found in one piece of html (a series page or an ajax answer); returns a list newest-first as on the site
	local function chaptersIn(self, html, manga, seen)
		local list = {}
		local own = manga.Link:gsub("[?#].*$", ""):gsub("/+$", "")
		for tag, href, inner in html:gmatch('(<a%s[^>]-href="([^"]-)"[^>]->)(.-)</a>') do
			local full = absolute(href, self.Host)
			if full and hostOf(full) == self.Host then
				full = full:gsub("[?#].*$", "")
				local path = full:match("^https?://[^/]+(/.*)$") or ""
				if full:gsub("/+$", "") ~= own and isChapterPath(path) and not seen[full] then
					seen[full] = true
					if not isPremium(tag, inner) then
						local name = stripTags(inner)
						name = name:gsub("%s+%d+%s+%a+%s+ago$", ""):gsub("%s+last%s+%a+$", ""):gsub("%s+yesterday$", ""):gsub("%s+today$", ""):gsub("%s+just now$", "")
						if name == "" then
							name = (full:match("([^/]+)/*$") or "Chapter"):gsub("%-", " ")
						end
						list[#list + 1] = {Name = decode(name), Link = full, Pages = {}, Manga = manga}
					end
				end
			end
		end
		return list
	end

	function P:getChapters(manga, t)
		local url = manga.Link
		local html = request(url)
		t.Description = summaryOf(html)
		local seen = {}
		local list = chaptersIn(self, html, manga, seen)
		if #list == 0 then
			-- Madara sites load the chapter list with ajax: POST <series>/ajax/chapters/
			local base = url:gsub("[?#].*$", ""):gsub("/+$", "")
			list = chaptersIn(self, requestPost(base .. "/ajax/chapters/", ""), manga, seen)
			if #list == 0 then
				-- older Madara: admin-ajax.php needs the numeric id of the series
				local id = html:match('data%-id="(%d+)"') or html:match('"manga_id"%s*:%s*"?(%d+)') or html:match("postid%-(%d+)")
				if id then
					list = chaptersIn(self, requestPost("https://" .. self.Host .. "/wp-admin/admin-ajax.php", "action=manga_get_chapters&manga=" .. id), manga, seen)
				end
			end
		end
		-- most sites list newest first; keep the order if the list already counts upwards
		local first = #list > 0 and tonumber(list[1].Name:match("(%d+%.?%d*)")) or nil
		local last = #list > 0 and tonumber(list[#list].Name:match("(%d+%.?%d*)")) or nil
		if first and last and first < last then
			for i = 1, #list do
				t[#t + 1] = list[i]
			end
		else
			for i = #list, 1, -1 do
				t[#t + 1] = list[i]
			end
		end
	end

	function P:prepareChapter(chapter, t)
		local html = request(chapter.Link)
		-- the site's own logo / menu pictures live in the header, footer and menus: never pages
		local body = html:gsub("<[Hh][Ee][Aa][Dd][Ee][Rr].-</[Hh][Ee][Aa][Dd][Ee][Rr]>", " "):gsub("<[Ff][Oo][Oo][Tt][Ee][Rr].-</[Ff][Oo][Oo][Tt][Ee][Rr]>", " "):gsub("<[Nn][Aa][Vv][%s>].-</[Nn][Aa][Vv]>", " "):gsub("<[Aa][Ss][Ii][Dd][Ee].-</[Aa][Ss][Ii][Dd][Ee]>", " ")
		local strong, weak, seen = {}, {}, {}
		for tag in body:gmatch("<img[^>]->") do
			local src = imgSrc(tag, self.Host)
			if src and not seen[src] and not skipImage(src) then
				seen[src] = true
				local lower = src:lower()
				if tag:find("wp-manga-chapter-img", 1, true) or lower:find("/chapters/", 1, true) or lower:find("/chapter/", 1, true) or lower:find("wp-manga/data", 1, true) then
					strong[#strong + 1] = src
				elseif lower:find("%.jpe?g") or lower:find("%.png") or lower:find("%.webp") then
					weak[#weak + 1] = src
				end
			end
		end
		-- pages listed inside the page's scripts (reader scripts such as ts_reader, Next.js data ...)
		local raw = html:gsub("\\u002[Ff]", "/"):gsub("\\/", "/"):gsub("&amp;", "&")
		local listed, scripted = {}, {}
		local dedupe = {}
		local arr = raw:match('"images"%s*:%s*(%b[])')
		if arr then
			for src in arr:gmatch('"(https?://[^"]+)"') do
				if not dedupe[src] and not skipImage(src) then
					dedupe[src] = true
					listed[#listed + 1] = src
				end
			end
		end
		local function scriptScan()
			for src in raw:gmatch("https?://[^\"'%s<>\\]+%.%a%a%a%a?") do
				local l = src:lower()
				if (l:find("%.jpe?g$") or l:find("%.png$") or l:find("%.webp$") or l:find("%.avif$")) and not skipImage(src) and not l:find("thumb", 1, true) and not l:find("cover", 1, true) and not dedupe[src] then
					dedupe[src] = true
					scripted[#scripted + 1] = src
				end
			end
			return scripted
		end
		-- a chapter has many pages: a single picture is the site's logo / a loading image, not the chapter
		local use = {}
		if #strong >= 2 then
			use = strong
		elseif #listed >= 1 then
			use = listed
		elseif #strong == 1 then
			use = strong
		elseif #weak >= 2 then
			use = weak
		else
			local s = scriptScan()
			if #s >= 2 then
				use = s
			elseif #s == 1 then
				use = s
			else
				use = weak
			end
		end
		for i = 1, #use do
			t[#t + 1] = (use[i]:gsub("%%", "%%%%"))
		end
	end

	function P:loadChapterPage(link, t)
		t.Link = link
	end

	return P
end
