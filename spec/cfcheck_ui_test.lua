-- Run from the repository root: lua spec/cfcheck_ui_test.lua.
dofile('spec/catalog_start_test.lua')
local now, body = 0, '<a href="/series">Series</a>'
Timer.new = function() return { start = now } end
Timer.getTime = function(timer) return now - timer.start end
Timer.reset = function(timer) timer.start = now end
CircleIcon = { e = 'spinner' }
Threads.insertTask = function(_, task) task.Table[task.Index] = body end
Settings.CFCheck = true
EaseInOutCubic = function(t) return t end
dofile('source/assets/libs/cfcheck.lua')
local labels = {}
Font.print = function(_, _, _, text) labels[text] = true end
local function draw()
	labels = {}
	CFCheck.draw()
	return labels
end
local function tick(ms)
	now = now + ms
	CFCheck.update()
end
local opened = 0
local parser = {
	ID = 'TEST', Link = 'https://example.invalid',
	getLatestManga = function(_, _, list) list[1] = { Name = 'A title' } end
}
CFCheck.begin(parser, function() opened = opened + 1 end)
tick(200)
assert(draw()['Checking site…'], 'checking popup must render')
tick(600)
assert(draw()['Site connected'], 'successful popup must render')
assert(labels['Open now'] and labels.Cancel, 'success actions must remain visible')
CFCheck.input(0, SCE_CTRL_CIRCLE)
assert(opened == 1 and not CFCheck.isActive(), 'open now must keep the callback handoff')
body = ''
CFCheck.begin(parser, function() opened = opened + 1 end)
tick(800)
assert(draw()["Couldn't read the site"], 'failed popup must render')
assert(labels['Retry connection'] and labels['Open browser'] and labels['Open anyway'] and labels.Cancel, 'failure must show every available action')
CFCheck.input(0, SCE_CTRL_CROSS)
assert(draw()['Checking site…'], 'retry must return to checking')
CFCheck.input(0, SCE_CTRL_SQUARE)
assert(not CFCheck.isActive() and opened == 1, 'cancel must not open the source')
print('Site popup checks passed: checking/success/failure rendering, action hints, open, retry and cancel.')
