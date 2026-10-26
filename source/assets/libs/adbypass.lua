-- adbypass.lua : skips ad / interstitial / redirect pages
--
-- Some manga sites answer a request with an "ad page" (pop-up wall, "click to continue", meta refresh,
-- a script redirect through an ad network...) instead of the real list. net.lua asks this module about
-- every downloaded page; when it is such a page, the real link is found in it and requested instead
-- (up to 4 hops), so the sources load straight away.
AdBypass = { skipped = 0, last = nil }

local AD_WORDS = {
	"adsterra", "popunder", "pop%-under", "popads", "propellerads", "exoclick", "clickadu", "hilltopads",
	"juicyads", "trafficjunky", "onclickads", "adcash", "monetag", "popcash", "ad%-block", "adblock",
	"disable your ad", "turn off your ad", "whitelist"
}
local CONTINUE_WORDS = {
	"continue", "skip", "proceed", "go to site", "go to website", "click here", "visit site", "enter site",
	"i am human", "get link", "open site", "enter"
}

local function lower(s)
	return (s:lower())
end

local function count(s, pat)
	local _, n = s:gsub(pat, "")
	return n
end

---@param href string
---@param base string  link the page came from
---@return string | nil
local function resolve(href, base)
	if type(href) ~= "string" or href == "" then
		return nil
	end
	href = href:gsub("&amp;", "&"):gsub("\\/", "/"):gsub("\\u002[Ff]", "/")
	href = href:match("^%s*(.-)%s*$")
	local l = href:lower()
	if l:find("^javascript:") or l:find("^mailto:") or l:find("^tel:") or l:sub(1, 1) == "#" or l:find("^data:") then
		return nil
	end
	if href:match("^https?://") then
		return href
	end
	if href:sub(1, 2) == "//" then
		return "https:" .. href
	end
	local origin = base:match("^(https?://[^/]+)")
	if not origin then
		return nil
	end
	if href:sub(1, 1) == "/" then
		return origin .. href
	end
	local dir = (base:gsub("[?#].*$", "")):match("^(.*/)") or (origin .. "/")
	return dir .. href
end

local function hostOf(link)
	local h = tostring(link or ""):match("^https?://([^/:%?#]+)")
	return h and h:lower():gsub("^www%.", "") or nil
end

---Is `body` an ad / redirect page instead of real content?
---@param body string
---@return boolean
function AdBypass.isInterstitial(body)
	if type(body) ~= "string" or #body == 0 or #body > 60000 then
		return false
	end
	local head = body:match("^%s*(.)")
	if head == "{" or head == "[" then
		return false -- json answer
	end
	local l = lower(body)
	if not l:find("<html", 1, true) and not l:find("<body", 1, true) and not l:find("<script", 1, true) and not l:find("<meta", 1, true) then
		return false -- plain text / xml
	end
	local anchors = count(l, "<a%s")
	local imgs = count(l, "<img")
	if l:find("http%-equiv=[\"']?refresh") and anchors <= 6 then
		return true
	end
	if #body < 8000 and anchors <= 4 and (l:find("window%.location") or l:find("location%.replace") or l:find("location%.href%s*=") or l:find("window%.open")) then
		return true
	end
	if anchors < 12 and imgs < 6 then
		for i = 1, #AD_WORDS do
			if l:find(AD_WORDS[i]) then
				return true
			end
		end
		if l:find("click here to continue", 1, true) or l:find("skip ad", 1, true) or l:find("skip this ad", 1, true) or l:find("continue to site", 1, true) or l:find("continue to website", 1, true) or l:find("please wait while", 1, true) then
			return true
		end
	end
	return false
end

---Finds the link that leads past the ad page
---@param body string
---@param link string  link the body came from
---@return string | nil
function AdBypass.nextLink(body, link)
	if type(body) ~= "string" or type(link) ~= "string" then
		return nil
	end
	local own = hostOf(link)
	local cands = {}
	local function add(c)
		local u = resolve(c, link)
		if u and u ~= link then
			cands[#cands + 1] = u
		end
	end
	-- 1. meta refresh
	local meta = body:match("<[Mm][Ee][Tt][Aa][^>]-[Hh][Tt][Tt][Pp]%-[Ee][Qq][Uu][Ii][Vv]=[\"']?[Rr]efresh[^>]->")
	if meta then
		local target = meta:match("[Uu][Rr][Ll]%s*=%s*['\"]?([^'\">%s]+)")
		if target then
			add(target)
		end
	end
	-- 2. script redirects
	for _, pat in ipairs({
		"location%.replace%(%s*[\"']([^\"']+)[\"']",
		"location%.href%s*=%s*[\"']([^\"']+)[\"']",
		"window%.location%s*=%s*[\"']([^\"']+)[\"']",
		"window%.location%.href%s*=%s*[\"']([^\"']+)[\"']",
		"top%.location%s*=%s*[\"']([^\"']+)[\"']"
	}) do
		for target in body:gmatch(pat) do
			add(target)
		end
	end
	-- 3. "continue" style links / buttons
	for tag, inner in body:gmatch("(<a%s[^>]->)(.-)</a>") do
		local text = lower(inner:gsub("<[^>]->", " "))
		for i = 1, #CONTINUE_WORDS do
			if text:find(CONTINUE_WORDS[i], 1, true) then
				local href = tag:match("href=[\"']([^\"']+)[\"']")
				if href then
					add(href)
				end
				break
			end
		end
	end
	for href in body:gmatch("data%-href=[\"']([^\"']+)[\"']") do
		add(href)
	end
	-- prefer targets on the same site, then anything that is not an ad network
	for i = 1, #cands do
		if hostOf(cands[i]) == own then
			return cands[i]
		end
	end
	for i = 1, #cands do
		local l = cands[i]:lower()
		local bad = false
		for j = 1, #AD_WORDS do
			if l:find(AD_WORDS[j]) then
				bad = true
			end
		end
		if not bad then
			return cands[i]
		end
	end
	-- an ad page that only offers ad links: go to the site's own front page
	if own and link:gsub("^https?://[^/]+", "") ~= "" and link:gsub("^https?://[^/]+", "") ~= "/" then
		return (link:match("^(https?://[^/]+)") or "") .. "/"
	end
	return nil
end

---Called by net.lua for each finished page request.
---@return string | nil  link to request instead (when `body` was an ad page)
function AdBypass.check(body, link, hops)
	if (hops or 0) >= 4 or not AdBypass.isInterstitial(body) then
		return nil
	end
	local nxt = AdBypass.nextLink(body, link)
	if nxt and nxt ~= link then
		AdBypass.skipped = AdBypass.skipped + 1
		AdBypass.last = nxt
		return nxt
	end
	return nil
end
