-- EN_AsuraScans.lua  --  direct (no PC needed) source for https://asurascans.com
-- v2: * premium / locked chapters are skipped (only free, readable chapters are listed)
--     * the series summary is read from the series page and shown in the details screen
--     * chapter links are taken from the page itself (no guessing of the slug), so the
--       "no chapters" result no longer happens when the site changes its URL layout
AsuraScans = Parser:new("Asura Scans", "https://asurascans.com", "ENG", "ASURASCANSEN", 2)

local SECTIONS = {"comics", "series"}

local function decode(s)
	if u8c then
		return (s:gsub("&#([^;]-);", function(c)
			local d = tonumber("0" .. c) or tonumber(c)
			if not d and c:match("^[xX]%x+$") then
				d = tonumber(c:sub(2), 16)
			end
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

local function trim(s)
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function stripTags(s)
	return trim((s:gsub("<[^>]->", " "):gsub("%s+", " ")))
end

local function absolute(src, link)
	src = src:gsub("&amp;", "&")
	if src:sub(1, 2) == "//" then
		return "https:" .. src
	elseif src:sub(1, 1) == "/" then
		return link .. src
	end
	return src
end

local function imgSrc(self, tag)
	local src = tag:match('data%-src="([^"]+)"') or tag:match('data%-lazy%-src="([^"]+)"') or tag:match('src="([^"]+)"')
	if src and src:sub(1, 5) == "data:" then
		src = nil
	end
	return src and absolute(src, self.Link) or nil
end

-- "/comics/slug-1a2b3c" from any kind of href; nil for other sites / non series links
local function seriesPath(href)
	href = href:gsub("&amp;", "&"):gsub("^https?://[^/]+", ""):gsub("[?#].*$", "")
	for i = 1, #SECTIONS do
		local slug = href:match("^/" .. SECTIONS[i] .. "/([^/]+)/?$")
		if slug and slug ~= "" and slug ~= "page" then
			return "/" .. SECTIONS[i] .. "/" .. slug, slug
		end
	end
	return nil
end

-- cards of a listing page -> appends to t; returns number of cards found
local function readCards(self, html, t, seen)
	local count = 0
	local order = {}
	local cards = {}
	for href, inner in html:gmatch('<a%s[^>]-href="([^"]-)"[^>]->(.-)</a>') do
		local path, slug = seriesPath(href)
		if path then
			local c = cards[path]
			if not c then
				c = {path = path, slug = slug, title = "", cover = nil}
				cards[path] = c
				order[#order + 1] = path
			end
			local img = inner:match("<img[^>]->")
			if img then
				c.cover = c.cover or imgSrc(self, img)
				if c.title == "" then
					c.title = img:match('alt="([^"]*)"') or ""
				end
			end
			if c.title == "" then
				local text = stripTags(inner):gsub("%s+%d+%.%d+$", "")
				if #text > 1 then
					c.title = text
				end
			end
		end
	end
	for i = 1, #order do
		local c = cards[order[i]]
		if c.cover and not seen[c.path] then
			seen[c.path] = true
			local title = c.title
			if title == "" then
				title = c.slug:gsub("%-%x+$", ""):gsub("%-", " ")
			end
			local cover = c.cover:gsub("%%", "%%%%")
			t[#t + 1] = CreateManga(decode(title), c.path, cover, self.ID, self.Link .. c.path)
			count = count + 1
			coroutine.yield(false)
		end
	end
	return count
end

-- old versions of the app saved only the slug; new ones save "/comics/<slug>"
local function mangaPath(manga)
	local l = manga.Link
	if l:sub(1, 1) == "/" then
		return l
	end
	return "/comics/" .. l
end

function AsuraScans:getLatestManga(page, t)
	local html = request(self.Link .. "/browse/comics" .. (page > 1 and ("?page=" .. page) or ""))
	t.NoPages = readCards(self, html, t, {}) == 0
end

function AsuraScans:getPopularManga(page, t)
	-- the home page's trending list (single page)
	local html = request(self.Link .. "/comics")
	readCards(self, html, t, {})
	t.NoPages = true
end

local allTitles = nil

function AsuraScans:searchManga(query, page, t)
	t.NoPages = true
	if page > 1 then
		return
	end
	if not allTitles then
		-- the site only filters with JavaScript, so read every browse page once and filter here
		local all = {}
		local seen = {}
		for p = 1, 30 do
			local part = {}
			local n = readCards(self, request(self.Link .. "/browse/comics" .. (p > 1 and ("?page=" .. p) or "")), part, seen)
			for i = 1, #part do
				all[#all + 1] = part[i]
			end
			if n == 0 then
				break
			end
		end
		if #all == 0 then
			return
		end
		allTitles = all
	end
	local q = query:gsub("%%(%x%x)", function(h)
		return string.char(tonumber(h, 16))
	end):gsub("%+", " "):lower()
	for i = 1, #allTitles do
		local m = allTitles[i]
		if m.Name and m.Name:lower():find(q, 1, true) then
			t[#t + 1] = m
		end
	end
end

---------------------------------------------------------------- summary

local function summaryOf(html)
	local candidates = {}
	-- 1) a "Synopsis" heading followed by its text
	local after = html:match("[Ss]ynopsis%s*</h%d>%s*(.-)<h%d") or html:match("[Ss]ynopsis%s*</h%d>%s*(.-)</section>")
	if after then
		candidates[#candidates + 1] = after
	end
	-- 2) elements named like a description / synopsis
	for _, pat in ipairs({
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
	-- 3) page meta tags
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

---------------------------------------------------------------- chapters

-- true for premium / locked / early-access entries (they can't be read without paying)
local function isPremium(tag, inner)
	local l = (tag .. " " .. inner):lower()
	if l:find("premium", 1, true) or l:find("locked", 1, true) or l:find("early access", 1, true) or l:find("unlock", 1, true) then
		return true
	end
	if l:find("[^%a]lock[^%a]") or l:find("%-lock%-") or l:find("[^%a]coins?[^%a]") then
		return true
	end
	return false
end

function AsuraScans:getChapters(manga, t)
	local path = mangaPath(manga)
	local html = request(self.Link .. path)
	t.Description = summaryOf(html)
	local list, seen = {}, {}
	for tag, href, inner in html:gmatch('(<a%s[^>]-href="([^"]-)"[^>]->)(.-)</a>') do
		local clean = href:gsub("&amp;", "&"):gsub("^https?://[^/]+", ""):gsub("[?#].*$", "")
		local num = clean:match("/chapter[/%-]([^/]+)/?$")
		-- only chapters of this series
		if num and clean:sub(1, #path + 1) == path .. "/" and not seen[clean] then
			seen[clean] = true
			if not isPremium(tag, inner) then
				local name = stripTags(inner)
				name = name:gsub("%s+%d+%s+%a+%s+ago$", ""):gsub("%s+last%s+%a+$", ""):gsub("%s+yesterday$", ""):gsub("%s+just now$", ""):gsub("%s+today$", "")
				if name == "" then
					name = "Chapter " .. (num:gsub("%-", "."))
				end
				list[#list + 1] = {Name = decode(name), Link = clean, Pages = {}, Manga = manga, Number = tonumber((num:gsub("%-", ".")))}
			end
		end
	end
	-- NOBORU wants oldest first. Sort by chapter number when every chapter has one,
	-- otherwise trust the site (newest first) and reverse it.
	local numeric = #list > 0
	for i = 1, #list do
		if not list[i].Number then
			numeric = false
			break
		end
	end
	if numeric then
		for i = 1, #list do
			list[i].Index = i
		end
		table.sort(list, function(a, b)
			if a.Number ~= b.Number then
				return a.Number < b.Number
			end
			return a.Index < b.Index
		end)
		for i = 1, #list do
			t[#t + 1] = list[i]
		end
	else
		for i = #list, 1, -1 do
			t[#t + 1] = list[i]
		end
	end
end

function AsuraScans:prepareChapter(chapter, t)
	local link = chapter.Link
	if link:sub(1, 1) ~= "/" then
		-- old saved format: chapter number only
		link = mangaPath(chapter.Manga) .. "/chapter/" .. link
	end
	local html = request(self.Link .. link)
	local seen = {}
	local function add(src)
		if src and not seen[src] then
			seen[src] = true
			t[#t + 1] = (src:gsub("%%", "%%%%"))
		end
	end
	for tag in html:gmatch("<img[^>]->") do
		local src = imgSrc(self, tag)
		if src and src:find("/chapters/", 1, true) then
			add(src)
		end
	end
	if #t == 0 then
		-- pages that are only listed inside the page's scripts / json
		local raw = html:gsub("\\u002F", "/"):gsub("\\/", "/"):gsub("&amp;", "&")
		for src in raw:gmatch("https?://[^\"'%s<>\\]+/chapters/[^\"'%s<>\\]+%.%a%a%a%a?") do
			add(src)
		end
	end
	if #t == 0 then
		-- last resort: big lazy-loaded images that look like pages
		for tag in html:gmatch("<img[^>]->") do
			local src = imgSrc(self, tag)
			if src then
				local l = src:lower()
				if (l:find("%.webp") or l:find("%.jpe?g") or l:find("%.png")) and not (l:find("logo", 1, true) or l:find("avatar", 1, true) or l:find("icon", 1, true) or l:find("banner", 1, true) or l:find("thumb", 1, true) or l:find("cover", 1, true)) then
					add(src)
				end
			end
		end
	end
end

function AsuraScans:loadChapterPage(link, t)
	t.Link = link
end
