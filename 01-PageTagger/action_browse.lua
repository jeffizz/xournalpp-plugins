-- ============================================================================
-- action_browse.lua | BROWSING, CHAPTER NAVIGATION & X-RAY ENGINE
-- ============================================================================
local config = require("config")
local utils = require("utils")
local helpers = require("xopp_helpers")

local action_browse = {}

local tagQueue = {}
local currentTagsMap = {}
local currentButtons = {}
local allAvailableTags = {}
local dialogCurrentPage = 1
local currentBrowsingTag = nil
local lastBrowsedPage = nil

local function showTagSelectionDialog()
	currentButtons = {}
	local startIndex = (dialogCurrentPage - 1) * config.TAGS_PER_DIALOG + 1
	local endIndex = math.min(startIndex + config.TAGS_PER_DIALOG - 1, #allAvailableTags)

	for i = startIndex, endIndex do
		local tag = allAvailableTags[i]
		local count = #(currentTagsMap[tag] or {})
		table.insert(currentButtons, string.format("%s(%d)", tag, count))
	end
	if startIndex > 1 then
		table.insert(currentButtons, "[ Previous ]")
	end
	if endIndex < #allAvailableTags then
		table.insert(currentButtons, "[ Next ]")
	end
	table.insert(currentButtons, "Cancel")

	local msg = string.format(
		"Which tag would you like to review?\n(Page %d of options, %d tags found):",
		dialogCurrentPage,
		#allAvailableTags
	)
	app.openDialog(msg, currentButtons, "onTagDialogResult")
end

local function clearHighlight(pageNo)
	if not pageNo then
		return
	end
	local doc = app.getDocumentStructure()
	if not doc.pages[pageNo] then
		return
	end

	local originalPage = doc.currentPage
	if originalPage ~= pageNo then
		app.setCurrentPage(pageNo)
	end

	local data = helpers.getPageData(pageNo)
	helpers.renderPageLabels(pageNo, data, nil)

	if originalPage ~= pageNo then
		app.setCurrentPage(originalPage)
	end
end

local function jumpToPageAndShowTag(targetPageNo, tagName)
	if lastBrowsedPage and lastBrowsedPage ~= targetPageNo then
		clearHighlight(lastBrowsedPage)
	end

	app.setCurrentPage(targetPageNo)
	app.scrollToPage(targetPageNo)
	lastBrowsedPage = targetPageNo
	local data = helpers.getPageData(targetPageNo)
	helpers.renderPageLabels(targetPageNo, data, tagName)
end

local function startBrowsingSession(tagName, isFromClipboard)
	tagQueue = currentTagsMap[tagName]
	currentBrowsingTag = tagName
	lastBrowsedPage = nil

	table.sort(tagQueue)
	local firstPage = table.remove(tagQueue, 1)

	jumpToPageAndShowTag(firstPage, currentBrowsingTag)

	local prefix = isFromClipboard and "📋 Match found from clipboard!" or "✅ Ready to review!"
	if #tagQueue > 0 then
		app.openDialog(
			string.format("%s\nJumped to page %d.\nThere are %d more pages.", prefix, firstPage, #tagQueue),
			{ "OK" }
		)
	else
		app.openDialog(
			string.format("%s\nOnly appears on page %d. Review complete!", prefix, firstPage),
			{ "OK" },
			"onFinishBrowse"
		)
	end
end

local function buildTagsMap(startPage, endPage)
	currentTagsMap, allAvailableTags = {}, {}
	local doc = app.getDocumentStructure()
	local allTexts = app.getTexts("all") or {}
	local labelLayerIds = {}

	startPage = startPage or 1
	endPage = endPage or #doc.pages

	for pNo = startPage, endPage do
		local page = doc.pages[pNo]
		if type(page) == "table" and page.layers then
			for lId, layer in pairs(page.layers) do
				if layer.name == "label" then
					labelLayerIds[pNo] = lId
					break
				end
			end
		end
	end

	for _, txt in pairs(allTexts) do
		local pNo = txt.page
		if pNo >= startPage and pNo <= endPage then
			if labelLayerIds[pNo] and txt.layer == labelLayerIds[pNo] then
				if txt.color == 0x000000 or txt.color == 0 then
					local tagPart = txt.text:gsub("^%s*(.-)%s*$", "%1")
					local isValid = (tagPart == "@chapter")
					if not isValid then
						isValid, _ = utils.isValidTag(tagPart)
					end

					if isValid and txt.y < 15 and tagPart ~= "@chapter" then
						if not currentTagsMap[tagPart] then
							currentTagsMap[tagPart] = {}
						end
						local alreadyInList = false
						for _, existingPage in ipairs(currentTagsMap[tagPart]) do
							if existingPage == pNo then
								alreadyInList = true
								break
							end
						end
						if not alreadyInList then
							table.insert(currentTagsMap[tagPart], pNo)
						end
					end
				end
			end
		end
	end

	for t, _ in pairs(currentTagsMap) do
		table.insert(allAvailableTags, t)
	end

	local activeTags = utils.loadActiveTags()
	local builtInRanks = {}
	for i, tag in ipairs(activeTags) do
		builtInRanks[tag] = i
	end

	table.sort(allAvailableTags, function(a, b)
		local countA = #(currentTagsMap[a] or {})
		local countB = #(currentTagsMap[b] or {})

		if countA ~= countB then
			return countA > countB
		end

		local rankA = builtInRanks[a]
		local rankB = builtInRanks[b]

		if rankA and rankB then
			return rankA < rankB
		elseif rankA then
			return true
		elseif rankB then
			return false
		else
			return a < b
		end
	end)
end

function action_browse.browseOrNextTag()
	if tagQueue and #tagQueue > 0 then
		local nextPage = table.remove(tagQueue, 1)
		jumpToPageAndShowTag(nextPage, currentBrowsingTag)
		if #tagQueue == 0 then
			app.openDialog("You've reviewed all pages for this tag!", { "OK" }, "onFinishBrowse")
		end
		return
	end

	if lastBrowsedPage and currentBrowsingTag then
		clearHighlight(lastBrowsedPage)
		lastBrowsedPage = nil
		currentBrowsingTag = nil
	end

	local doc = app.getDocumentStructure()
	buildTagsMap(1, #doc.pages)

	if #allAvailableTags == 0 then
		app.openDialog("No tags found in this document.", { "Close" })
		return
	end

	local clipText = utils.getClipboardText()
	clipText = (clipText:gsub("^%s*(.-)%s*$", "%1"))
	if clipText ~= "" and currentTagsMap[clipText] then
		startBrowsingSession(clipText, true)
		return
	end

	dialogCurrentPage = 1
	showTagSelectionDialog()
end

function action_browse.browseChapterTags()
	if tagQueue and #tagQueue > 0 then
		local nextPage = table.remove(tagQueue, 1)
		jumpToPageAndShowTag(nextPage, currentBrowsingTag)
		if #tagQueue == 0 then
			app.openDialog("You've reached the last tagged page in this chapter.", { "OK" }, "onFinishBrowse")
		end
		return
	end

	if lastBrowsedPage and currentBrowsingTag then
		clearHighlight(lastBrowsedPage)
		lastBrowsedPage = nil
		currentBrowsingTag = nil
	end

	local doc = app.getDocumentStructure()
	local currentPage = doc.currentPage
	local chapmarks = {}

	local allTexts = app.getTexts("all") or {}
	local labelLayerIds = {}
	for pNo, page in pairs(doc.pages) do
		if type(page) == "table" and page.layers then
			for lId, layer in pairs(page.layers) do
				if layer.name == "label" then
					labelLayerIds[pNo] = lId
					break
				end
			end
		end
	end

	for _, txt in pairs(allTexts) do
		local pNo = txt.page
		if labelLayerIds[pNo] and txt.layer == labelLayerIds[pNo] then
			if txt.color == 0x000000 or txt.color == 0 then
				local tagPart = txt.text:gsub("^%s*(.-)%s*$", "%1")
				if tagPart == "@chapter" then
					table.insert(chapmarks, pNo)
				end
			end
		end
	end

	table.sort(chapmarks)
	local startPage, endPage = 1, #doc.pages
	for _, cp in ipairs(chapmarks) do
		if cp <= currentPage then
			startPage = cp
		elseif cp > currentPage then
			endPage = cp - 1
			break
		end
	end

	buildTagsMap(startPage, endPage)

	if #allAvailableTags == 0 then
		app.openDialog(string.format("No tags found in current chapter (P%d-P%d).", startPage, endPage), { "Close" })
		return
	end

	local clipText = utils.getClipboardText()
	clipText = (clipText:gsub("^%s*(.-)%s*$", "%1"))
	if clipText ~= "" and currentTagsMap[clipText] then
		startBrowsingSession(clipText, true)
		return
	end

	dialogCurrentPage = 1
	showTagSelectionDialog()
end

function action_browse.onTagDialogResult(selectedIndex)
	if not selectedIndex then
		return
	end
	local btnLabel = nil
	if type(selectedIndex) == "number" then
		btnLabel = currentButtons[selectedIndex] or currentButtons[selectedIndex + 1]
	elseif type(selectedIndex) == "string" then
		btnLabel = selectedIndex
	end

	if not btnLabel or btnLabel == "Cancel" then
		return
	end
	if btnLabel == "[ Previous ]" then
		dialogCurrentPage = dialogCurrentPage - 1
		showTagSelectionDialog()
		return
	elseif btnLabel == "[ Next ]" then
		dialogCurrentPage = dialogCurrentPage + 1
		showTagSelectionDialog()
		return
	end

	local actualTagStr = btnLabel:match("^(.-)%s*%(%d+%)$") or btnLabel

	if currentTagsMap[actualTagStr] then
		startBrowsingSession(actualTagStr, false)
	end
end

function action_browse.onFinishBrowse(selectedIndex)
	if lastBrowsedPage and currentBrowsingTag then
		clearHighlight(lastBrowsedPage)
		lastBrowsedPage = nil
		currentBrowsingTag = nil
	end
end

return action_browse
