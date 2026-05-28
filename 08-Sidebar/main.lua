sidebarContext = nil

local metadata = require("metadata")

local cachedStoragePath = nil
local cachedHtml2MarkdownPath = nil

local MARKER_COLOR = 0xEF514E
local MARKER_THICKNESS_FACTOR = 2.123
local DEFAULT_MARKER_SCALE = 0.5

local os_name = package.config:sub(1, 1) == "\\" and "win" or "unix"
local is_mac = false

if os_name == "unix" then
	local f = io.popen("uname -s", "r")
	if f then
		local uname = f:read("*a")
		if uname:match("Darwin") then
			is_mac = true
		end
		f:close()
	end
end

local function showNote(msg)
	app.openDialog(msg, { "OK" }, "", false)
end

local function getUniqueTmpFile(ext)
	local base = os.tmpname()
	return base .. "_" .. tostring(math.floor(os.clock() * 10000)) .. ext
end

local function simpleHash(str)
	local h = 5381
	for i = 1, #str do
		h = (h * 33 + str:byte(i)) % 4294967296
	end
	return string.format("%08x", h)
end

local function utf8sub(str, numChars)
	local startIndex = 1
	while numChars > 0 and startIndex <= #str do
		local byte = string.byte(str, startIndex)
		if not byte then
			break
		end

		local bytes = 1
		if byte >= 192 and byte <= 223 then
			bytes = 2
		elseif byte >= 224 and byte <= 239 then
			bytes = 3
		elseif byte >= 240 and byte <= 247 then
			bytes = 4
		end

		if startIndex + bytes - 1 > #str then
			break
		end

		startIndex = startIndex + bytes
		numChars = numChars - 1
	end
	return str:sub(1, startIndex - 1)
end

local function getCenter()
	local doc = app.getDocumentStructure()
	if not doc or not doc.pages then
		return 297, 421
	end
	local pageNo = doc.currentPage
	local page = doc.pages[pageNo]
	local w = page.pageWidth or 595
	local h = page.pageHeight or 842
	return w / 2, h / 2
end

local function loadConfigFromMetadata()
	local text = metadata.getMetadataText()
	if text and text ~= "" then
		local db = metadata.parseINI(text)
		if db and db["Sidebar"] then
			if db["Sidebar"]["StoragePath"] then
				cachedStoragePath = db["Sidebar"]["StoragePath"]
			end
			if db["Sidebar"]["Html2MarkdownPath"] then
				cachedHtml2MarkdownPath = db["Sidebar"]["Html2MarkdownPath"]
			end
		end
	end
end

local function getBaseStorageDir()
	if not cachedStoragePath then
		loadConfigFromMetadata()
	end
	return cachedStoragePath
end

local function getHtml2MarkdownPath()
	if not cachedHtml2MarkdownPath then
		loadConfigFromMetadata()
	end
	return cachedHtml2MarkdownPath
end

local function getStorageDir()
	local baseDir = getBaseStorageDir()

	if not baseDir then
		app.openDialog(
			"⚠️ Storage path not configured!\n\nPlease copy your target folder path and click [Sidebar: Set Storage Path] in the menu.",
			{ "OK" },
			"",
			true
		)
		return nil
	end

	local doc = app.getDocumentStructure()
	if not doc then
		return baseDir .. "/Untitled/1"
	end

	local pageNo = doc.pages[doc.currentPage].pdfBackgroundPageNo
	if pageNo <= 0 then
		showNote("⚠️ Only supports saving to pages with a PDF background.")
		return nil
	end

	local filename = doc.xoppFilename
	if not filename or filename == "" then
		filename = doc.pdfBackgroundFilename
	end
	if not filename or filename == "" then
		filename = "Untitled"
	end

	local baseName = filename:match("([^/]+)$") or filename
	baseName = baseName:gsub("%.xopp$", ""):gsub("%.pdf$", "")

	return baseDir .. "/" .. baseName .. "/" .. pageNo
end

local digitPaths = {
	["0"] = { { 0, 1 }, { 0, 0 }, { 1, 0 }, { 1, 1 }, { 0, 1 } },
	["1"] = { { 0, 1 }, { 0.5, 1 }, { 0.5, 0 } },
	["2"] = { { 0, 1 }, { 1, 1 }, { 0, 1 }, { 0, 0.5 }, { 1, 0.5 }, { 1, 0 }, { 0, 0 } },
	["3"] = { { 0, 1 }, { 1, 1 }, { 1, 0 }, { 0, 0 }, { 1, 0 }, { 1, 0.5 }, { 0.2, 0.5 } },
	["4"] = { { 0, 1 }, { 0.8, 1 }, { 0.8, 0 }, { 0.8, 0.5 }, { 0, 0.5 }, { 0, 0 } },
	["5"] = { { 0, 1 }, { 1, 1 }, { 1, 0.5 }, { 0, 0.5 }, { 0, 0 }, { 1, 0 } },
	["6"] = { { 0, 1 }, { 1, 1 }, { 1, 0.5 }, { 0, 0.5 }, { 0, 1 }, { 0, 0 }, { 1, 0 } },
	["7"] = { { 0, 1 }, { 1, 0 }, { 0, 0 } },
	["8"] = { { 0, 1 }, { 1, 1 }, { 1, 0 }, { 0, 0 }, { 0, 1 }, { 0, 0.5 }, { 1, 0.5 } },
	["9"] = { { 0, 1 }, { 0.8, 1 }, { 1, 1 }, { 1, 0 }, { 0, 0 }, { 0, 0.5 }, { 1, 0.5 } },
}

local function getStoredItems()
	local dir = getStorageDir()
	if not dir then
		return nil
	end

	local items = {}
	local cmd = string.format('ls -1 "%s" 2>/dev/null', dir)
	local f = io.popen(cmd, "r")
	if f then
		for filename in f:lines() do
			local rc_str = filename:match("^(%d%d)%-")
			if rc_str and (filename:match("%.png$") or filename:match("%.md$")) then
				table.insert(items, {
					filename = filename,
					filepath = dir .. "/" .. filename,
					type = filename:match("%.png$") and "image" or "text",
					recall_count = tonumber(rc_str) or 0,
				})
			end
		end
		f:close()
	end

	table.sort(items, function(a, b)
		local timeA = a.filename:match("^%d%d%-(%d+)") or "0"
		local timeB = b.filename:match("^%d%d%-(%d+)") or "0"
		return timeA < timeB
	end)

	return items
end

local function incrementRecallCountAndRename(item)
	local dir = getStorageDir()
	local rc_str, rest = item.filename:match("^(%d%d)%-(.*)$")
	if rc_str and rest then
		local rc = tonumber(rc_str)
		if rc < 99 then
			rc = rc + 1
		end
		local newRcStr = string.format("%02d", rc)
		local newFilename = newRcStr .. "-" .. rest
		local newFilepath = dir .. "/" .. newFilename
		os.rename(item.filepath, newFilepath)
		return newFilepath
	end
	return item.filepath
end

local function updateSidebarMarker()
	local items = getStoredItems() or {}
	local stash_count = #items

	local refsToDelete = {}
	local center_x, center_y = nil, nil
	local current_marker_scale = DEFAULT_MARKER_SCALE
	local recall_count = 0

	for _, item in ipairs(items) do
		recall_count = recall_count + (item.recall_count or 0)
	end
	if recall_count > 99 then
		recall_count = 99
	end

	local currentColor = MARKER_COLOR

	local strokes = app.getStrokes("page") or {}
	for _, s in ipairs(strokes) do
		local is_marker = false

		if s.x and #s.x > 50 then
			local minx, maxx, miny, maxy = s.x[1], s.x[1], s.y[1], s.y[1]
			for i = 2, #s.x do
				if s.x[i] < minx then
					minx = s.x[i]
				end
				if s.x[i] > maxx then
					maxx = s.x[i]
				end
				if s.y[i] < miny then
					miny = s.y[i]
				end
				if s.y[i] > maxy then
					maxy = s.y[i]
				end
			end

			local bb_width = maxx - minx
			local bb_height = maxy - miny
			local max_bb = math.max(bb_width, bb_height)

			if max_bb > 10 then
				local user_scale = max_bb / 84

				local is_square = math.abs(bb_width - bb_height) < (0.05 * max_bb)

				local expected_width = MARKER_THICKNESS_FACTOR * user_scale
				local width_matches = false

				if s.width and (math.abs(s.width - expected_width) < (0.05 * expected_width)) then
					width_matches = true
				end

				local color_matches = (s.color == MARKER_COLOR) or (s.fill == 67)

				if is_square and width_matches and color_matches then
					is_marker = true
					current_marker_scale = user_scale
					center_x = (minx + maxx) / 2
					center_y = (miny + maxy) / 2
				end
			end
		end

		if is_marker then
			table.insert(refsToDelete, s.ref)
			currentColor = s.color
			break
		end
	end

	if #refsToDelete > 0 then
		app.clearSelection()
		app.addToSelection(refsToDelete)
		app.activateAction("delete")
	end

	if stash_count == 0 then
		app.refreshPage()
		return
	end

	local cx, cy = center_x, center_y
	if not cx or not cy then
		cx, cy = getCenter()
	end

	local X, Y, P = {}, {}

	local function p(x, y)
		table.insert(X, x)
		table.insert(Y, y)
	end

	local function retrace(from_idx)
		for i = #X - 1, from_idx, -1 do
			p(X[i], Y[i])
		end
	end

	local function arc(ax, ay, rad, start_angle, end_angle, steps)
		for i = 0, steps do
			local a = start_angle + (end_angle - start_angle) * (i / steps)
			p(ax + rad * math.cos(math.rad(a)), ay + rad * math.sin(math.rad(a)))
		end
	end

	local R = 28 * current_marker_scale
	local R_OUT = 42 * current_marker_scale
	local S = R * 0.70710678

	local max_w = 34 * current_marker_scale
	local W_BASE = 7 * current_marker_scale
	local H_BASE = 12 * current_marker_scale
	local SPACING_BASE = 4 * current_marker_scale

	local function drawEmbeddedText(textStr, cx_offset, cy_offset, is_left)
		local w, h, sp = W_BASE, H_BASE, SPACING_BASE
		local total_w = #textStr * w + (#textStr - 1) * sp
		if total_w > max_w then
			local scale = max_w / total_w
			w = w * scale
			h = h * scale
			sp = sp * scale
			total_w = max_w
		end

		local start_x = cx + cx_offset * current_marker_scale - total_w / 2
		local bottom_y = cy + cy_offset * current_marker_scale
		local edge_x = is_left and (cx - S) or (cx + S)

		p(edge_x, bottom_y)
		p(start_x, bottom_y)

		for i = 1, #textStr do
			local char = textStr:sub(i, i)
			local char_x = start_x + (i - 1) * (w + sp)
			local mark_char = #X
			p(char_x, bottom_y)
			local path = digitPaths[char] or digitPaths["0"]
			for _, pt in ipairs(path) do
				p(char_x + pt[1] * w, bottom_y - h + pt[2] * h)
			end
			retrace(mark_char)
		end

		p(edge_x, bottom_y)
	end

	p(cx, cy - R)

	local mark_shell = #X
	p(cx, cy - R_OUT)
	arc(cx, cy, R_OUT, 270, 180, 12)

	local mark_L_conn = #X
	p(cx - R, cy)
	retrace(mark_L_conn)

	arc(cx, cy, R_OUT, 180, 90, 12)

	local mark_B_conn = #X
	p(cx, cy + R)
	retrace(mark_B_conn)

	arc(cx, cy, R_OUT, 90, 0, 12)

	local mark_R_conn = #X
	p(cx + R, cy)
	retrace(mark_R_conn)

	arc(cx, cy, R_OUT, 0, -90, 12)

	retrace(mark_shell)

	arc(cx, cy, R, 270, 225, 8)

	local mark_inner_start = #X

	p(cx - S, cy - 3 * current_marker_scale)
	drawEmbeddedText(tostring(stash_count), -9, -3, true)

	p(cx - S, cy + S)

	local mark_slash = #X
	p(cx + S, cy - S)
	retrace(mark_slash)

	p(cx + S, cy + S)

	p(cx + S, cy + 16 * current_marker_scale)
	drawEmbeddedText(tostring(recall_count), 9, 16, false)

	p(cx + S, cy - S)
	p(cx - S, cy - S)

	retrace(mark_inner_start)

	arc(cx, cy, R, 225, 180, 8)
	arc(cx, cy, R, 180, 90, 16)
	arc(cx, cy, R, 90, 0, 16)
	arc(cx, cy, R, 0, -90, 16)

	local stroke_visual_thickness = MARKER_THICKNESS_FACTOR * current_marker_scale

	local dynamic_pressure = 1.0 * (current_marker_scale / DEFAULT_MARKER_SCALE)

	local P = {}
	for i = 1, #X do
		table.insert(P, dynamic_pressure)
	end

	app.addStrokes({
		strokes = {
			{
				x = X,
				y = Y,
				pressure = P,
				tool = "pen",
				width = stroke_visual_thickness,
				color = currentColor,
				fill = 67,
				lineStyle = "solid",
			},
		},
		allowUndoRedoAction = "none",
	})
	app.refreshPage()
end

local function getClipboardText()
	local text = ""
	if is_mac then
		local f = io.popen("pbpaste 2>/dev/null", "r")
		if f then
			text = f:read("*a")
			f:close()
		end
	else
		local f = io.popen("xclip -selection clipboard -o 2>/dev/null", "r")
		if f then
			text = f:read("*a")
			f:close()
		end
	end
	return text and text:match("^%s*(.-)%s*$") or ""
end

local function getSmartClipboardData()
	local imgPath = getUniqueTmpFile(".png")
	if is_mac then
		local infoF = io.popen("osascript -e 'clipboard info' 2>/dev/null", "r")
		local info = infoF:read("*a") or ""
		infoF:close()
		if info:match("TIFF") or info:match("PNGf") or info:match("JPEG") then
			local tiffPath = getUniqueTmpFile(".tiff")
			local cmd = string.format(
				"osascript -e 'try' -e 'set f to open for access POSIX file \"%s\" with write permission' -e 'set eof of f to 0' -e 'write (the clipboard as TIFF picture) to f' -e 'close access f' -e 'end try'",
				tiffPath
			)
			os.execute(cmd)
			local fCheck = io.open(tiffPath, "rb")
			if fCheck then
				fCheck:close()
				os.execute(string.format("sips -s format png '%s' --out '%s' >/dev/null 2>&1", tiffPath, imgPath))
				os.remove(tiffPath)
			end
		end
	else
		os.execute('xclip -selection clipboard -t image/png -o > "' .. imgPath .. '" 2>/dev/null')
	end

	local f = io.open(imgPath, "rb")
	if f then
		local data = f:read("*a")
		f:close()
		os.remove(imgPath)
		if data and #data > 0 then
			return { type = "image", data = data }
		end
	end

	local html2mdPath = getHtml2MarkdownPath()
	if html2mdPath and html2mdPath ~= "" then
		local cmd = ""
		if is_mac then
			cmd = string.format(
				"osascript -e 'the clipboard as «class HTML»' 2>/dev/null | perl -ne 'if (/«data HTML([0-9a-fA-F]+)»/i) { my $hex = $1; print chr(hex($1)) while $hex =~ /([0-9a-fA-F]{2})/g; }' | \"%s\" --plugin-table --plugin-strikethrough 2>/dev/null",
				html2mdPath
			)
		else
			cmd = string.format(
				'xclip -selection clipboard -t text/html -o 2>/dev/null | "%s" --plugin-table --plugin-strikethrough 2>/dev/null',
				html2mdPath
			)
		end

		local hf = io.popen(cmd, "r")
		if hf then
			local mdData = hf:read("*a")
			hf:close()

			if mdData and #mdData > 0 then
				local bom = string.char(0xEF, 0xBB, 0xBF)
				if mdData:sub(1, 3) == bom then
					mdData = mdData:sub(4)
				end

				if mdData:match("%S") then
					return { type = "text", data = mdData }
				end
			end
		end
	end

	local text = getClipboardText()
	if text and text ~= "" then
		return { type = "text", data = text }
	end
	return nil
end

local function triggerRecallAction(parsedObj)
	if parsedObj.type == "text" then
		local tmpFile = getUniqueTmpFile(".txt")
		local f = io.open(tmpFile, "w")
		if f then
			f:write(parsedObj.data)
			f:close()
		end
		if is_mac then
			os.execute("cat '" .. tmpFile .. "' | pbcopy")
		else
			os.execute("cat '" .. tmpFile .. "' | xclip -selection clipboard -i 2>/dev/null")
		end
		os.remove(tmpFile)
	elseif parsedObj.type == "image" then
		local imgPath = getUniqueTmpFile(".png")
		local f = io.open(imgPath, "wb")
		if f then
			f:write(parsedObj.data)
			f:close()
		end
		if is_mac then
			local tiffPath = getUniqueTmpFile(".tiff")
			os.execute(string.format("sips -s format tiff '%s' --out '%s' >/dev/null 2>&1", imgPath, tiffPath))
			os.execute(
				string.format(
					"osascript -e 'set the clipboard to (read (POSIX file \"%s\") as TIFF picture)'",
					tiffPath
				)
			)
			os.remove(tiffPath)
		else
			os.execute('xclip -selection clipboard -t image/png -i "' .. imgPath .. '" 2>/dev/null')
		end
		os.remove(imgPath)
	end

	if is_mac then
		os.execute("open 'raycast://extensions/codiy/clipboard-preview/clipboard-preview'")
	else
		showNote(parsedObj.type == "image" and "✅ Image copied to clipboard!" or "✅ Text copied to clipboard!")
	end
end

local function showPaginatedDialog(action, items, page)
	local ITEMS_PER_PAGE = 7
	local startIdx = (page - 1) * ITEMS_PER_PAGE + 1
	local endIdx = math.min(startIdx + ITEMS_PER_PAGE - 1, #items)

	local msg = string.format(
		action == "recall" and "📚 Stashed items (Page %d):\n\n" or "🗑️ Select an item to delete (Page %d):\n\n",
		page
	)

	local dialogOptions = {}
	sidebarContext = {
		action = action,
		items = items,
		page = page,
		dialogMap = {},
	}

	for i = startIdx, endIdx do
		local item = items[i]
		local preview = ""

		if item.type == "image" then
			local f = io.open(item.filepath, "rb")
			local sizeKB = 0
			if f then
				local size = f:seek("end")
				sizeKB = math.floor((size or 0) / 1024)
				f:close()
			end
			preview = string.format("🖼️ [Image] - %d KB", sizeKB)
		else
			local f = io.open(item.filepath, "r")
			if f then
				local content = f:read(100) or ""
				preview = utf8sub(content:gsub("[\r\n\t]+", " "), 38) .. "..."
				f:close()
			else
				preview = "📄 [Text] (Unreadable)"
			end
		end

		local optionLabel = (action == "recall" and "📋 Item " or "🗑️ Delete ") .. i
		table.insert(dialogOptions, optionLabel)
		msg = msg .. string.format("[%d](r%d)\t%s\n", i, item.recall_count, preview)
		sidebarContext.dialogMap[#dialogOptions] = { type = "item", index = i, itemInfo = item }
	end

	if page > 1 then
		table.insert(dialogOptions, "⬅️ Prev Page")
		sidebarContext.dialogMap[#dialogOptions] = { type = "prev" }
	end

	if endIdx < #items then
		table.insert(dialogOptions, "➡️ Next Page")
		sidebarContext.dialogMap[#dialogOptions] = { type = "next" }
	end

	table.insert(dialogOptions, "🚫 Cancel")
	sidebarContext.dialogMap[#dialogOptions] = { type = "cancel" }

	app.openDialog(msg, dialogOptions, "handlePaginatedCallback", false)
end

function handlePaginatedCallback(selectedIndex)
	if not sidebarContext or not selectedIndex then
		sidebarContext = nil
		return
	end

	local idx = tonumber(selectedIndex)
	if not idx then
		sidebarContext = nil
		return
	end

	local mapEntry = sidebarContext.dialogMap[idx]
	if not mapEntry then
		mapEntry = sidebarContext.dialogMap[idx + 1]
	end
	if not mapEntry then
		sidebarContext = nil
		return
	end

	if mapEntry.type == "cancel" then
		sidebarContext = nil
		return
	elseif mapEntry.type == "prev" then
		showPaginatedDialog(sidebarContext.action, sidebarContext.items, sidebarContext.page - 1)
	elseif mapEntry.type == "next" then
		showPaginatedDialog(sidebarContext.action, sidebarContext.items, sidebarContext.page + 1)
	elseif mapEntry.type == "item" then
		local itemInfo = mapEntry.itemInfo

		if sidebarContext.action == "recall" then
			local f = io.open(itemInfo.filepath, "rb")
			if f then
				local fullData = f:read("*a")
				f:close()
				triggerRecallAction({ type = itemInfo.type, data = fullData })
				incrementRecallCountAndRename(itemInfo)
				updateSidebarMarker()
			else
				showNote("❌ Could not read file data.")
			end
			sidebarContext = nil
		elseif sidebarContext.action == "purge" then
			os.remove(itemInfo.filepath)
			showNote("✂️ Item deleted.")
			updateSidebarMarker()
			sidebarContext = nil
		end
	end
end

function stashSidebar()
	local clipObj = getSmartClipboardData()
	if not clipObj then
		return showNote("❌ Clipboard is empty. Please copy some text or image first.")
	end

	local dir = getStorageDir()
	if not dir then
		return
	end

	os.execute(string.format('mkdir -p "%s"', dir))

	local hash = simpleHash(clipObj.data)
	local ext = clipObj.type == "image" and ".png" or ".md"
	local timeStr = os.date("%Y%m%d%H%M%S")
	local newFilename = "00-" .. timeStr .. "-" .. hash .. ext
	local newFilepath = dir .. "/" .. newFilename

	local checkCmd = string.format('ls "%s"/[0-9][0-9]-*-%s.* 2>/dev/null', dir, hash)
	local checkF = io.popen(checkCmd, "r")
	if checkF then
		local res = checkF:read("*a")
		checkF:close()
		if res and res ~= "" then
			return showNote("⚠️ This item is already stored. Duplicate rejected.")
		end
	end

	local currentItems = getStoredItems() or {}
	if #currentItems >= 30 then
		return showNote("⚠️ Storage is full (max 30 items per page). Please delete some items first.")
	end

	local fOut = io.open(newFilepath, "wb")
	if fOut then
		fOut:write(clipObj.data)
		fOut:close()

		updateSidebarMarker()
		showNote(clipObj.type == "image" and "✅ Image stored locally!" or "✅ Text stored locally!")
	else
		showNote("❌ Failed to write file to Obsidian folder.")
	end
end

function recallSidebar()
	local items = getStoredItems()
	if not items then
		return
	end

	if #items == 0 then
		return showNote("📭 No stashed items found for this page.")
	end

	if #items > 0 then
		updateSidebarMarker()
	end

	if #items == 1 then
		local f = io.open(items[1].filepath, "rb")
		if f then
			local fullData = f:read("*a")
			f:close()
			triggerRecallAction({ type = items[1].type, data = fullData })
			incrementRecallCountAndRename(items[1])
			updateSidebarMarker()
			return
		end
	end

	showPaginatedDialog("recall", items, 1)
end

function purgeSidebar()
	local items = getStoredItems()
	if not items then
		return
	end

	if #items == 0 then
		return showNote("📭 Nothing to delete on this page.")
	end

	showPaginatedDialog("purge", items, 1)
end

function setStoragePath()
	local path = getClipboardText()
	if not path or path == "" then
		return showNote("❌ Clipboard is empty.\n\nPlease copy a path first.")
	end

	path = path:match("^%s*(.-)%s*$"):gsub('^"', ""):gsub('"$', "")

	local isHtml2Md = path:match("html2markdown") ~= nil

	local isDirOrFile = false
	if is_mac or os_name == "unix" then
		if isHtml2Md then
			local ret = os.execute('test -x "' .. path .. '"')
			isDirOrFile = (ret == 0 or ret == true)
		else
			local ret = os.execute('test -d "' .. path .. '"')
			isDirOrFile = (ret == 0 or ret == true)
		end
	else
		if isHtml2Md then
			local ret = os.execute('if exist "' .. path .. '" (exit 0) else (exit 1)')
			isDirOrFile = (ret == 0 or ret == true)
		else
			local ret = os.execute('if exist "' .. path .. '\\*" (exit 0) else (exit 1)')
			isDirOrFile = (ret == 0 or ret == true)
		end
	end

	if not isDirOrFile then
		if not (path:match("^/") or path:match("^[a-zA-Z]:\\")) then
			return showNote("❌ Invalid absolute path:\n" .. path)
		end
	end

	local text = metadata.getMetadataText()
	local db = {}
	if text and text ~= "" then
		db = metadata.parseINI(text)
	end

	if not db["Sidebar"] then
		db["Sidebar"] = {}
	end

	if isHtml2Md then
		db["Sidebar"]["Html2MarkdownPath"] = path
		local success = metadata.writeMetadata(db)
		if success then
			cachedHtml2MarkdownPath = path
			showNote("✅ Html2Markdown path updated to:\n" .. path)
		else
			showNote("❌ Failed to save html2markdown path.")
		end
	else
		db["Sidebar"]["StoragePath"] = path
		local success = metadata.writeMetadata(db)
		if success then
			cachedStoragePath = path
			showNote("✅ Storage path updated to:\n" .. path)
		else
			showNote("❌ Failed to save path configuration.")
		end
	end
end

function initUi()
	app.registerUi({
		["menu"] = "Sidebar: Stash Clipboard",
		["callback"] = "stashSidebar",
		["accelerator"] = "<Shift>w",
	})
	app.registerUi({ ["menu"] = "Sidebar: Recall & Read", ["callback"] = "recallSidebar", ["accelerator"] = "<Shift>r" })
	app.registerUi({ ["menu"] = "Sidebar: Purge Assets", ["callback"] = "purgeSidebar", ["accelerator"] = "<Shift>d" })
	app.registerUi({ ["menu"] = "Sidebar: Set Storage Path", ["callback"] = "setStoragePath" })
end
