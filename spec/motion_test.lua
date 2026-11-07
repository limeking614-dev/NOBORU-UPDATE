-- Run from the repository root with Lua 5.2+.
dofile('spec/extra_menu_test.lua')
local now = 0
Timer.new = function() return { start = now } end
Timer.getTime = function(timer) return now - timer.start end
Timer.reset = function(timer) timer.start = now end
local function near(a, b) assert(math.abs(a - b) < 0.000001, 'transition jumped') end
local timer = Timer.new()
near(UI.transition(0, 1, timer, UI.motion.enter), 0)
now = 40
assert(UI.transition(0, 1, timer, UI.motion.enter) > 0.5, 'entry must respond immediately')
now = 160
near(UI.transition(0, 1, timer, UI.motion.enter), 1)
now = 1000
near(UI.transition(0, 1, timer, UI.motion.enter), 1)

dofile('source/assets/libs/extra.lua')
local function open()
	Extra.setChapters({ Name = 'Motion', ParserID = 'TEST' }, {})
end
open()
now = now + 40
Extra.update()
local partial = Extra.getFade()
Extra.input(0, SCE_CTRL_START, {}, {})
Extra.update()
near(Extra.getFade(), partial)
now = now + 40
Extra.update()
local closing = Extra.getFade()
assert(closing < partial and closing > 0)
open()
Extra.update()
near(Extra.getFade(), closing)
now = now + UI.motion.enter
Extra.update()
near(Extra.getFade(), 1)
Extra.input(0, SCE_CTRL_START, {}, {})
now = now + UI.motion.exit
Extra.update()
assert(Extra.getStatus() == 'END', 'exit must release input on its final frame')

local alpha
Graphics.drawImage = function(_, _, _, color) alpha = Color.getA(color) end
GlobalTimer = Timer.new()
dofile('source/assets/libs/loading.lua')
Loading.draw()
assert(alpha == nil, 'hidden loader must skip drawing')
Loading.setStatus('WHITE')
now = now + 40
Loading.draw()
local visible = alpha
Loading.setStatus('NONE')
Loading.draw()
near(alpha, visible)
now = now + UI.motion.exit
alpha = nil
Loading.draw()
assert(alpha == nil, 'finished loader must stop drawing')

Language[Settings.Language].MESSAGE = { LOST_CONNECTION = 'Offline', PRESS_TO_UPDATE = 'Update' }
SCE_CTRL_REAL_CROSS, SCE_CTRL_REAL_CIRCLE = SCE_CTRL_CROSS, SCE_CTRL_CIRCLE
local cleared = false
ChapterSaver.clearDownloadingList = function() cleared = true end
Threads.netActionUnSafe = function() return false end
Network = { isWifiEnabled = function() return false end }
dofile('source/assets/libs/conmessage.lua')
ConnectMessage.show()
ConnectMessage.update()
now = now + UI.motion.dialog
ConnectMessage.update()
assert(ConnectMessage.input(SCE_CTRL_CROSS) == SCE_CTRL_CROSS and cleared)
local top
Graphics.fillRect = function(_, _, y) top = y end
ConnectMessage.update()
now = now + UI.motion.exit
ConnectMessage.update()
ConnectMessage.draw()
assert(top == nil, 'dismissed connection dialog must leave the screen')

dofile('source/assets/libs/changes.lua')
local updating = true
Settings.updateApp = function() end
Settings.isAppUpdating = function() return updating end
Changes.load('Release notes')
Changes.update()
now = now + UI.motion.dialog
Changes.update()
Changes.close(SCE_CTRL_CROSS)
updating = false
Changes.update()
now = now + UI.motion.exit
Changes.update()
top = nil
Changes.draw()
assert(not Changes.isActive() and top == nil, 'completed update must animate out')
print('Motion checks passed: finite timing, interrupted close/reopen, loader reversal, dialog dismissal and update completion.')
