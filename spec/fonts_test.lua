-- Run from the repository root: lua spec/fonts_test.lua.
local loaded, sizes, printed = {}, {}, nil
Font = {
	load = function(path)
		loaded[#loaded + 1] = path
		return #loaded
	end,
	setPixelSizes = function(font, size) sizes[font] = size end,
	print = function(font) printed = font end,
	getTextWidth = function(font) return font * 10 end,
	getTextHeight = function(font) return sizes[font] end
}
dofile('source/assets/libs/fonts.lua')
assert(#loaded == 5, 'multilingual fallback fonts must load only when needed')
assert(loaded[FONT16] == 'app0:SourceSans3-Regular.ttf')
assert(loaded[BONT30] == 'app0:SourceSans3-SemiBold.ttf')
assert(sizes[FONT16] == 16 and sizes[FONT20] == 20 and sizes[FONT26] == 26 and sizes[BONT30] == 30)
for _, text in ipairs({ 'Library', 'Français', 'Русский', 'Ελληνικά', 'Tiếng Việt', '… →', 'Line\nTwo' }) do
	Font.print(FONT16, 0, 0, text)
	assert(printed == FONT16, 'supported text must use Source Sans: ' .. text)
end
Font.print(FONT26, 0, 0, '漫画 日本語')
local fallback = printed
assert(loaded[fallback] == 'app0:roboto.ttf' and sizes[fallback] == 26)
assert(Font.getTextWidth(FONT26, '漫画 日本語') == fallback * 10, 'measurement must use the same fallback as drawing')
assert(Font.getTextHeight(FONT26, '漫画 日本語') == 26)
Font.print(BONT16, 0, 0, '中文')
assert(loaded[printed] == 'app0:robboto.ttf' and sizes[printed] == 16, 'semibold strings must keep a bold fallback')
local count = #loaded
Font.print(FONT26, 0, 0, '別の漫画')
assert(#loaded == count, 'reuse the fallback font across titles')
Font.print(FONT26, 0, 0, 'Settings')
assert(printed == FONT26, 'Latin text must return to the new font')
print('Font checks passed: new faces, sizes, supported scripts, CJK fallback, consistent metrics, fallback reuse.')
