-- Glyph coverage of the bundled Source Sans 3 static fonts (from fc-scan).
local coverage = [[20-7e a0-181 186 18a 18d-190 192-194 196-197 19a-19b 19e 1a0-1a1 1af-1b1 1b7 1bf-1c3 1cd-1dd 1e2-1e7 1ea-1eb 1ee-1f0 1f4-1f5 1f7-201 204-205 208-209 20c-20d 218-220 222-223 226-227 237 23a-23e 241-245 248-249 250-27b 27d-285 287-292 294-295 298-299 29b-29f 2a1-2a8 2b0-2b4 2b7-2b9 2bb-2c1 2c6-2cc 2d0-2de 2e0-2e4 2ed 300-30d 30f-313 315 318-320 323-32a 32c 32e-332 334 337-33d 340 342-345 34f 357-358 35c 35e-35f 361 374-375 37a 37e 384-38a 38c 38e-3a1 3a3-3d1 3d5 3d7 3d9 3db 3dd 3e1 3f4 3f7-3f8 400-45f 462-463 472-475 490-493 496-49b 4a0-4a3 4aa-4ab 4ae-4b3 4b6-4b7 4ba-4bb 4c0-4c4 4c7-4c8 4cf-4d1 4d4-4d9 4e2-4e3 4e6-4e9 4ee-4ef 4f2-4f3 4f6-4f7 1d25 1d2c 1d2e 1d30-1d31 1d33-1d3a 1d3c 1d3e-1d43 1d47-1d4b 1d4d 1d4f-1d52 1d56-1d58 1d5b 1d6f-1d70 1d79 1d7b 1d7f 1d9c 1da0 1dac 1dae 1db0 1dbb 1dbf 1dcd 1e02-1e03 1e06-1e07 1e0a-1e11 1e16-1e17 1e1e-1e2b 1e32-1e3b 1e3e-1e49 1e52-1e53 1e56-1e63 1e66-1e67 1e6a-1e6f 1e72-1e73 1e7e-1e85 1e8e-1e97 1e9e-1ef9 1f00-1f15 1f18-1f1d 1f20-1f45 1f48-1f4d 1f50-1f57 1f59 1f5b 1f5d 1f5f-1f7d 1f80-1fb4 1fb6-1fc4 1fc6-1fd3 1fd6-1fdb 1fdd-1fef 1ff2-1ff4 1ff6-1ffe 2007 2009-200b 2010-201e 2020-2023 2026 202f-2033 2035 2039-203a 203c-203f 2044 2047-204a 2070-2071 2074-208e 20a1 20a3-20a4 20a6-20a7 20a9 20ab-20ac 20ae 20b1-20b2 20b4-20b5 20b8-20ba 20bd 2105 2113 2116-2117 211e 2120 2122 2126 212e 2150-215e 2189 2190-2199 21a8 21d0-21d3 21e7 2200 2202-2203 2206 220f 2211-2212 2215 2219-221a 221e-221f 2229 222b 2236-2237 2248 2260-2261 2264-2265 2302-2303 2310 2318 231c-2321 2325-2326 232b 25a0-25a1 25aa-25ac 25b2-25ba 25bc-25c4 25c6 25c9-25cc 25cf 25d8-25d9 25e6 2610-2611 2615 263a-263c 263f-2642 2660 2663 2665-2666 266a-266b 2713-2714 2717-2718 2752 275b-2760 2764 27e6-27e9 2c60-2c62 2c65-2c66 2c71 2c7d 2e18 2e22-2e25 2e3a-2e3b 2e52 a71c a722-a725 a74e-a74f a75a-a75b a764-a765 a779-a787 a789 a7ad-a7ae a7b3 a7b5 a7f2-a7f4 ab53 ab66-ab67 fb00-fb04 feff 1f10d-1f10f 1f12f 1f16a-1f16f 1f4a9 1f512 1f748 1f916]]
local ranges = {}
for token in coverage:gmatch('%S+') do
	local first, last = token:match('^(%x+)%-?(%x*)$')
	ranges[#ranges + 1] = { tonumber(first, 16), tonumber(last, 16) or tonumber(first, 16) }
end
local function supported(code)
	if code == 9 or code == 10 or code == 13 then return true end
	local lo, hi = 1, #ranges
	while lo <= hi do
		local mid = math.floor((lo + hi) / 2)
		local range = ranges[mid]
		if code < range[1] then hi = mid - 1
		elseif code > range[2] then lo = mid + 1
		else return true end
	end
	return false
end
local decisions, decisionCount = {}, 0
local function needsFallback(text)
	text = tostring(text or '')
	if not text:find('[\128-\255]') then return false end
	if decisions[text] ~= nil then return decisions[text] end
	local fallback = false
	for char in text:gmatch('[%z\1-\127\194-\244][\128-\191]*') do
		local a, b, c, d = char:byte(1, 4)
		local code = a
		if a >= 240 then code = (a - 240) * 262144 + (b - 128) * 4096 + (c - 128) * 64 + d - 128
		elseif a >= 224 then code = (a - 224) * 4096 + (b - 128) * 64 + c - 128
		elseif a >= 192 then code = (a - 192) * 64 + b - 128 end
		if not supported(code) then fallback = true; break end
	end
	-- Bound this cache: manga titles and notification text can change indefinitely.
	if decisionCount >= 256 then decisions, decisionCount = {}, 0 end
	decisions[text], decisionCount = fallback, decisionCount + 1
	return fallback
end
local fonts = {}
local function load(path, legacy, size)
	local font = Font.load(path)
	Font.setPixelSizes(font, size)
	fonts[font] = { legacy = legacy, size = size }
	return font
end
FONT16 = load('app0:SourceSans3-Regular.ttf', 'app0:roboto.ttf', 16)
FONT20 = load('app0:SourceSans3-Regular.ttf', 'app0:roboto.ttf', 20)
FONT26 = load('app0:SourceSans3-Regular.ttf', 'app0:roboto.ttf', 26)
BONT16 = load('app0:SourceSans3-SemiBold.ttf', 'app0:robboto.ttf', 16)
BONT30 = load('app0:SourceSans3-SemiBold.ttf', 'app0:robboto.ttf', 30)

-- Use the old multilingual fonts only for strings containing unsupported glyphs.
-- Drawing and measurement choose the same face to keep wrapping/alignment correct.
local function face(font, text)
	local info = fonts[font]
	if info and needsFallback(text) then
		if not info.fallback then
			info.fallback = Font.load(info.legacy)
			Font.setPixelSizes(info.fallback, info.size)
		end
		return info.fallback
	end
	return font
end
local printText, textWidth, textHeight = Font.print, Font.getTextWidth, Font.getTextHeight
function Font.print(font, x, y, text, ...)
	return printText(face(font, text), x, y, text, ...)
end
function Font.getTextWidth(font, text)
	return textWidth(face(font, text), text)
end
function Font.getTextHeight(font, text)
	return textHeight(face(font, text), text)
end
