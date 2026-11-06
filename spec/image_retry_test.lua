-- Run from the repository root: lua spec/image_retry_test.lua
local function runCase(failedSlice, permanent, localFile, cancel)
	local files = { ['ux0:data/noboru/later.image'] = 'later-page' }
	local result, failures, downloads, handles = nil, 0, {}, {}
	local completed, finalized = 0, 0
	Settings = { BrowserMode = false }
	USERAGENT, GET_METHOD, XWWW, FILTER_LINEAR = 'test', 0, 0, 0
	Color = { new = function() end }
	Console = { write = function() end, error = function() end }
	RemoveDirectory = function() end
	System = {
		getAsyncState = function() return 1 end,
		getAsyncResult = function() return result end,
		doesFileExist = function(path) return files[path] ~= nil end,
		deleteFile = function(path) files[path] = nil end,
		getPictureResolution = function(path)
			return 800, files[path] == 'later-page' and 12001 or 1000
		end
	}
	Network = {
		init = function() end,
		term = function() end,
		stopCurrentDownload = function() end,
		downloadFileAsync = function(link, path)
			files[path] = link
			downloads[link] = (downloads[link] or 0) + 1
			result = 123 -- download result, never an image handle
		end
	}
	local function image(path, y, height)
		local handle = { source = files[path], y = y, height = height, freed = false }
		handles[#handles + 1] = handle
		return handle
	end
	Graphics = {
		getFreeMemory = function() return 100000000 end,
		loadImageAsync = function(path) result = image(path, 0, 1000) end,
		loadPartImageAsync = function(path, x, y, width, height)
			if y == (failedSlice - 1) * 4000 and (permanent or failures == 0) then
				failures = failures + 1
				result = nil
			else
				result = image(path, y, height)
			end
		end
	}
	Image = { new = function(self, handle)
		if not handle then return nil end
		assert(type(handle) == 'table', 'download result must never be used as an image')
		return { e = handle, free = function()
			assert(not handle.freed, 'texture freed twice')
			handle.freed = true
		end }
	end }
	dofile('source/assets/libs/net.lua')
	local later, first = {}, {}
	Threads.addTask(later, {
		Type = localFile and 'Image' or 'ImageDownload',
		Path = localFile and 'later.image' or nil,
		Link = not localFile and 'later-page' or nil,
		Table = later, Index = 'Image',
		OnComplete = function() completed = completed + 1 end,
		OnFinalComplete = function() finalized = finalized + 1 end
	})
	Threads.addTask(first, { Type = 'ImageDownload', Link = 'first-page', Table = first, Index = 'Image' })
	local cancelled = false
	for i = 1, 100 do
		Threads.update()
		if cancel and not cancelled and type(result) == 'table' and result.source == 'later-page' and result.y == 4000 then
			-- Match the reader unloading a partially loaded page while its next slice is pending.
			Threads.remove(later)
			for k = 1, later.Image.Parts do
				if later.Image[k] then later.Image[k]:free() end
			end
			later.Image = nil
			cancelled = true
		end
	end
	assert(not Threads.check(later) and not Threads.check(first), 'queue must finish')
	assert(not Threads.isDownloadRunning(), 'cancelled slices must not block the queue')
	assert(first.Image.e.source == 'first-page', 'first page must retain its own image')
	local retained = { [first.Image.e] = true }
	if cancel then
		assert(cancelled and later.Image == nil, 'cancelled page must stay unloaded')
		assert(finalized == 0, 'cancelled image must not report successful completion')
	elseif permanent then
		assert(later.Image == nil, 'failed page must not retain partial or unrelated slices')
		assert(failures == 3, 'failed slices must respect the retry limit')
		assert(completed == 0 and finalized == 0, 'failed page must not report completion')
	else
		assert(later.Image and later.Image.Parts == 3, 'long image must have three slices')
		for i = 1, 3 do
			local part = later.Image[i]
			assert(part and part.e.source == 'later-page', 'later page must never display first-page slices')
			assert(part.e.y == (i - 1) * 4000, 'retry must not skip a slice')
			assert(part.e.height == (i == 3 and 4001 or 4000), 'slices must cover the entire image')
			assert(not part.e.freed, 'successful slice must remain alive')
			retained[part.e] = true
		end
		assert(completed == 1 and finalized == 1, 'successful image must complete exactly once')
	end
	assert((downloads['later-page'] or 0) == (localFile and 0 or (cancel and 1 or (permanent and 3 or 2))),
		'online retries must redownload their own image; local retries must stay local')
	for _, handle in ipairs(handles) do
		assert(retained[handle] or handle.freed, 'discarded slices must be freed')
	end
end

for slice = 1, 3 do
	for _, localFile in ipairs({ false, true }) do
		runCase(slice, false, localFile)
		runCase(slice, true, localFile)
	end
end
runCase(99, false, false, true)
print('Image retry checks passed: slice ownership, retries, cleanup, completion and local images.')
