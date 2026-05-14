-- ============================================================================
-- action_sys.lua | SYSTEM OPERATIONS & DATABASE SYNC
-- ============================================================================
local utils = require("utils")
local metadata = require("metadata")

local action_sys = {}

function action_sys.sanitizeWorkspace()
	local doc = app.getDocumentStructure()
	local startPage = doc.currentPage
	local suspiciousPages = {}
	local processedCount = 0
	local fixedCount = 0

	for pNo = 1, #doc.pages do
		local page = doc.pages[pNo]
		local hasLegacy = false
		local hasLabel = false
		local hasMeta = false

		-- 1.
		if page.layers then
			for _, layer in pairs(page.layers) do
				local name = layer.name or ""
				if name:sub(1, 4) == "tag_" then
					hasLegacy = true
				end
				if name == "label" then
					hasLabel = true
				end
				if name == "@metadata" then
					hasMeta = true
				end
			end
		end

		if hasLegacy or hasLabel or hasMeta then
			app.setCurrentPage(pNo)
			processedCount = processedCount + 1

			local pageFixed = false
			local originalLayerId = app.getDocumentStructure().pages[pNo].currentLayer

			-- A.
			local function moveLayerToBottom(layerName)
				local currentDoc = app.getDocumentStructure()
				local currentPage = currentDoc.pages[pNo]
				local currentId = nil
				for id, layer in pairs(currentPage.layers) do
					if layer.name == layerName then
						currentId = id
						break
					end
				end

				if currentId and currentId > 1 then
					local moves = currentId - 1
					for i = 1, moves do
						app.setCurrentLayer(currentId, false)
						app.activateAction("layer-move-down")
						if (currentId - 1) == originalLayerId then
							originalLayerId = originalLayerId + 1
						end
						currentId = currentId - 1
					end
				end
			end

			local checkDoc = app.getDocumentStructure()
			local checkPage = checkDoc.pages[pNo]
			local mId, lId = nil, nil
			for id, layer in pairs(checkPage.layers) do
				if layer.name == "@metadata" then
					mId = id
				end
				if layer.name == "label" then
					lId = id
				end
			end

			local expectedLabelId = mId and 2 or 1
			if (mId and mId ~= 1) or (lId and lId ~= expectedLabelId) then
				pageFixed = true
				moveLayerToBottom("label")
				moveLayerToBottom("@metadata")
			end

			-- B.
			local finalPage = app.getDocumentStructure().pages[pNo]
			local labelId, metaId = nil, nil
			for id, layer in pairs(finalPage.layers) do
				if layer.name == "label" then
					labelId = id
				elseif layer.name == "@metadata" then
					metaId = id
				end
			end

			if metaId then
				if finalPage.layers[metaId].isVisible ~= false then
					pageFixed = true
					app.setCurrentLayer(metaId, false)
					app.setLayerVisibility(false)
				end
			end

			if labelId then
				if finalPage.layers[labelId].isVisible ~= true then
					pageFixed = true
					app.setCurrentLayer(labelId, false)
					app.setLayerVisibility(true)
				end

				local isAbnormal = false
				local texts = app.getTexts("page") or {}
				for _, t in pairs(texts) do
					if t.layer == labelId and t.y > 30 then
						isAbnormal = true
						break
					end
				end
				if not isAbnormal then
					local imgs = app.getImages("page") or {}
					for _, img in pairs(imgs) do
						if img.layer == labelId then
							isAbnormal = true
							break
						end
					end
				end
				if isAbnormal then
					table.insert(suspiciousPages, pNo)
				end
			end

			-- C.
			local targetLayer = finalPage.layers[originalLayerId]
			if targetLayer and (targetLayer.name == "label" or targetLayer.name == "@metadata") then
				pageFixed = true
				local topNonSystemLayer = nil
				for id, l in pairs(finalPage.layers) do
					if l.name ~= "label" and l.name ~= "@metadata" then
						if not topNonSystemLayer or id > topNonSystemLayer then
							topNonSystemLayer = id
						end
					end
				end
				if topNonSystemLayer then
					originalLayerId = topNonSystemLayer
				end
			end

			app.setCurrentLayer(originalLayerId, false)
			if pageFixed then
				fixedCount = fixedCount + 1
			end
		end
	end

	app.setCurrentPage(startPage)
	app.scrollToPage(startPage)
	app.refreshPage()

	local resultMsg = string.format("✅ Workspace Sanitized.\n\n (%d fixed, %d processed)", fixedCount, processedCount)
	if #suspiciousPages > 0 then
		resultMsg = resultMsg
			.. "\n\n⚠️ Warning: Abnormal content (notes/images) detected in 'label' layer on:\n"
			.. table.concat(suspiciousPages, ", ")
	end
	app.openDialog(resultMsg, { "OK" })
end

function action_sys.generateAndInstallIcons()
	local isWindows = package.config:sub(1, 1) == "\\"
	local iconDir, mkdirCmd = "", ""

	if isWindows then
		iconDir = os.getenv("LOCALAPPDATA") .. "\\icons\\"
		mkdirCmd = 'if not exist "' .. iconDir .. '" mkdir "' .. iconDir .. '"'
	else
		iconDir = os.getenv("HOME") .. "/.local/share/icons/"
		mkdirCmd = 'mkdir -p "' .. iconDir .. '"'
	end

	os.execute(mkdirCmd)
	local svgBase =
		[[<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64"><rect width="64" height="64" rx="14" fill="%s" opacity="0.6"/>%s</svg>]]

	local function buildSvgText(str)
		local len = #str
		if len <= 5 then
			return string.format(
				'<text x="32" y="40" font-family="-apple-system, sans-serif" font-size="24" font-weight="bold" fill="#000000" text-anchor="middle">%s</text>',
				str
			)
		else
			local mid = math.ceil(len / 2)
			local line1 = string.sub(str, 1, mid)
			local line2 = string.sub(str, mid + 1)

			return string.format(
				'<text x="32" y="28" font-family="-apple-system, sans-serif" font-size="24" font-weight="bold" fill="#000000" text-anchor="middle">%s</text>'
					.. '<text x="32" y="48" font-family="-apple-system, sans-serif" font-size="24" font-weight="bold" fill="#000000" text-anchor="middle">%s</text>',
				line1,
				line2
			)
		end
	end

	local activeTags = utils.loadActiveTags()
	for i, tagName in ipairs(activeTags) do
		local file = io.open(iconDir .. "tag_icon_" .. i .. ".svg", "w")
		if file then
			local hexColor = string.format("#%06X", utils.getColorForTag(tagName))
			file:write(string.format(svgBase, hexColor, buildSvgText(tagName)))
			file:close()
		end
	end

	local chapFile = io.open(iconDir .. "tag_icon_chapter.svg", "w")
	if chapFile then
		local chapColor = string.format("#%06X", utils.getColorForTag("@chapter"))
		chapFile:write(string.format(svgBase, chapColor, buildSvgText("chapter")))
		chapFile:close()
	end

	local vocabFile = io.open(iconDir .. "tag_icon_vocab.svg", "w")
	if vocabFile then
		local vocabColor = string.format("#%06X", utils.getColorForTag("vocab"))
		local vocabTextSvg = buildSvgText("Voc")
		vocabFile:write(string.format(svgBase, vocabColor, vocabTextSvg))
		vocabFile:close()
	end
end

function action_sys.setupToolbarIcons()
	local content = utils.getClipboardText()
	content = (content:gsub("^%s*(.-)%s*$", "%1"))

	local parsedTokens = {}
	if content ~= "" then
		for token in string.gmatch(content, "([^,，]+)") do
			local clean = token:gsub("^%s*(.-)%s*$", "%1")
			if clean ~= "" then
				table.insert(parsedTokens, clean)
			end
		end
	end

	local isColorMode, isTagMode = false, false
	local normalizedColors = {}

	if #parsedTokens == 6 then
		local allColors = true
		for _, t in ipairs(parsedTokens) do
			local cleanHex = t:gsub("^#", ""):gsub("^0[xX]", "")
			if string.match(cleanHex, "^%x%x%x%x%x%x$") then
				table.insert(normalizedColors, "#" .. string.upper(cleanHex))
			else
				allColors = false
				break
			end
		end

		if allColors then
			isColorMode = true
		else
			local allValidTags = true
			for _, t in ipairs(parsedTokens) do
				local isValid, _ = utils.isValidTag(t)
				if not isValid then
					allValidTags = false
					break
				end
			end
			if allValidTags then
				isTagMode = true
			end
		end
	end

	if isColorMode or isTagMode then
		local existingDbText = metadata.getMetadataText()
		local db = metadata.parseINI(existingDbText)
		if not db["Tagger"] then
			db["Tagger"] = {}
		end

		local finalOutputStr, successMsg = "", ""
		if isColorMode then
			db["Tagger"]["tag_colors"] = table.concat(normalizedColors, ", ")
			finalOutputStr = table.concat(normalizedColors, ", ")
		elseif isTagMode then
			db["Tagger"]["quick_tags"] = table.concat(parsedTokens, ", ")
			finalOutputStr = table.concat(parsedTokens, ", ")
		end

		metadata.writeMetadata(db)
		utils.cachedActiveTags, utils.cachedTheme = nil, nil
		action_sys.generateAndInstallIcons()
		app.openDialog("✅ Updated successfully!\n\nApplied: [" .. finalOutputStr .. "]", { "OK" })
	else
		utils.cachedActiveTags, utils.cachedTheme = nil, nil
		action_sys.generateAndInstallIcons()
		app.openDialog("ℹ️ No valid tags or colors found in clipboard.", { "OK" })
	end
end

return action_sys
