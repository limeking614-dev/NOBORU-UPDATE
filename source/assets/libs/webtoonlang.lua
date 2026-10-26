-- Strings for the webtoon (continuous scroll) reader; filled into every language that lacks them
for _, L in pairs(Language) do
	L.EXTRA = L.EXTRA or {}
	L.SETTINGS = L.SETTINGS or {}
	L.SETTINGS_DESCRIPTION = L.SETTINGS_DESCRIPTION or {}
	L.READER = L.READER or {}
	L.EXTRA.ReaderWebtoon = L.EXTRA.ReaderWebtoon or "Reader mode"
	L.SETTINGS.ReaderMode = L.SETTINGS.ReaderMode or "Reader mode"
	L.SETTINGS_DESCRIPTION.ReaderMode = L.SETTINGS_DESCRIPTION.ReaderMode or "Webtoon scrolls pages continuously"
	L.READER.Webtoon = L.READER.Webtoon or "Webtoon"
	L.READER.Paged = L.READER.Paged or "Paged"
	L.READER.NEXT_CHAPTER = L.READER.NEXT_CHAPTER or "Next chapter"
	L.READER.PREV_CHAPTER = L.READER.PREV_CHAPTER or "Previous chapter"
	L.READER.NO_NEXT_CHAPTER = L.READER.NO_NEXT_CHAPTER or "There is no next chapter"
	L.READER.PULL_NEXT = L.READER.PULL_NEXT or "Keep scrolling to continue"
	L.READER.PULL_PREV = L.READER.PULL_PREV or "Keep pulling to go back"
	L.READER.RELEASE_CONTINUE = L.READER.RELEASE_CONTINUE or "Release to continue"
	L.READER.TAP_RETRY = L.READER.TAP_RETRY or "tap to retry"
	L.READER.ERROR = L.READER.ERROR or "Failed to load"
end
