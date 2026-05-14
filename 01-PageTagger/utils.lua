-- ============================================================================
-- utils.lua | UTILITY FUNCTIONS & HELPERS
-- ============================================================================
local config = require("config")
local metadata = require("metadata")
local utils = {}

utils.cachedActiveTags = nil
utils.cachedTheme = nil

function utils.loadActiveTags()
	if utils.cachedActiveTags then
		return utils.cachedActiveTags
	end
	local defaultTags = config.DEFAULT_QUICK_TAGS

	local dbText = metadata.getMetadataText()
	if dbText == "" then
		utils.cachedActiveTags = defaultTags
		return defaultTags
	end

	local db = metadata.parseINI(dbText)
	local tagStr = db["Tagger"] and db["Tagger"]["quick_tags"]

	if not tagStr or tagStr == "" then
		utils.cachedActiveTags = defaultTags
		return defaultTags
	end

	local parsedTags = {}
	for token in string.gmatch(tagStr, "([^,]+)") do
		local clean = token:gsub("^%s*(.-)%s*$", "%1")
		if clean ~= "" then
			table.insert(parsedTags, clean)
		end
	end

	if #parsedTags == 6 then
		local valid = true
		for _, pt in ipairs(parsedTags) do
			if not utils.isValidTag(pt) then
				valid = false
				break
			end
		end
		if valid then
			utils.cachedActiveTags = parsedTags
			return parsedTags
		end
	end

	utils.cachedActiveTags = defaultTags
	return defaultTags
end

function utils.loadTheme()
	if utils.cachedTheme then
		return utils.cachedTheme
	end

	local theme = {
		colors = {},
		chapter = 0xFF1493,
	}
	for i, c in ipairs(config.TAG_COLORS) do
		theme.colors[i] = c
	end

	local dbText = metadata.getMetadataText()
	if dbText ~= "" then
		local db = metadata.parseINI(dbText)
		if db["Tagger"] then
			local colorStr = db["Tagger"]["tag_colors"]
			if colorStr then
				local parsedColors = {}
				for token in string.gmatch(colorStr, "([^,，]+)") do
					local clean = token:gsub("^%s*(.-)%s*$", "%1"):gsub("^#", ""):gsub("^0x", "")
					local colorNum = tonumber(clean, 16)
					if colorNum then
						table.insert(parsedColors, colorNum)
					end
				end
				if #parsedColors >= 6 then
					for i = 1, 6 do
						theme.colors[i] = parsedColors[i]
					end
				end
			end

			local chapStr = db["Tagger"]["chapter_color"]
			if chapStr then
				local clean = chapStr:gsub("^%s*(.-)%s*$", "%1"):gsub("^#", ""):gsub("^0x", "")
				local colorNum = tonumber(clean, 16)
				if colorNum then
					theme.chapter = colorNum
				end
			end
		end
	end

	utils.cachedTheme = theme
	return theme
end

function utils.getColorForTag(tag)
	local theme = utils.loadTheme()

	if tag == "@chapter" or tag == "chapter" then
		return theme.chapter
	end

	local activeTags = utils.loadActiveTags()
	for i, builtinTag in ipairs(activeTags) do
		if tag == builtinTag then
			return theme.colors[i]
		end
	end

	local hash = 5381
	for i = 1, #tag do
		hash = (hash * 33 + string.byte(tag, i)) % 1000000007
	end
	local index = (hash % #config.CUSTOM_TAG_COLORS) + 1
	return config.CUSTOM_TAG_COLORS[index]
end

function utils.getRoundedRectPoints(left, top, right, bottom, radius)
	local ptsX, ptsY = {}, {}
	local numSegments = 4

	local function addArc(cx, cy, startDeg, endDeg)
		local step = (endDeg - startDeg) / numSegments
		for i = 0, numSegments do
			local rad = math.rad(startDeg + i * step)
			table.insert(ptsX, cx + radius * math.cos(rad))
			table.insert(ptsY, cy + radius * math.sin(rad))
		end
	end

	addArc(right - radius, top + radius, -90, 0)
	addArc(right - radius, bottom - radius, 0, 90)
	addArc(left + radius, bottom - radius, 90, 180)
	addArc(left + radius, top + radius, 180, 270)

	table.insert(ptsX, ptsX[1])
	table.insert(ptsY, ptsY[1])

	return ptsX, ptsY
end

function utils.getClipboardText()
	local os_type = "unknown"
	if package.config:sub(1, 1) == "\\" then
		os_type = "Windows"
	else
		local handle = io.popen("uname -s")
		if handle then
			local result = handle:read("*l")
			handle:close()
			os_type = (result == "Darwin") and "macOS" or "Linux"
		end
	end

	local cmd = (os_type == "macOS") and "pbpaste"
		or (os_type == "Windows") and 'powershell -command "Get-Clipboard"'
		or "wl-paste 2>/dev/null || xclip -selection clipboard -o 2>/dev/null"

	local handle = io.popen(cmd)
	if not handle then
		return ""
	end

	local result = handle:read("*a")
	handle:close()
	return (result:gsub("^%s*(.-)%s*$", "%1"))
end

function utils.isValidTag(tag)
	if #tag == 0 then
		return false, "Tag cannot be empty."
	end
	if #tag > 10 then
		return false, "Tag length (" .. #tag .. ") exceeds 10 characters."
	end

	local pattern = "[^%w_%-#]"
	local invalidChar = string.match(tag, pattern)

	if invalidChar then
		if invalidChar == " " then
			return false, "Tag cannot contain spaces."
		end
		return false, "Invalid character detected: " .. invalidChar
	end

	return true, ""
end

function utils.estimateTextWidth(text, fontSize)
	local maxWidth = 0
	local normalizedText = text:gsub("\r\n", "\n"):gsub("\r", "\n")

	for line in string.gmatch(normalizedText .. "\n", "(.-)\n") do
		local width = 0
		local i = 1
		while i <= #line do
			local b = string.byte(line, i)
			if b < 128 then
				local char = string.char(b)
				if char == "i" or char == "l" or char == "1" or char == "'" or char == "|" then
					width = width + fontSize * 0.25
				elseif
					char == "t"
					or char == "f"
					or char == "r"
					or char == "j"
					or char == "1"
					or char == "I"
					or char == " "
					or char == "("
					or char == ")"
					or char == "."
					or char == ","
					or char == "/"
				then
					width = width + fontSize * 0.35
				elseif char == "@" then
					width = width + fontSize * 1
				elseif char:match("[mMwW#]") then
					width = width + fontSize * 0.80
				elseif char:match("%u") then
					width = width + fontSize * 0.65
				elseif char:match("%d") then
					width = width + fontSize * 0.60
				else
					width = width + fontSize * 0.52
				end
				i = i + 1
			elseif b >= 192 and b < 224 then
				width = width + fontSize * 1.0
				i = i + 2
			elseif b >= 224 and b < 240 then
				width = width + fontSize * 1.0
				i = i + 3
			elseif b >= 240 then
				width = width + fontSize * 1.0
				i = i + 4
			else
				i = i + 1
			end
		end
		if width > maxWidth then
			maxWidth = width
		end
	end
	return maxWidth
end

return utils
