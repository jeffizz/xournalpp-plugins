local metadata = {}

function metadata.getMetadataText()
	local doc = app.getDocumentStructure()
	if not doc or not doc.pages or not doc.pages[1] then
		return ""
	end
	local page1 = doc.pages[1]
	local dbLayerId = nil
	if page1.layers then
		for l, layer in pairs(page1.layers) do
			if type(layer) == "table" and layer.name == "@metadata" then
				dbLayerId = l
				break
			end
		end
	end
	if not dbLayerId then
		return ""
	end

	local allTexts = app.getTexts("all") or {}
	local dbText = ""
	for _, txt in pairs(allTexts) do
		if type(txt) == "table" and txt.page == 1 and txt.layer == dbLayerId then
			if txt.text and txt.text ~= "" then
				dbText = dbText .. txt.text .. "\n"
			end
			break
		end
	end
	return dbText
end

function metadata.parseINI(text)
	local db = {}
	local currentSection = "Global"
	for line in text:gmatch("[^\r\n]+") do
		line = line:match("^%s*(.-)%s*$")
		if line ~= "" then
			local section = line:match("^%[([^%]]+)%]$")
			if section then
				currentSection = section
				db[currentSection] = db[currentSection] or {}
			else
				local k, v = line:match("^([^=:]+)[=:]%s*(.+)$")
				if k and v then
					k = k:match("^%s*(.-)%s*$")
					v = v:match("^%s*(.-)%s*$")
					db[currentSection] = db[currentSection] or {}
					db[currentSection][k] = v
				end
			end
		end
	end
	return db
end

function metadata.stringifyINI(db)
	local lines = {}
	for section, keys in pairs(db) do
		table.insert(lines, "[" .. section .. "]")
		for k, v in pairs(keys) do
			table.insert(lines, k .. "=" .. v)
		end
		table.insert(lines, "")
	end
	return table.concat(lines, "\n")
end

function metadata.parseArray(str)
	local arr = {}
	for token in string.gmatch(str, "([^,]+)") do
		local num = tonumber(token)
		if num then
			table.insert(arr, num)
		end
	end
	return arr
end

function metadata.writeMetadata(db)
	local doc = app.getDocumentStructure()
	local originalPage = doc.currentPage

	app.setCurrentPage(1)

	local page1 = app.getDocumentStructure().pages[1]
	local originalLayerId = page1.currentLayer
	local dbLayerId = nil

	if page1.layers then
		for l, layer in pairs(page1.layers) do
			if type(layer) == "table" and layer.name == "@metadata" then
				dbLayerId = l
				break
			end
		end
	end

	if not dbLayerId then
		app.setCurrentLayer(1, false)
		app.activateAction("layer-new-below-current")
		app.setCurrentLayerName("@metadata")
		dbLayerId = 1
		originalLayerId = originalLayerId + 1
	end

	if not dbLayerId then
		app.setCurrentPage(originalPage)
		return false
	end

	app.setCurrentLayer(dbLayerId, false)

	local allTexts = app.getTexts("layer") or {}
	local refsToDelete = {}
	for _, txt in pairs(allTexts) do
		table.insert(refsToDelete, txt.ref)
	end
	if #refsToDelete > 0 then
		app.addToSelection(refsToDelete)
		app.activateAction("delete")
	end

	local newText = metadata.stringifyINI(db)
	local font = app.getFont()
	font.size = 10
	app.addTexts({
		texts = { { text = newText, x = 20, y = 20, color = 0x888888, font = font } },
	})

	app.setLayerVisibility(false)
	app.setCurrentLayer(originalLayerId, false)

	app.setCurrentPage(originalPage)
	return true
end

return metadata
