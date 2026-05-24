-- ============================================================================
-- action_tag.lua | TAG CREATION, DELETION & QUICK ACTIONS
-- ============================================================================
local config = require("config")
local utils = require("utils")
local helpers = require("xopp_helpers")
local metadata = require("metadata")

local action_tag = {}

local deleteButtons = {}
local currentPageBeforeDelete = nil
local cachedDictApp = nil
local isDictConfigLoaded = false

local function applyQuickTag(tagName, initialText)
	local doc = app.getDocumentStructure()
	local pageNo = doc.currentPage
	local data = helpers.getPageData(pageNo)

	local exists = false
	for _, t in ipairs(data.tags) do
		if t == tagName then
			exists = true
			break
		end
	end

	if not exists then
		if #data.tags >= config.MAX_TAGS_PER_PAGE then
			app.openDialog("⚠️ Too many tags on this page.", { "OK" })
			return
		end
		table.insert(data.tags, tagName)
	end

	if initialText and initialText ~= "" then
		if tagName == "@chapter" then
			data.chapterNote = initialText
		else
			data.note = tagName .. ": " .. initialText
		end
	end

	helpers.renderPageLabels(pageNo, data)
end

local function getDictAppConfig()
	if isDictConfigLoaded then
		return cachedDictApp
	end
	local dbText = metadata.getMetadataText()
	if dbText ~= "" then
		local db = metadata.parseINI(dbText)
		if db["Common"] and db["Common"]["DictApp"] then
			cachedDictApp = string.lower(tostring(db["Common"]["DictApp"])):gsub("^%s*(.-)%s*$", "%1")
		end
	end
	isDictConfigLoaded = true
	return cachedDictApp
end

local function checkAndOpenDict(word)
	if string.match(word, "^[a-zA-Z%-]+$") then
		local dictApp = getDictAppConfig()
		if dictApp == "eudic" then
			os.execute("open 'eudic://dict/" .. word .. "'")
		elseif dictApp == "easydict" then
			os.execute(
				"open 'raycast://extensions/isfeng/easydict/easydict?arguments=%7B%22queryText%22%3A%22"
					.. word
					.. "%22%7D'"
			)
		end
	end
end

function action_tag.addVocabTag()
	local content = utils.getClipboardText()
	if content == "" then
		return
	end

	local word = (content:gsub("^%s*(.-)%s*$", "%1"))
	if #word > 50 then
		app.openDialog("⚠️ Vocabulary word is too long (maximum 50 characters).", { "OK" })
		return
	end
	if word == "" then
		return
	end

	local dbText = metadata.getMetadataText()
	local db = metadata.parseINI(dbText)
	if not db["Tagger"] then
		db["Tagger"] = {}
	end

	local existingVocabStr = db["Tagger"]["VocabList"] or ""
	local vocabList = {}
	local isDuplicate = false

	for w in string.gmatch(existingVocabStr, "([^,]+)") do
		local cleanW = w:gsub("^%s*(.-)%s*$", "%1")
		if cleanW ~= "" then
			table.insert(vocabList, cleanW)
			if string.lower(cleanW) == string.lower(word) then
				isDuplicate = true
			end
		end
	end

	if not isDuplicate then
		table.insert(vocabList, word)
		db["Tagger"]["VocabList"] = table.concat(vocabList, ", ")
		metadata.writeMetadata(db)
	end

	applyQuickTag("vocab", nil)

	helpers.deleteSourceText(content)
	checkAndOpenDict(word)
end

function action_tag.addTagAndNote()
	local content = utils.getClipboardText()
	if content == "" then
		return
	end

	local tag, note = string.match(content, "^(.-)%s*:%s*(.*)")
	if not tag or not note then
		return
	end

	tag = (tag:gsub("^%s*(.-)%s*$", "%1"))
	local isValid, _ = utils.isValidTag(tag)
	if not isValid then
		return
	end

	note = (note:gsub("^%s*(.-)%s*$", "%1")):gsub("\r\n", "\n"):gsub("\r", "\n")
	local _, lineCount = note:gsub("\n", "\n")
	if (lineCount + 1) > 2 then
		app.openDialog("⚠️ Note is too long (Max 2 lines).", { "OK" })
		return
	end

	local doc = app.getDocumentStructure()
	local pageNo = doc.currentPage
	local data = helpers.getPageData(pageNo)

	local exists = false
	for _, t in ipairs(data.tags) do
		if t == tag then
			exists = true
			break
		end
	end

	if not exists then
		if #data.tags >= config.MAX_TAGS_PER_PAGE then
			app.openDialog("⚠️ Too many tags.", { "OK" })
			return
		end
		table.insert(data.tags, tag)
	end

	if tag == "@chapter" then
		data.chapterNote = note
	else
		data.note = tag .. ": " .. note
	end

	helpers.deleteSourceText(content)
	helpers.renderPageLabels(pageNo, data)
end

function action_tag.deleteTagUI()
	local doc = app.getDocumentStructure()
	local pageNo = doc.currentPage
	local data = helpers.getPageData(pageNo)

	deleteButtons = {}
	currentPageBeforeDelete = pageNo

	for _, t in ipairs(data.tags) do
		table.insert(deleteButtons, t)
	end

	if #deleteButtons == 0 then
		app.openDialog("There are no tags on this page to remove.", { "OK" })
		return
	end
	table.insert(deleteButtons, "Cancel")
	app.openDialog("Choose a tag to remove from this page:", deleteButtons, "onDeleteTagResult")
end

function action_tag.onDeleteTagResult(selectedIndex)
	if not selectedIndex then
		return
	end
	local tagName = deleteButtons[selectedIndex] or deleteButtons[selectedIndex + 1]

	if tagName and tagName ~= "Cancel" then
		local data = helpers.getPageData(currentPageBeforeDelete)
		local newTags = {}
		for _, t in ipairs(data.tags) do
			if t ~= tagName then
				table.insert(newTags, t)
			end
		end
		data.tags = newTags

		if tagName == "@chapter" then
			data.chapterNote = nil
		end

		if data.note then
			local safeTagName = tagName:gsub("%-", "%%-")
			local matchPattern = "^" .. safeTagName .. "%s*:"
			if string.match(data.note, matchPattern) then
				data.note = nil
			end
		end

		if #data.tags == 0 then
			data.note = nil
		end

		helpers.renderPageLabels(currentPageBeforeDelete, data)
	end
end

function action_tag.toolbarQuickTagSlot(index)
	local activeTags = utils.loadActiveTags()
	local tagName = activeTags[index]
	if tagName then
		action_tag.toolbarQuickTag(tagName)
	end
end

function action_tag.toolbarQuickTag(tagName)
	if tagName == "chapter" then
		tagName = "@chapter"
	end
	local note = utils.getClipboardText()
	note = (note:gsub("^%s*(.-)%s*$", "%1"))

	if tagName == "@chapter" then
		local today = os.date("%Y%m%d")
		applyQuickTag("@chapter", "Chapter (" .. today .. ")")
	else
		applyQuickTag(tagName, nil)
	end
end

return action_tag
