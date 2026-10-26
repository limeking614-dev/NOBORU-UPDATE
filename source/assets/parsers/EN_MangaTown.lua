MangaTown=Parser:new("MangaTown","https://www.mangatown.com","ENG","MANGATOWNEN",4)MangaTown.Filters={{Name="Demographic",Type="radio",Tags={"Show All","Shounen","Seinen","Shoujo","Yaoi","Shoujo Ai","Josei","Shounen Ai","Yuri"}},{Name="Genres",Type="checkcross",Tags={"4 Koma","Action","Adventure","Comedy","Cooking","Doujinshi","Drama","Ecchi","Fantasy","Gender Bender","Harem","Historical","Horror","Josei","Lolicon","Martial Arts","Mature","Mecha","Music","Mystery","One Shot","Psychological","Reverse Harem","Romance","School Life","Sci Fi","Sci-fi","Seinen","Shotacon","Shoujo","Shoujo Ai","Shounen","Shounen Ai","Slice Of Life","Smut","Sports","Supernatural","Suspense","Tragedy","Vampire","Webtoons","Youkai","4 Koma","Action","Adventure","Comedy","Cooking","Doujinshi","Drama","Ecchi","Fantasy","Gender Bender","Harem","Historical","Horror","Josei","Lolicon","Martial Arts","Mature","Mecha","Music","Mystery","One Shot","Psychological","Reverse Harem","Romance","School Life","Sci Fi","Sci-fi","Seinen","Shotacon","Shoujo","Shoujo Ai","Shounen","Shounen Ai","Slice Of Life","Smut","Sports","Supernatural","Suspense","Tragedy","Vampire","Webtoons","Youkai"}},{Name="Completed Series",Type="radio",Tags={"Show All","Yes","No"}}}MangaTown.DemogKeys={["Shounen"]="SHOUNEN",["Seinen"]="SEİNEN",["Shoujo"]="SHOUJO",["Yaoi"]="YAOİ",["Shoujo Ai"]="SHOUJO Aİ",["Josei"]="JOSEİ",["Shounen Ai"]="SHOUNEN Aİ",["Yuri"]="YURİ",["Show All"]=""}MangaTown.Completed={["Yes"]="1",["No"]="0",["Show All"]=""}local function a(string)return string:gsub("&#([^;]-);",function(b)local c=tonumber("0"..b)or tonumber(b)return c and u8c(c)or"&#"..b..";"end):gsub("&(.-);",function(b)return HTML_entities and HTML_entities[b]and u8c(HTML_entities[b])or"&"..b..";"end)end;local function d(e)local f={}Threads.insertTask(f,{Type="StringRequest",Link=e,Table=f,Index="text"})while Threads.check(f)do coroutine.yield(false)end;return f.text or""end;function MangaTown:getManga(e,g)local h=d(e)g.NoPages=true;for i,j,k in h:gmatch('cover".-src="([^"]-)".-href="([^"]-)" title="([^>]-)">')do g[#g+1]=CreateManga(a(k),j,{Link=i,Header1="Referer: https://www.mangatown.com"},self.ID,self.Link..j)g.NoPages=false;coroutine.yield(false)end end;function MangaTown:getPopularManga(l,g)self:getManga(self.Link.."/hot/"..l..".htm",g)end;function MangaTown:getLatestManga(l,g)self:getManga(self.Link.."/new/"..l..".htm",g)end;function MangaTown:searchManga(m,l,g,n)local o="page="..l.."&name="..m;if n then local p=n["Genres"]local q=n["Demographic"]local r=n["Completed Series"]if p then for s,t in ipairs(p.include)do o=o.."&".."genres%5B"..t:gsub(" ","+").."%5D=1"end;for s,t in ipairs(p.exclude)do o=o.."&".."genres%5B"..t:gsub(" ","+").."%5D=2"end end;if q and self.DemogKeys[q]~=""then o=o.."&".."demographic="..self.DemogKeys[q]:gsub("[^a-zA-Z]",function(b)return string.format("%%%x",string.byte(b))end)end;if r and self.Completed[r]~=""then o=o.."&".."is_completed="..self.Completed[r]end end;self:getManga(self.Link.."/search?"..o,g)end;function MangaTown:getChapters(u,g)
local h=d(self.Link..u.Link)
local function strip(x)return(x:gsub("<[^>]->"," "):gsub("&nbsp;"," "):gsub("%s+"," "):gsub("^%s+",""):gsub("%s+$",""))end
-- summary: the full text in <span id="show">, else the page's meta description
local w=h:match('id="show"[^>]->(.-)<a')or h:match('id="show"[^>]->(.-)</span>')or""
w=strip(w):gsub("HIDE$",""):gsub("%s+$","")
if#w<20 then
w=h:match('<meta[^>]-property="og:description"[^>]-content="([^"]*)"')or h:match('<meta[^>]-name="description"[^>]-content="([^"]*)"')or h:match('<meta[^>]-content="([^"]*)"[^>]-name="description"')or w
end
g.Description=a(w)
local v,seen={},{}
-- every <li> of the chapter list that holds a link ending in /c<number>/
for li in h:gmatch("<li[^>]*>(.-)</li>")do
for tag,inner in li:gmatch("(<a%s[^>]->)(.-)</a>")do
local href=tag:match('href="([^"]-)"')
if href then
href=href:gsub("&amp;","&"):gsub("^https?://[^/]+",""):gsub("^//[^/]+",""):gsub("[?#].*$","")
if href:match("/manga/[^/]+/.*c%d[%d%.]*/?$")and not seen[href]then
seen[href]=true
if href:sub(-1)~="/"then href=href.."/"end
local k=strip(inner)
local rest=li:gsub("<a%s[^>]->.-</a>",""):gsub('<span class="time">.-</span>',""):gsub("<[^>]->"," ")
rest=rest:gsub("&nbsp;"," "):gsub("%s+"," "):gsub("^%s+",""):gsub("%s+$","")
if k==""then k=href:match("(c%d[%d%.]*)/$")or"Chapter"end
if rest~=""then k=k.." - "..rest end
v[#v+1]={Name=a(k),Link=href,Pages={},Manga=u}
end
end
end
end
-- the site lists newest first; NOBORU wants oldest first
for y=#v,1,-1 do g[#g+1]=v[y]end
end;function MangaTown:prepareChapter(z,g)local A=d(self.Link..z.Link.."1.html"):match("total_pages = (.-);")or 0;for y=1,A do g[y]=self.Link..z.Link..y..".html"end end;function MangaTown:loadChapterPage(e,g)
local x=d(e)
local src=x:match('<img[^>]-id="image"[^>]-src="([^"]-)"')or x:match('<img[^>]-src="([^"]-)"[^>]-id="image"')or x:match('img src="([^"]-)"')
if src then
src=src:gsub("&amp;","&")
if src:sub(1,2)=="//"then src=src:sub(3)end
end
g.Link={Link=src,Header1="Referer: https://www.mangatown.com"}
end
