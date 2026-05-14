-- ============================================================================
-- xopp_helpers.lua | XOURNAL++ CORE RENDERING & HELPERS
-- ============================================================================
local utils = require("utils")
local helpers = {}

function helpers.deleteSourceText(clipboardContent)
	if not clipboardContent or clipboardContent == "" then
		return
	end
	local rawContent = clipboardContent:gsub("^%s*(.-)%s*$", "%1")
	local allTextsOnLayer = app.getTexts("layer")

	if allTextsOnLayer then
		local refsToDelete = {}
		for _, txt in pairs(allTextsOnLayer) do
			if type(txt) == "table" and txt.text then
				local layerText = txt.text:gsub("^%s*(.-)%s*$", "%1")
				if layerText == rawContent then
					table.insert(refsToDelete, txt.ref)
				end
			end
		end
		if #refsToDelete > 0 then
			app.addToSelection(refsToDelete)
			app.activateAction("delete")
		end
	end
end

function helpers.getPageData(pageNo)
	local data = { tags = {}, note = nil, chapterNote = nil }
	local doc = app.getDocumentStructure()
	if not doc or not doc.pages[pageNo] then
		return data
	end

	local originalPage = doc.currentPage
	local needsSwitch = (originalPage ~= pageNo)

	if needsSwitch then
		app.setCurrentPage(pageNo)
	end

	local labelLayerId = nil
	for l, layer in pairs(doc.pages[pageNo].layers) do
		if layer.name == "label" then
			labelLayerId = l
			break
		end
	end

	if labelLayerId then
		local pageTexts = app.getTexts("page") or {}
		for _, txt in pairs(pageTexts) do
			if txt.layer == labelLayerId then
				local clean = txt.text:gsub("^%s*(.-)%s*$", "%1")
				if clean ~= "" then
					if txt.color == 0xFF0000 or txt.color == 16711680 then
						if txt.x < 100 then
							data.chapterNote = clean
						else
							data.note = clean
						end
					elseif txt.color == 0x000000 or txt.color == 0 then
						local isValid = (clean == "@chapter")
						if not isValid then
							isValid, _ = utils.isValidTag(clean)
						end
						if isValid and txt.y < 15 then
							table.insert(data.tags, clean)
						end
					end
				end
			end
		end
	end

	if needsSwitch then
		app.setCurrentPage(originalPage)
	end

	return data
end

function helpers.renderPageLabels(pageNo, pageData, highlightTag)
	local doc = app.getDocumentStructure()
	local page = doc.pages[pageNo]
	local originalLayerId = page.currentLayer
	local labelLayerId = nil

	for l, layer in pairs(page.layers) do
		if layer.name == "label" then
			labelLayerId = l
			break
		end
	end

	if not labelLayerId then
		if #pageData.tags == 0 and not pageData.note and not pageData.chapterNote then
			return
		end
		app.setCurrentLayer(1, false)
		app.activateAction("layer-new-below-current")
		app.setCurrentLayerName("label")
		labelLayerId = 1
		originalLayerId = originalLayerId + 1
	end

	app.setCurrentLayer(labelLayerId, false)

	local texts = app.getTexts("layer") or {}
	local strokes = app.getStrokes("layer") or {}
	local refs = {}
	for _, t in pairs(texts) do
		table.insert(refs, t.ref)
	end
	for _, s in pairs(strokes) do
		table.insert(refs, s.ref)
	end
	if #refs > 0 then
		app.addToSelection(refs)
		app.activateAction("delete")
	end

	if #pageData.tags == 0 and not pageData.note and not pageData.chapterNote then
		app.setCurrentLayer(originalLayerId, false)
		app.refreshPage()
		return
	end

	local baseFont = app.getFont()
	local labelFont = { name = baseFont.name, size = 12 }
	local strokesToDraw = {}
	local textsToDraw = {}

	local pageWidth = page.pageWidth or 595
	local currentRightEdge = pageWidth - 5
	local currentY = 5

	for _, tag in ipairs(pageData.tags) do
		local textWidth = utils.estimateTextWidth(tag, labelFont.size)
		local paddingX = 4
		local boxWidth = textWidth + (paddingX * 2)
		local boxHeight = 16
		local startX = currentRightEdge - boxWidth
		local endX = currentRightEdge

		if startX < 20 then
			currentRightEdge = pageWidth - 5
			currentY = currentY + boxHeight + 8
			endX = currentRightEdge
			startX = endX - boxWidth
		end

		local tagColor = utils.getColorForTag(tag)
		local rectX, rectY = utils.getRoundedRectPoints(startX, currentY, endX, currentY + boxHeight, 4)
		local rectP = {}
		for i = 1, #rectX do
			table.insert(rectP, 1.0)
		end

		table.insert(strokesToDraw, {
			["x"] = rectX,
			["y"] = rectY,
			["pressure"] = rectP,
			["tool"] = "highlighter",
			["width"] = 0.5,
			["color"] = tagColor,
			["fill"] = 155,
			["lineStyle"] = "solid",
		})

		if highlightTag == tag then
			local lineY = currentY + boxHeight + 2
			local lineX = { startX + 2, endX - 2 }
			table.insert(strokesToDraw, {
				["x"] = lineX,
				["y"] = { lineY, lineY },
				["pressure"] = { 1.0, 1.0 },
				["tool"] = "pen",
				["width"] = 2.0,
				["color"] = 0x000000,
				["fill"] = 0,
				["lineStyle"] = "solid",
			})
		end

		table.insert(textsToDraw, {
			text = tag,
			x = startX + paddingX + 0.5,
			y = currentY + 0.5,
			color = 0x000000,
			font = labelFont,
		})
		currentRightEdge = startX - 2
	end

	if pageData.note then
		local noteFont = app.getFont()
		local noteWidth = utils.estimateTextWidth(pageData.note, noteFont.size or 12)
		local tagsBottomY = currentY + 16
		local noteX = math.max(20, pageWidth - 5 - noteWidth)
		table.insert(textsToDraw, {
			text = pageData.note,
			x = noteX,
			y = tagsBottomY + 2,
			color = 0xFF0000,
			font = noteFont,
		})
	end

	if pageData.chapterNote then
		local noteFont = app.getFont()
		table.insert(textsToDraw, {
			text = pageData.chapterNote,
			x = 5,
			y = 5,
			color = 0xFF0000,
			font = noteFont,
		})
	end

	if #strokesToDraw > 0 then
		app.addStrokes({ ["strokes"] = strokesToDraw })
	end
	if #textsToDraw > 0 then
		app.addTexts({ texts = textsToDraw })
	end

	app.setCurrentLayer(originalLayerId, false)
	app.refreshPage()
end

return helpers
