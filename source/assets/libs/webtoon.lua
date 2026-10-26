-- RORUKU Webtoon reader (Aidoku-style continuous vertical scroll)
--
-- * every page is fitted to the screen width and stacked vertically with no gaps
-- * pages are loaded in full (tall strips are sliced by the NOBORU image loader, we just draw the slices)
-- * the whole chapter is queued in reading order (not one image at a time); VRAM decides what stays loaded
-- * when an image finishes loading above the viewport the scroll offset is corrected, so the content never jumps
-- * pulling past the end/start of a chapter continues to the next/previous chapter
Webtoon = {}

local SCREEN_W, SCREEN_H = 960, 544 -- *logical* screen size (544 x 960 when the reader is rotated)
local vertical = false -- "Vertical" reader orientation: the whole view is rotated 90 degrees (full screen strip)
local PI = math.pi
local sub = RK_SUB or string.sub

local MAX_INFLIGHT = 3 -- page requests kept queued at the same time (the net engine runs them in order)
local VRAM_SOFT = 0.80 -- stop requesting more pages above this video-memory fraction
local VRAM_HARD = 0.92 -- start freeing far pages above this fraction
local EST_RATIO = 1.45 -- placeholder height / width until a real image is measured
local FAIL_AFTER_MS = 2500 -- request without any running task for this long = failed
local TRANSITION_H = 200 -- height of the chapter transition panels
local PULL_TRIGGER = 130 -- overscroll needed to continue to the other chapter
local TOP_BAR_H = 56
local BOTTOM_BAR_H = 72
local SLIDER_X1, SLIDER_X2 = 200, 760

local floor, ceil, max, min, abs = math.floor, math.ceil, math.max, math.min, math.abs

local leftIcon = Image:new(Graphics.loadImage("app0:assets/icons/left.png"))
local rightIcon = Image:new(Graphics.loadImage("app0:assets/icons/right.png"))

local active = false
local ctx = nil -- callbacks from reader.lua
local pages = {}
local count = 0
local chapter, chapterNumber, chapterTotal
local manga

local scrollY = 0
local velocity = 0
local over = 0 -- overscroll (negative = pulling at the start, positive = pulling at the end)
local headH = 0
local footH = 0
local contentH = 0
local ratioSum, ratioCount = 0, 0
local currentPage = 1
local targetY = nil

local toolbar = false
local toolbarFade = 0
local counterTimer = Timer.new()
local ticker = Timer.new()

-- touch tracking
local touching = false
local touchStart = { x = 0, y = 0 }
local touchMoved = false
local touchOnBar = false
local touchTimer = Timer.new()
local sliderDrag = false

local heldPad = 0
local overPushed = false -- d-pad / stick pushed against the chapter edge this frame
local pageButtonTimer = Timer.new()
local frame = 0

-- zoom (hold TRIANGLE = zoom in, hold SQUARE = zoom out; touch drag / d-pad left-right pans while zoomed in)
local ZOOM_MIN, ZOOM_MAX = 0.5, 4
local ZOOM_IN_STEP, ZOOM_OUT_STEP = 1.04, 0.96
local zoom = 1
local panX = 0
local zoomLabel = false
local zoomTimer = Timer.new()

-- NOBORU themes only define a few colors, so the webtoon UI maps its needs onto those
local function theme()
	return {
		COLOR_BACK = COLOR_BACK,
		COLOR_FONT = COLOR_FONT,
		COLOR_SUBFONT = COLOR_SUBFONT,
		COLOR_GROUP = COLOR_SELECTED,
		COLOR_ACCENT = COLOR_ROYAL_BLUE,
		COLOR_TABBAR = COLOR_PANEL,
		COLOR_TAB_IDLE = COLOR_SUBFONT,
		COLOR_SEPARATOR = COLOR_SUBFONT
	}
end

---------------------------------------------------------------------------------------------------
-- Rotation layer: all drawing below uses logical coordinates (SCREEN_W x SCREEN_H).
-- In vertical mode logical (lx, ly) is drawn at physical (960 - ly, lx), images rotated by PI / 2
-- (same convention as the paged reader).
---------------------------------------------------------------------------------------------------

local function drawImg(cx, cy, e, sx, sy, w, h, xs, ys)
	if vertical then
		Graphics.drawImageExtended(960 - cy, cx, e, sx, sy, w, h, PI / 2, xs, ys)
	else
		Graphics.drawImageExtended(cx, cy, e, sx, sy, w, h, 0, xs, ys)
	end
end

local function fillR(x1, x2, y1, y2, color)
	if vertical then
		Graphics.fillRect(960 - y2, 960 - y1, x1, x2, color)
	else
		Graphics.fillRect(x1, x2, y1, y2, color)
	end
end

-- tiny 3x5 pixel font so the vertical layout can show numbers without rotated text
local GLYPH = {
	["0"] = { "111", "101", "101", "101", "111" }, ["1"] = { "010", "110", "010", "010", "111" },
	["2"] = { "111", "001", "111", "100", "111" }, ["3"] = { "111", "001", "111", "001", "111" },
	["4"] = { "101", "101", "111", "001", "001" }, ["5"] = { "111", "100", "111", "001", "111" },
	["6"] = { "111", "100", "111", "101", "111" }, ["7"] = { "111", "001", "001", "001", "001" },
	["8"] = { "111", "101", "111", "101", "111" }, ["9"] = { "111", "101", "111", "001", "111" },
	["/"] = { "001", "001", "010", "100", "100" }, ["%"] = { "101", "001", "010", "100", "101" }
}

local function glyphWidth(text, sc)
	return #text * 4 * sc - sc
end

local function drawGlyphs(text, lx, ly, sc, color)
	for i = 1, #text do
		local g = GLYPH[sub(text, i, i)]
		if g then
			for r = 1, 5 do
				for c = 1, 3 do
					if sub(g[r], c, c) == "1" then
						local x = lx + (i - 1) * 4 * sc + (c - 1) * sc
						local y = ly + (r - 1) * sc
						fillR(x, x + sc, y, y + sc, color)
					end
				end
			end
		end
	end
end

-- physical touch point -> logical point
local function toLogical(t)
	if vertical and t and t.x then
		return { x = t.y, y = 960 - t.x }
	end
	return t
end

---------------------------------------------------------------------------------------------------
-- Layout
---------------------------------------------------------------------------------------------------

local function averageRatio()
	if ratioCount > 0 then
		return ratioSum / ratioCount
	end
	return EST_RATIO
end

local function viewW()
	return SCREEN_W * zoom
end

local function pageHeight(p)
	if p.h then
		return p.h
	end
	return viewW() * averageRatio()
end

local function rescale(p)
	p.scale = viewW() / p.w
	p.h = p.scale * p.srcH
end

---Recomputes `top` of every page; keeps the viewport anchored if something above it changed size
local function layout()
	local y = headH
	for i = 1, count do
		local p = pages[i]
		p.top = y
		y = y + pageHeight(p)
	end
	contentH = y + footH
end

local function measure(p)
	local image = p.Image
	if not image then
		return
	end
	local w, h = image.Width, image.Height
	if not w or not h or w <= 0 or h <= 0 then
		return
	end
	local oldH = pageHeight(p)
	p.w = w
	p.srcH = h
	rescale(p)
	local newH = p.h
	ratioSum = ratioSum + h / w
	ratioCount = ratioCount + 1
	-- preserve what the reader is looking at: only content *above* the viewport moves it
	local delta = newH - oldH
	if delta ~= 0 and p.top + oldH <= scrollY then
		scrollY = scrollY + delta
		if targetY then
			targetY = targetY + delta
		end
	end
	layout()
end

local function pageAt(y)
	-- binary search the page containing content-y `y`
	if count == 0 then
		return 1
	end
	local lo, hi = 1, count
	while lo < hi do
		local mid = floor((lo + hi + 1) / 2)
		if pages[mid].top <= y then
			lo = mid
		else
			hi = mid - 1
		end
	end
	return lo
end

local function maxScroll()
	return max(0, contentH - SCREEN_H)
end

local function clampPan()
	local lim = max(0, (viewW() - SCREEN_W) / 2)
	panX = max(-lim, min(lim, panX))
end

---Multiplies the zoom by `f`, keeping the content in the middle of the screen where it is
local function zoomBy(f)
	local nz = max(ZOOM_MIN, min(ZOOM_MAX, zoom * f))
	if nz == zoom or count == 0 then
		return
	end
	local anchor = scrollY + SCREEN_H / 2
	local a = pageAt(anchor)
	local pa = pages[a]
	local hA = pageHeight(pa)
	local frac = hA > 0 and (anchor - pa.top) / hA or 0
	local ratio = nz / zoom
	zoom = nz
	for i = 1, count do
		local p = pages[i]
		if p.w then
			rescale(p)
		end
	end
	layout()
	pa = pages[a]
	scrollY = max(0, min(maxScroll(), pa.top + frac * pageHeight(pa) - SCREEN_H / 2))
	panX = panX * ratio
	clampPan()
	targetY = nil
	velocity = 0
	zoomLabel = true
	Timer.reset(zoomTimer)
end

---Switches between normal and rotated (vertical) layout, keeping the page you are reading
local function applyOrientation(v)
	v = v and true or false
	if v == vertical then
		return
	end
	local a, frac = 1, 0
	if count > 0 then
		a = pageAt(scrollY + SCREEN_H / 2)
		local pa = pages[a]
		local hA = pageHeight(pa)
		frac = hA > 0 and (scrollY + SCREEN_H / 2 - pa.top) / hA or 0
	end
	vertical = v
	if v then
		SCREEN_W, SCREEN_H = 544, 960
	else
		SCREEN_W, SCREEN_H = 960, 544
	end
	panX = 0
	for i = 1, count do
		if pages[i].w then
			rescale(pages[i])
		end
	end
	layout()
	if count > 0 then
		local pa = pages[a]
		scrollY = max(0, min(maxScroll(), pa.top + frac * pageHeight(pa) - SCREEN_H / 2))
	end
	targetY, velocity, over = nil, 0, 0
	if v then
		toolbar = false
	end
end

---------------------------------------------------------------------------------------------------
-- Image management
---------------------------------------------------------------------------------------------------

local function now()
	return Timer.getTime(GlobalTimer)
end

local function freeImage(p)
	local image = p.Image
	if image then
		if type(image.e or image) == "table" then
			-- sliced (Parts) or animated (frames) image
			Threads.remove(p)
			ParserManager.remove(p)
			if image.Parts then
				for i = 1, image.Parts do
					if image[i] and image[i].free then
						image[i]:free()
					end
				end
			else
				for i = 1, #image do
					if image[i] and image[i].Image and image[i].Image.free then
						image[i].Image:free()
					end
				end
			end
		elseif image.free then
			image:free()
		end
		p.Image = nil
	else
		Threads.remove(p)
		ParserManager.remove(p)
	end
	p.Queued = false
	p.IdleSince = nil
end

local function requestImage(p, priority)
	local add = priority and Threads.insertTask or Threads.addTask
	if p.Extract then
		add(
			p,
			{
				Type = "UnZipFile",
				Path = p.Path,
				Extract = p.Extract,
				DestPath = "ux0:data/noboru/temp/cache.image",
				OnComplete = function()
					Threads.insertTask(
						p,
						{
							Type = "Image",
							Table = p,
							Path = "temp/cache.image",
							Index = "Image",
							Animated = Settings.AnimatedGif
						}
					)
				end
			}
		)
	elseif p.Path then
		add(p, { Type = "Image", Path = p.Path, Table = p, Index = "Image", Animated = Settings.AnimatedGif })
	elseif p.Link then
		add(p, { Type = "ImageDownload", Link = p.Link, Table = p, Index = "Image", Animated = Settings.AnimatedGif })
	else
		ParserManager.loadPageImage(manga.ParserID, p[1], p, priority)
	end
	p.Queued = true
	p.Failed = false
	p.IdleSince = nil
end

local function isBusy(p)
	return Threads.check(p) or ParserManager.check(p)
end

local function isVisible(p)
	return p.top + pageHeight(p) > scrollY and p.top < scrollY + SCREEN_H
end

local function vramBudgetOk()
	return GetGPUMemoryUsed() < MAX_VRAM_MEMORY * 0.8
end

---Full-chapter loading: every page of the chapter is queued in reading order (nearest to the viewport first)
---instead of one image at a time while scrolling. Only video memory limits how much stays loaded:
---requests stop above VRAM_SOFT, and above VRAM_HARD the page farthest from the viewport is freed
---(pages behind you go first).
local function memFraction()
	return GetGPUMemoryUsed() / MAX_VRAM_MEMORY
end

local function manageImages()
	local cur = currentPage
	local t = now()

	-- 1. detect finished / failed requests, measure fresh images
	local inflight = 0
	for i = 1, count do
		local p = pages[i]
		if p.Image then
			if not p.h then
				measure(p)
			end
			if p.Queued and not isBusy(p) then
				p.Queued = false
			end
		elseif p.Queued then
			if isBusy(p) then
				p.IdleSince = nil
				inflight = inflight + 1
			else
				p.IdleSince = p.IdleSince or t
				if t - p.IdleSince > FAIL_AFTER_MS then
					p.Queued = false
					p.Failed = true
					p.IdleSince = nil
				else
					inflight = inflight + 1
				end
			end
		end
	end

	-- 2. memory pressure: free the page farthest from the viewport (behind counts as farther)
	if memFraction() > VRAM_HARD then
		local worst, worstScore = nil, -1
		for i = 1, count do
			local p = pages[i]
			if p.Image and not isVisible(p) then
				local d = i - cur
				local score = d < 0 and -d or d * 2
				if score > worstScore then
					worst, worstScore = p, score
				end
			end
		end
		if worst then
			freeImage(worst)
		end
	end

	-- 3. keep the queue full: visible pages first (priority), then everything ahead, then behind
	if inflight >= MAX_INFLIGHT then
		return
	end
	local roomy = memFraction() < VRAM_SOFT
	local function want(i)
		local p = pages[i]
		if p and not p.Image and not p.Queued and not p.Failed then
			local visible = isVisible(p)
			if visible or roomy then
				requestImage(p, visible)
				inflight = inflight + 1
				return inflight >= MAX_INFLIGHT
			end
		end
		return false
	end
	for i = max(1, cur - 1), min(count, cur + 3) do
		if isVisible(pages[i]) and want(i) then
			return
		end
	end
	for i = cur, count do
		if want(i) then
			return
		end
	end
	for i = cur - 1, 1, -1 do
		if want(i) then
			return
		end
	end
end

local function retryPage(p)
	freeImage(p)
	p.Failed = false
	requestImage(p, true)
end

---------------------------------------------------------------------------------------------------
-- Navigation helpers
---------------------------------------------------------------------------------------------------

local function jumpToPage(i)
	i = max(1, min(count, i))
	targetY = max(0, min(maxScroll(), pages[i].top))
	velocity = 0
end

local function bookmarkValue()
	-- same convention as the paged reader: nil = first page, true = finished, number = page
	if count == 0 then
		return nil
	end
	local atEnd = scrollY + SCREEN_H >= contentH - footH + 20
	if currentPage >= count and atEnd then
		return true
	elseif currentPage <= 1 then
		return nil
	end
	return currentPage
end

---@return any bookmark value for Cache.setBookmark
function Webtoon.getBookmark()
	return bookmarkValue()
end

---@return number index of the page at the top third of the screen (1-based)
function Webtoon.getPage()
	return currentPage
end

function Webtoon.isActive()
	return active
end

---Frees every texture and cancels all page requests
function Webtoon.free()
	for i = 1, count do
		freeImage(pages[i])
	end
	pages = {}
	count = 0
	active = false
	ctx = nil
	velocity = 0
	over = 0
	targetY = nil
	toolbar = false
	toolbarFade = 0
	collectgarbage("collect")
end

---@param context table { chapters, index, startPage, onNext, onPrev, onExit, onOptions }
---Starts the webtoon reader for the chapter whose page list has just been prepared by the parser
function Webtoon.begin(context)
	Webtoon.free()
	vertical = false
	SCREEN_W, SCREEN_H = 960, 544
	ctx = context
	chapterNumber = context.index
	chapterTotal = #context.chapters
	chapter = context.chapters[chapterNumber]
	manga = chapter.Manga
	count = #chapter.Pages
	pages = {}
	ratioSum, ratioCount = 0, 0
	for i = 1, count do
		local src = chapter.Pages[i]
		pages[i] = {
			src,
			Path = src.Path,
			Extract = src.Extract,
			top = 0
		}
	end
	headH = chapterNumber > 1 and TRANSITION_H or 0
	footH = TRANSITION_H
	layout()
	active = true
	over = 0
	velocity = 0
	targetY = nil
	toolbar = false
	toolbarFade = 0
	touching = false
	panX = 0
	currentPage = 1
	local start = context.startPage
	if start == false then
		-- came back from the next chapter: start at the end
		scrollY = maxScroll()
	elseif start and start > 1 and start <= count then
		scrollY = pages[start].top
	else
		scrollY = headH
	end
	currentPage = pageAt(scrollY + SCREEN_H * 0.35)
	Timer.reset(counterTimer)
	Timer.reset(ticker)
	if context.isVertical and context.isVertical() then
		applyOrientation(true)
	end
	manageImages()
end

---@return table|nil descriptor of the current page image (used by the options menu)
function Webtoon.getCurrentPageImageLink()
	local p = pages[currentPage]
	if not p then
		return nil
	end
	if p.Extract then
		return { Path = p.Path, Extract = p.Extract }
	elseif p.Path then
		return { Path = p.Path }
	elseif p.Link then
		return { Link = p.Link }
	else
		return { ParserID = manga.ParserID, Link = p[1] }
	end
end

---------------------------------------------------------------------------------------------------
-- Input
---------------------------------------------------------------------------------------------------

local function inTopBar(y)
	return toolbar and y < TOP_BAR_H
end

local function inBottomBar(y)
	return toolbar and y > SCREEN_H - BOTTOM_BAR_H
end

local function tapBar(x, y)
	if y < TOP_BAR_H then
		if x < 88 then
			ctx.onExit()
		elseif x > SCREEN_W - 88 then
			local p = pages[currentPage]
			if p and ctx.onOptions then
				ctx.onOptions(p)
			end
		elseif x > SCREEN_W - 176 then
			local p = pages[currentPage]
			if p then
				retryPage(p)
			end
		end
	else
		if x < 88 then
			if chapterNumber > 1 then
				ctx.onPrev()
			end
		elseif x > SCREEN_W - 88 then
			if chapterNumber < chapterTotal then
				ctx.onNext()
			end
		end
	end
end

local function sliderToPage(x)
	if count <= 1 then
		return 1
	end
	local f = (x - SLIDER_X1) / (SLIDER_X2 - SLIDER_X1)
	return max(1, min(count, floor(f * (count - 1) + 1.5)))
end

function Webtoon.input(oldPad, pad, oldTouch, touch, oldTouch2, touch2)
	if not active then
		return
	end
	heldPad = pad

	-- buttons -------------------------------------------------------------------------------------
	if Controls.check(pad, SCE_CTRL_CIRCLE) and not Controls.check(oldPad, SCE_CTRL_CIRCLE) then
		ctx.onExit()
		return
	end
	if Controls.check(pad, SCE_CTRL_START) and not Controls.check(oldPad, SCE_CTRL_START) and not vertical then
		toolbar = not toolbar
	end
	-- SELECT: switch between normal and vertical (rotated, full screen) layout
	if Controls.check(pad, SCE_CTRL_SELECT) and not Controls.check(oldPad, SCE_CTRL_SELECT) and ctx.toggleOrientation then
		ctx.toggleOrientation()
		applyOrientation(ctx.isVertical())
	end
	oldTouch, touch = toLogical(oldTouch), toLogical(touch)

	-- scroll = logical up/down, pan = logical left/right.  In vertical mode the device is turned
	-- 90 degrees, so d-pad LEFT scrolls forward, RIGHT back, and UP/DOWN pan.
	local fwd, back, panF, panB = SCE_CTRL_DOWN, SCE_CTRL_UP, SCE_CTRL_RIGHT, SCE_CTRL_LEFT
	if vertical then
		fwd, back, panF, panB = SCE_CTRL_LEFT, SCE_CTRL_RIGHT, SCE_CTRL_DOWN, SCE_CTRL_UP
	end
	local step = 0
	if Controls.check(pad, fwd) then
		step = step + 18
	end
	if Controls.check(pad, back) then
		step = step - 18
	end
	local lax, lay = Controls.readLeftAnalog()
	local ly = (vertical and -(lax - 127) or (lay - 127))
	if abs(ly) > SCE_LEFT_STICK_DEADZONE then
		step = step + SCE_LEFT_STICK_SENSITIVITY * 22 * (ly - SCE_LEFT_STICK_DEADZONE * (ly < 0 and -1 or 1)) / (128 - SCE_LEFT_STICK_DEADZONE)
	end
	local rax, ray = Controls.readRightAnalog()
	ry = vertical and -(rax - 127) or (ray - 127)
	if abs(ry) > SCE_RIGHT_STICK_DEADZONE then
		step = step + SCE_RIGHT_STICK_SENSITIVITY * 34 * (ry - SCE_RIGHT_STICK_DEADZONE * (ry < 0 and -1 or 1)) / (128 - SCE_RIGHT_STICK_DEADZONE)
	end
	if step ~= 0 then
		targetY = nil
		velocity = 0
		Timer.reset(counterTimer)
		local ny = scrollY + step
		if ny < 0 then
			over = max(-PULL_TRIGGER - 60, over + ny * 0.2)
			overPushed = true
			ny = 0
		elseif ny > maxScroll() then
			over = min(PULL_TRIGGER + 60, over + (ny - maxScroll()) * 0.2)
			overPushed = true
			ny = maxScroll()
		end
		scrollY = ny
	end

	-- zoom: hold TRIANGLE to zoom in, hold SQUARE to zoom out
	if Controls.check(pad, SCE_CTRL_TRIANGLE) then
		zoomBy(ZOOM_IN_STEP)
	end
	if Controls.check(pad, SCE_CTRL_SQUARE) then
		zoomBy(ZOOM_OUT_STEP)
	end
	-- horizontal pan while zoomed in
	if zoom > 1 then
		local pstep = 0
		if Controls.check(pad, panF) then
			pstep = pstep + 14
		end
		if Controls.check(pad, panB) then
			pstep = pstep - 14
		end
		local lax2, lay2 = Controls.readLeftAnalog()
		local lx = (vertical and (lay2 - 127) or (lax2 - 127))
		if abs(lx) > SCE_LEFT_STICK_DEADZONE then
			pstep = pstep + 16 * (lx - SCE_LEFT_STICK_DEADZONE * (lx < 0 and -1 or 1)) / (128 - SCE_LEFT_STICK_DEADZONE)
		end
		if pstep ~= 0 then
			panX = panX + pstep
			clampPan()
		end
	end

	-- page jumps (L / R by default)
	if Controls.check(pad, SCE_CTRL_RIGHTPAGE) and not Controls.check(oldPad, SCE_CTRL_RIGHTPAGE) then
		if currentPage >= count then
			targetY = maxScroll()
		else
			jumpToPage(currentPage + 1)
		end
		Timer.reset(counterTimer)
	elseif Controls.check(pad, SCE_CTRL_LEFTPAGE) and not Controls.check(oldPad, SCE_CTRL_LEFTPAGE) then
		local p = pages[currentPage]
		if p and scrollY > p.top + 30 then
			jumpToPage(currentPage)
		else
			jumpToPage(currentPage - 1)
		end
		Timer.reset(counterTimer)
	end

	-- cross: continue to the next chapter once the end panel is on screen
	if Controls.check(pad, SCE_CTRL_CROSS) and not Controls.check(oldPad, SCE_CTRL_CROSS) then
		if scrollY >= maxScroll() - 4 and chapterNumber < chapterTotal then
			ctx.onNext()
			return
		end
	end

	-- touch ---------------------------------------------------------------------------------------
	if touch.x and not oldTouch.x then
		touching = true
		touchMoved = false
		touchStart.x, touchStart.y = touch.x, touch.y
		touchOnBar = not vertical and (inTopBar(touch.y) or inBottomBar(touch.y))
		sliderDrag = not vertical and inBottomBar(touch.y) and touch.x > SLIDER_X1 - 20 and touch.x < SLIDER_X2 + 20
		Timer.reset(touchTimer)
		velocity = 0
		targetY = nil
	end
	if touching and touch.x and oldTouch.x then
		if sliderDrag then
			jumpToPage(sliderToPage(touch.x))
			targetY = nil
			scrollY = max(0, min(maxScroll(), pages[sliderToPage(touch.x)].top))
		elseif not touchOnBar then
			local dy = oldTouch.y - touch.y
			if abs(touch.y - touchStart.y) > 10 or abs(touch.x - touchStart.x) > 10 then
				touchMoved = true
			end
			if touchMoved then
				panX = panX + (oldTouch.x - touch.x)
				clampPan()
				local ny = scrollY + dy
				if ny < 0 then
					over = max(-PULL_TRIGGER - 80, over + ny * 0.5)
					ny = 0
				elseif ny > maxScroll() then
					over = min(PULL_TRIGGER + 80, over + (ny - maxScroll()) * 0.5)
					ny = maxScroll()
				end
				scrollY = ny
				velocity = dy
				Timer.reset(counterTimer)
			end
		end
	end
	if touching and not touch.x then
		touching = false
		if not touchMoved and not sliderDrag then
			-- a tap
			local tx, ty = touchStart.x, touchStart.y
			if touchOnBar then
				tapBar(tx, ty)
			else
				local p = pages[pageAt(scrollY + ty)]
				if p and p.Failed then
					retryPage(p)
				else
					toolbar = not toolbar and not vertical
				end
			end
		end
		if abs(over) >= PULL_TRIGGER then
			if over > 0 and chapterNumber < chapterTotal then
				ctx.onNext()
				return
			elseif over < 0 and chapterNumber > 1 then
				ctx.onPrev()
				return
			end
		end
		sliderDrag = false
	end
end

---------------------------------------------------------------------------------------------------
-- Update
---------------------------------------------------------------------------------------------------

function Webtoon.update()
	if not active then
		return
	end
	frame = frame + 1
	if ctx and ctx.isVertical and (ctx.isVertical() and true or false) ~= vertical then
		applyOrientation(ctx.isVertical())
	end

	if targetY then
		local d = targetY - scrollY
		if abs(d) < 1 then
			scrollY = targetY
			targetY = nil
		else
			scrollY = scrollY + d * 0.3
		end
	elseif not touching then
		-- inertia
		if abs(velocity) > 0.3 then
			local ny = scrollY + velocity
			velocity = velocity * 0.93
			if ny < 0 then
				ny = 0
				velocity = 0
			elseif ny > maxScroll() then
				ny = maxScroll()
				velocity = 0
			end
			scrollY = ny
		else
			velocity = 0
		end
	end

	-- overscroll rubber band; holding d-pad / stick against the edge keeps it and finally continues
	if not touching then
		if abs(over) >= PULL_TRIGGER and overPushed then
			if over > 0 and chapterNumber < chapterTotal then
				ctx.onNext()
				return
			elseif over < 0 and chapterNumber > 1 then
				ctx.onPrev()
				return
			end
		end
		if not overPushed then
			over = over * 0.8
			if abs(over) < 0.5 then
				over = 0
			end
		end
	end
	overPushed = false

	local p = pageAt(scrollY + SCREEN_H * 0.35)
	if p ~= currentPage then
		currentPage = p
		Timer.reset(counterTimer)
	end

	if frame % 3 == 0 then
		manageImages()
	end

	if toolbar then
		toolbarFade = min(toolbarFade + 0.18, 1)
	else
		toolbarFade = max(toolbarFade - 0.18, 0)
	end
end

---------------------------------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------------------------------

local function dots(speed)
	return string.sub("...", 1, ceil(Timer.getTime(GlobalTimer) / (speed or 250)) % 4)
end

local function drawPlaceholder(p, i, y1, y2, t)
	fillR(0, SCREEN_W, y1, y2, t.COLOR_GROUP)
	local cy = max(y1, 0) + (min(y2, SCREEN_H) - max(y1, 0)) / 2
	if vertical then
		-- no text in the rotated layout: spinner bar for loading, refresh icon for failed
		local cx = SCREEN_W / 2
		if p.Failed then
			drawImg(cx, cy, RefreshIcon.e, 0, 0, 24, 24, 1.5, 1.5)
		else
			local progress = Threads.getProgress(p) or 0
			fillR(cx - 60, cx + 60, cy - 2, cy + 2, t.COLOR_SEPARATOR)
			fillR(cx - 60, cx - 60 + 120 * progress, cy - 2, cy + 2, t.COLOR_ACCENT)
			drawGlyphs(tostring(i), cx - glyphWidth(tostring(i), 3) / 2, cy - 30, 3, t.COLOR_SUBFONT)
		end
		return
	end
	local label
	if p.Failed then
		label = (Language[Settings.Language].READER.ERROR or "Failed to load") .. " - " .. (Language[Settings.Language].READER.TAP_RETRY or "tap to retry")
		Font.print(FONT16, 480 - Font.getTextWidth(FONT16, label) / 2, cy - 10, label, t.COLOR_ACCENT)
	else
		label = (Language[Settings.Language].READER.LOADING_PAGE or "Loading page") .. " " .. i .. dots()
		Font.print(FONT16, 480 - Font.getTextWidth(FONT16, label) / 2, cy - 22, label, t.COLOR_SUBFONT)
		local progress = Threads.getProgress(p)
		Graphics.fillRect(430, 530, cy + 4, cy + 8, t.COLOR_SEPARATOR)
		Graphics.fillRect(430, 430 + 100 * progress, cy + 4, cy + 8, t.COLOR_ACCENT)
	end
end

local function drawPageImage(p, y1, offset)
	local image = p.Image
	local s = p.scale
	if not s then
		return
	end
	if type(image.e or image) == "table" then
		if image.Parts then
			local sliceH = image.SliceHeight or floor(image.Height / image.Parts)
			for k = 1, image.Parts do
				local part = image[k]
				local top = y1 + (k - 1) * sliceH * s
				if part and part.e then
					local ph = Graphics.getImageHeight(part.e)
					local bottom = top + ph * s
					if bottom > 0 and top < SCREEN_H then
						drawImg(SCREEN_W / 2 - panX, top + ph * s / 2, part.e, 0, 0, p.w, ph, s, s)
					end
				elseif top + sliceH * s > 0 and top < SCREEN_H then
					local t = theme()
					fillR(0, SCREEN_W, max(0, top), min(SCREEN_H, top + sliceH * s), t.COLOR_GROUP)
					if not vertical then
						local label = (Language[Settings.Language].READER.LOADING_SEGMENT or "Loading segment") .. dots()
						local ty = max(top, 0) + 20
						Font.print(FONT16, 480 - Font.getTextWidth(FONT16, label) / 2, ty, label, t.COLOR_SUBFONT)
					end
				end
			end
		else
			-- animated gif: pick the frame by time
			local total = 0
			for k = 1, #image do
				total = total + (image[k].Delay or 100)
			end
			local at = total > 0 and Timer.getTime(GlobalTimer) % total or 0
			local fr = 1
			for k = 1, #image do
				local d = image[k].Delay or 100
				if at > d then
					fr = fr + 1
					at = at - d
				else
					break
				end
			end
			local f = image[fr] and image[fr].Image
			if f and f.e then
				drawImg(SCREEN_W / 2 - panX, y1 + p.h / 2, f.e, 0, 0, p.w, p.srcH, s, s)
			end
		end
	elseif image.e then
		drawImg(SCREEN_W / 2 - panX, y1 + p.h / 2, image.e, 0, 0, p.w, p.srcH, s, s)
	end
end

local function drawTransition(y1, forNext, t)
	local y2 = y1 + TRANSITION_H
	if y2 < 0 or y1 > SCREEN_H then
		return
	end
	local cy = y1 + TRANSITION_H / 2
	local targetIndex = forNext and chapterNumber + 1 or chapterNumber - 1
	local target = ctx.chapters[targetIndex]
	if vertical then
		local cx = SCREEN_W / 2
		if target then
			local icon = forNext and rightIcon or leftIcon
			drawImg(cx, cy - 20, icon.e, 0, 0, 24, 24, 2, 2)
			local pull = forNext and over or -over
			local f = min(1, max(0, pull / PULL_TRIGGER))
			fillR(cx - 80, cx + 80, cy + 20, cy + 24, t.COLOR_SEPARATOR)
			fillR(cx - 80, cx - 80 + 160 * f, cy + 20, cy + 24, t.COLOR_ACCENT)
			drawGlyphs(tostring(targetIndex), cx - glyphWidth(tostring(targetIndex), 3) / 2, cy + 36, 3, t.COLOR_FONT)
		else
			fillR(cx - 40, cx + 40, cy - 2, cy + 2, t.COLOR_SEPARATOR)
		end
		return
	end
	local title1, title2
	local lang = Language[Settings.Language].READER
	if forNext then
		title1 = chapter.Name or ""
		if target then
			title2 = (lang.NEXT_CHAPTER or "Next chapter") .. ": " .. (target.Name or ("Chapter " .. targetIndex))
		else
			title2 = lang.NO_NEXT_CHAPTER or "There is no next chapter"
		end
	else
		title1 = chapter.Name or ""
		title2 = (lang.PREV_CHAPTER or "Previous chapter") .. ": " .. ((target and target.Name) or ("Chapter " .. targetIndex))
	end
	local hint
	if target then
		local pull = forNext and over or -over
		if pull >= PULL_TRIGGER then
			hint = lang.RELEASE_CONTINUE or "Release to continue"
		else
			hint = forNext and (lang.PULL_NEXT or "Keep scrolling to continue") or (lang.PULL_PREV or "Keep pulling to go back")
		end
	end
	local function center(font, text, y, color)
		if Font.getTextWidth(font, text) > 900 then
			font = FONT16
		end
		Font.print(font, 480 - Font.getTextWidth(font, text) / 2, y, text, color)
	end
	center(FONT20, title1, cy - 46, t.COLOR_SUBFONT)
	center(BONT16, title2, cy - 14, target and t.COLOR_FONT or t.COLOR_SUBFONT)
	if hint then
		center(FONT16, hint, cy + 22, t.COLOR_ACCENT)
		local pull = forNext and over or -over
		local f = min(1, max(0, pull / PULL_TRIGGER))
		Graphics.fillRect(380, 580, cy + 52, cy + 55, t.COLOR_SEPARATOR)
		Graphics.fillRect(380, 380 + 200 * f, cy + 52, cy + 55, t.COLOR_ACCENT)
	end
end

local function drawToolbars(t)
	if toolbarFade <= 0 or vertical then
		return
	end
	local a = 255 * toolbarFade
	local bar = CloneColorWithNewAlpha(t.COLOR_TABBAR, 240 * toolbarFade)
	local line = CloneColorWithNewAlpha(t.COLOR_SEPARATOR, a)
	local fontColor = CloneColorWithNewAlpha(t.COLOR_FONT, a)
	local subColor = CloneColorWithNewAlpha(t.COLOR_SUBFONT, a)
	local accent = CloneColorWithNewAlpha(t.COLOR_ACCENT, a)
	local idle = CloneColorWithNewAlpha(t.COLOR_TAB_IDLE, a)
	local shift = (1 - toolbarFade)

	-- top bar
	local ty = -TOP_BAR_H * shift
	Graphics.fillRect(0, SCREEN_W, ty, ty + TOP_BAR_H, bar)
	Graphics.fillRect(0, SCREEN_W, ty + TOP_BAR_H - 1, ty + TOP_BAR_H, line)
	Graphics.drawImage(30, ty + TOP_BAR_H / 2 - 12, BackIcon.e, accent)
	local name = manga.Name or ""
	local cname = chapter.Name or ""
	local maxW = SCREEN_W - 88 * 2 - 40
	local function tickerText(text, font, y, color)
		local w = Font.getTextWidth(font, text)
		local x = 88
		if w > maxW then
			local cycle = 50 * #text
			local tt = min(max(0, Timer.getTime(ticker) - 1500), cycle)
			x = x - (w - maxW) * tt / cycle
			Graphics.fillRect(0, 88, ty, ty + TOP_BAR_H, bar)
			Font.print(font, x, y, text, color)
			Graphics.fillRect(0, 88, ty, ty + TOP_BAR_H - 1, bar)
			Graphics.fillRect(SCREEN_W - 176, SCREEN_W, ty, ty + TOP_BAR_H - 1, bar)
			Graphics.drawImage(30, ty + TOP_BAR_H / 2 - 12, BackIcon.e, accent)
		else
			Font.print(font, x, y, text, color)
		end
	end
	tickerText(name, FONT20, ty + 6, fontColor)
	tickerText(cname, FONT16, ty + 32, subColor)
	Graphics.drawImage(SCREEN_W - 32 - 24 - 32 - 24, ty + TOP_BAR_H / 2 - 12, RefreshIcon.e, accent)
	local p = pages[currentPage]
	Graphics.drawImage(SCREEN_W - 32 - 24, ty + TOP_BAR_H / 2 - 12, OptionsIcon.e, accent)
	if Timer.getTime(ticker) > 3500 + 50 * max(#name, #cname) then
		Timer.reset(ticker)
	end

	-- bottom bar
	local by = SCREEN_H + BOTTOM_BAR_H * shift - BOTTOM_BAR_H
	Graphics.fillRect(0, SCREEN_W, by, SCREEN_H + BOTTOM_BAR_H * shift, bar)
	Graphics.fillRect(0, SCREEN_W, by, by + 1, line)
	local cy = by + BOTTOM_BAR_H / 2
	Graphics.drawImage(32, cy - 12, leftIcon.e, chapterNumber > 1 and accent or idle)
	Graphics.drawImage(SCREEN_W - 32 - 24, cy - 12, rightIcon.e, chapterNumber < chapterTotal and accent or idle)
	local f = count > 1 and (currentPage - 1) / (count - 1) or 1
	local sx = SLIDER_X1 + (SLIDER_X2 - SLIDER_X1) * f
	Graphics.fillRect(SLIDER_X1, SLIDER_X2, cy - 1, cy + 2, line)
	Graphics.fillRect(SLIDER_X1, sx, cy - 1, cy + 2, accent)
	Graphics.drawImage(sx - 6, cy - 6, CircleIcon.e, accent)
	local cur = tostring(currentPage)
	Font.print(FONT20, SLIDER_X1 - 20 - Font.getTextWidth(FONT20, cur), cy - 11, cur, fontColor)
	Font.print(FONT20, SLIDER_X2 + 20, cy - 11, tostring(count), fontColor)
end

function Webtoon.draw()
	if not active then
		return
	end
	local t = theme()
	Screen.clear(t.COLOR_BACK)
	RK_ReaderVertical = vertical
	RK_BarsShown = toolbarFade > 0.02 and not vertical
	local oy = -over * 0.5 -- rubber band
	local offset = scrollY - oy

	-- pages ---------------------------------------------------------------------------------------
	local firstIndex = pageAt(offset)
	for i = firstIndex, count do
		local p = pages[i]
		local y1 = p.top - offset
		if y1 >= SCREEN_H then
			break
		end
		local h = pageHeight(p)
		if p.Image and p.scale then
			drawPageImage(p, y1, offset)
		else
			drawPlaceholder(p, i, y1, y1 + h, t)
		end
	end

	-- chapter transitions -------------------------------------------------------------------------
	if headH > 0 then
		drawTransition(-offset, false, t)
	end
	drawTransition(contentH - footH - offset, true, t)

	-- floating page counter (fades out after scrolling stops)
	if toolbarFade < 1 and count > 0 then
		local show = Timer.getTime(counterTimer) < 1500 or toolbar
		if show and vertical then
			local text = currentPage .. "/" .. count
			local sc = 3
			local w = glyphWidth(text, sc) + 16
			fillR(SCREEN_W - w - 8, SCREEN_W - 8, SCREEN_H - 14 - 5 * sc - 8, SCREEN_H - 6, Color.new(0, 0, 0, 170))
			drawGlyphs(text, SCREEN_W - w, SCREEN_H - 14 - 5 * sc, sc, COLOR_WHITE)
		elseif show then
			local text = currentPage .. "/" .. count
			local w = Font.getTextWidth(FONT16, text) + 20
			Graphics.fillRect(SCREEN_W - w - 12, SCREEN_W - 12, SCREEN_H - 40, SCREEN_H - 12, Color.new(0, 0, 0, 170))
			Font.print(FONT16, SCREEN_W - w - 2, SCREEN_H - 36, text, COLOR_WHITE)
		end
	end

	if zoomLabel and vertical and Timer.getTime(zoomTimer) < 1200 then
		local text = floor(zoom * 100 + 0.5) .. "%"
		local sc = 4
		local w = glyphWidth(text, sc) + 20
		fillR(SCREEN_W / 2 - w / 2, SCREEN_W / 2 + w / 2, 10, 10 + 5 * sc + 16, Color.new(0, 0, 0, 170))
		drawGlyphs(text, SCREEN_W / 2 - glyphWidth(text, sc) / 2, 18, sc, COLOR_WHITE)
	elseif zoomLabel and Timer.getTime(zoomTimer) < 1200 then
		local text = floor(zoom * 100 + 0.5) .. "%"
		local w = Font.getTextWidth(FONT20, text) + 24
		Graphics.fillRect(480 - w / 2, 480 + w / 2, 14, 46, Color.new(0, 0, 0, 170))
		Font.print(FONT20, 480 - Font.getTextWidth(FONT20, text) / 2, 19, text, COLOR_WHITE)
	end

	drawToolbars(t)
end
