local DELIMITER = "\n\n🚀========== SIDEBAR ENTRY ==========\n\n"
sidebarContext = nil
sidebarDeleteContext = nil

local ICON_SIZE = 45

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

local function generateSidebarSvg(count, payload)
	local countStr = count > 0 and tostring(count) or ""

	return [[<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="100" height="100">
  <rect x="2" y="2" width="96" height="96" rx="13" fill="white" stroke="#000000" stroke-width="4"/>

  <path d="M 15 4 H 85 A 11 11 0 0 1 96 15 V 34 H 4 V 15 A 11 11 0 0 1 15 4 Z" fill="#4ade80" />

  <line x1="4" y1="34" x2="96" y2="34" stroke="#000000" stroke-width="4"/>
  <line x1="35" y1="34" x2="35" y2="98" stroke="#000000" stroke-width="4"/>

  <text x="50" y="26" font-family="monospace, sans-serif" font-size="22" font-weight="bold" fill="black" text-anchor="middle">sidebar</text>

  <line x1="4" y1="55" x2="25" y2="55" stroke="#000000" stroke-width="4" stroke-linecap="round"/>
  <line x1="10" y1="75" x2="25" y2="75" stroke="#000000" stroke-width="4" stroke-linecap="round"/>

  <text x="65" y="75" font-family="sans-serif" font-size="30" font-weight="bold" fill="#FF0002" text-anchor="middle">]] .. countStr .. [[</text>

  <desc id="sidebar-meta">:::COUNT:::]] .. tostring(count) .. [[:::ENDCOUNT::::::S1D3C4R:::]] .. payload .. [[:::END:::</desc>
</svg>]]
end

local function extractSidebarMeta(imgData)
	if type(imgData) ~= "string" then
		return nil, 0
	end
	local payload = nil
	local count = 0

	local ps, pe = string.find(imgData, ":::S1D3C4R:::", 1, true)
	if ps then
		local pend = string.find(imgData, ":::END:::", pe + 1, true)
		if pend then
			payload = string.sub(imgData, pe + 1, pend - 1)
		end
	end

	local cs, ce = string.find(imgData, ":::COUNT:::", 1, true)
	if cs then
		local cend = string.find(imgData, ":::ENDCOUNT:::", ce + 1, true)
		if cend then
			count = tonumber(string.sub(imgData, ce + 1, cend - 1)) or 0
		end
	end

	return payload, count
end

local function findSidebarSVG()
	local allImages = app.getImages("layer") or {}
	local targetImgRef, targetImgX, targetImgY = nil, nil, nil
	local rawText, currentCount = "", 0

	for _, img in ipairs(allImages) do
		local payload, count = extractSidebarMeta(img.data)
		if payload then
			rawText = rawText .. payload
			targetImgRef = img.ref
			targetImgX = img.x
			targetImgY = img.y
			currentCount = count
			break
		end
	end
	return targetImgRef, targetImgX, targetImgY, rawText, currentCount
end

local function getByteCount(byte)
	if not byte then
		return 1
	end
	if byte >= 0 and byte <= 127 then
		return 1
	elseif byte >= 192 and byte <= 223 then
		return 2
	elseif byte >= 224 and byte <= 239 then
		return 3
	elseif byte >= 240 and byte <= 247 then
		return 4
	end
	return 1
end

local function utf8sub(str, startChar, numChars)
	local startIndex = 1
	while startChar > 1 do
		local byte = string.byte(str, startIndex)
		if not byte then
			break
		end
		startIndex = startIndex + getByteCount(byte)
		startChar = startChar - 1
	end
	local currentIndex = startIndex
	while numChars > 0 and currentIndex <= #str do
		local byte = string.byte(str, currentIndex)
		if not byte then
			break
		end
		currentIndex = currentIndex + getByteCount(byte)
		numChars = numChars - 1
	end
	return str:sub(startIndex, currentIndex - 1)
end

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

local function getUniqueTmpFile(ext)
	local base = os.tmpname()
	if os_name == "win" and not base:match("^[A-Za-z]:") then
		local tempDir = os.getenv("TEMP") or os.getenv("TMP") or "C:\\Temp"
		base = tempDir .. "\\" .. base:match("([^\\/]+)$")
	end
	return base .. "_" .. tostring(math.floor(os.clock() * 10000)) .. ext
end

local function showNote(msg)
	app.openDialog(msg, { "OK" }, "", false)
end

local b64chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local b64dec = {}
for i = 1, 64 do
	b64dec[b64chars:sub(i, i)] = i - 1
end

local function fastB64Encode(data)
	local out = {}
	local len = #data
	for i = 1, len, 3 do
		local a, b, c = string.byte(data, i, i + 2)
		a = a or 0
		b = b or 0
		c = c or 0
		local v = a * 65536 + b * 256 + c
		local d1 = math.floor(v / 262144) % 64
		local d2 = math.floor(v / 4096) % 64
		local d3 = math.floor(v / 64) % 64
		local d4 = v % 64
		table.insert(out, b64chars:sub(d1 + 1, d1 + 1))
		table.insert(out, b64chars:sub(d2 + 1, d2 + 1))
		table.insert(out, i + 1 <= len and b64chars:sub(d3 + 1, d3 + 1) or "=")
		table.insert(out, i + 2 <= len and b64chars:sub(d4 + 1, d4 + 1) or "=")
	end
	return table.concat(out)
end

local function fastB64Decode(data)
	data = string.gsub(data, "[^" .. b64chars .. "=]", "")
	local out = {}
	local len = #data
	for i = 1, len, 4 do
		local chars = { string.sub(data, i, i + 3):byte(1, 4) }
		local a = b64dec[string.char(chars[1] or 0)] or 0
		local b = b64dec[string.char(chars[2] or 0)] or 0
		local c = b64dec[string.char(chars[3] or 0)] or 0
		local d = b64dec[string.char(chars[4] or 0)] or 0
		local v = a * 262144 + b * 4096 + c * 64 + d
		table.insert(out, string.char(math.floor(v / 65536) % 256))
		if chars[3] ~= 61 then
			table.insert(out, string.char(math.floor(v / 256) % 256))
		end
		if chars[4] ~= 61 then
			table.insert(out, string.char(v % 256))
		end
	end
	return table.concat(out)
end

local function extractPngIdat(data)
	if data:sub(1, 8) ~= "\137\080\078\071\013\010\026\010" then
		return data
	end
	local idat, pos, len = {}, 9, #data
	while pos <= len - 8 do
		local l1, l2, l3, l4 = string.byte(data, pos, pos + 3)
		if not l1 then
			break
		end
		local chunkLen = l1 * 16777216 + l2 * 65536 + l3 * 256 + l4
		local chunkType = string.sub(data, pos + 4, pos + 7)
		if chunkType == "IDAT" then
			table.insert(idat, string.sub(data, pos + 8, pos + 7 + chunkLen))
		elseif chunkType == "IEND" then
			break
		end
		pos = pos + 12 + chunkLen
	end
	return table.concat(idat)
end

local function getClipboardText()
	local text = ""
	if os_name == "win" then
		local f = io.popen("powershell -command Get-Clipboard", "r")
		if f then
			text = f:read("*a")
			f:close()
		end
	elseif is_mac then
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
		if not text or text == "" then
			f = io.popen("wl-paste 2>/dev/null", "r")
			if f then
				text = f:read("*a")
				f:close()
			end
		end
	end
	return text and text:match("^%s*(.-)%s*$") or ""
end

local function getSmartClipboardData()
	local imgPath = getUniqueTmpFile(".png")
	if os_name == "win" then
		local cmd = "powershell -command \"Add-Type -AssemblyName System.Windows.Forms; if ([Windows.Forms.Clipboard]::ContainsImage()) { $img = [Windows.Forms.Clipboard]::GetImage(); $img.Save('"
			.. imgPath
			.. "', [System.Drawing.Imaging.ImageFormat]::Png); $img.Dispose() }\""
		os.execute(cmd)
	elseif is_mac then
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
		os.execute(
			'xclip -selection clipboard -t image/png -o > "'
				.. imgPath
				.. '" 2>/dev/null || wl-paste -t image/png > "'
				.. imgPath
				.. '" 2>/dev/null'
		)
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
		if os_name == "win" then
			os.execute("powershell -command \"Get-Content -Raw '" .. tmpFile .. "' | Set-Clipboard\"")
		elseif is_mac then
			os.execute("cat '" .. tmpFile .. "' | pbcopy")
		else
			os.execute("cat '" .. tmpFile .. "' | xclip -selection clipboard -i 2>/dev/null")
			os.execute("cat '" .. tmpFile .. "' | wl-copy 2>/dev/null")
		end
		os.remove(tmpFile)
	elseif parsedObj.type == "image" then
		local imgPath = getUniqueTmpFile(".png")
		local f = io.open(imgPath, "wb")
		if f then
			f:write(parsedObj.data)
			f:close()
		end
		if os_name == "win" then
			local cmd = "powershell -command \"Add-Type -AssemblyName System.Windows.Forms; $img = [System.Drawing.Image]::FromFile('"
				.. imgPath
				.. "'); [Windows.Forms.Clipboard]::SetImage($img); $img.Dispose()\""
			os.execute(cmd)
		elseif is_mac then
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
			os.execute(
				'xclip -selection clipboard -t image/png -i "'
					.. imgPath
					.. '" 2>/dev/null || wl-copy -t image/png < "'
					.. imgPath
					.. '" 2>/dev/null'
			)
		end
		os.remove(imgPath)
	end

	if incrementBadgeCount then
		incrementBadgeCount()
	end

	if is_mac then
		os.execute("open 'raycast://extensions/codiy/clipboard-preview/clipboard-preview'")
	else
		local note = parsedObj.type == "image" and "✅ Image decrypted and copied to clipboard!"
			or "✅ Text decrypted and copied to clipboard!"
		showNote(note)
	end
end

local function compressTextToZ64(text)
	if os_name == "win" then
		return "B64:" .. fastB64Encode(text)
	end
	local tmpIn = getUniqueTmpFile(".txt")
	local f = io.open(tmpIn, "w")
	if not f then
		return "B64:" .. fastB64Encode(text)
	end
	f:write(text)
	f:close()
	local tmpGz = tmpIn .. ".gz"
	os.execute(string.format("gzip -c '%s' > '%s'", tmpIn, tmpGz))
	local fGz = io.open(tmpGz, "rb")
	local gzData = ""
	if fGz then
		gzData = fGz:read("*a")
		fGz:close()
	end
	os.remove(tmpIn)
	os.remove(tmpGz)
	if gzData == "" then
		return "B64:" .. fastB64Encode(text)
	end
	return "Z64:" .. fastB64Encode(gzData)
end

local function decodeZ64ToText(z64text)
	if os_name == "win" then
		return "[System Info: This record is in Z64 compressed format and requires macOS to decompress]"
	end
	local gzData = fastB64Decode(z64text)
	local tmpGz = getUniqueTmpFile(".gz")
	local f = io.open(tmpGz, "wb")
	if not f then
		return ""
	end
	f:write(gzData)
	f:close()
	local handle = io.popen(string.format("gzip -dc '%s'", tmpGz), "r")
	local result = ""
	if handle then
		result = handle:read("*a")
		handle:close()
	end
	os.remove(tmpGz)
	return result
end

local function parseChunk(chunkText)
	if chunkText:sub(1, 8) == "IMG:B64:" then
		return { type = "image", data = fastB64Decode(chunkText:sub(9)) }
	elseif chunkText:sub(1, 4) == "Z64:" then
		return { type = "text", data = decodeZ64ToText(chunkText:sub(5)) }
	elseif chunkText:sub(1, 4) == "B64:" then
		return { type = "text", data = fastB64Decode(chunkText:sub(5)) }
	end
	return { type = "text", data = chunkText }
end

incrementBadgeCount = function()
	local targetImgRef, targetImgX, targetImgY, rawText, currentCount = findSidebarSVG()

	if not targetImgRef then
		return
	end

	app.clearSelection()
	app.addToSelection({ targetImgRef })
	app.activateAction("delete")

	app.addImages({
		images = {
			{
				data = generateSidebarSvg(currentCount + 1, rawText),
				x = targetImgX,
				y = targetImgY,
				maxWidth = ICON_SIZE,
				maxHeight = ICON_SIZE,
				aspectRatio = true,
			},
		},
		allowUndoRedoAction = "none",
	})

	app.clearSelection()
	app.refreshPage()
end

function stashSidebar()
	local clipObj = getSmartClipboardData()
	if not clipObj then
		return showNote("❌ Clipboard is empty. Please copy some text or image first.")
	end

	local targetImgRef, targetImgX, targetImgY, rawText, currentCount = findSidebarSVG()

	local chunkCount = 0
	if rawText ~= "" then
		local escapedDelimiter = string.gsub(DELIMITER, "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
		for chunk in string.gmatch(rawText, "(.-)" .. escapedDelimiter) do
			local clean = chunk:match("^%s*(.-)%s*$")
			if clean and clean ~= "" then
				chunkCount = chunkCount + 1
				local parsed = parseChunk(clean)
				if parsed.type == clipObj.type then
					if parsed.type == "image" then
						if extractPngIdat(parsed.data) == extractPngIdat(clipObj.data) then
							return showNote("⚠️ This image is already stored. Duplicate rejected.")
						end
					else
						if parsed.data == clipObj.data then
							return showNote("⚠️ This text is already stored. Duplicate rejected.")
						end
					end
				end
			end
		end
	end

	if chunkCount >= 8 then
		return showNote("⚠️ Sidebar is full (maximum 8 items). Please delete some items first.")
	end

	local textToStash = ""
	if clipObj.type == "image" then
		textToStash = "IMG:B64:" .. fastB64Encode(clipObj.data)
	else
		textToStash = compressTextToZ64(clipObj.data)
	end

	if targetImgRef then
		app.clearSelection()
		app.addToSelection({ targetImgRef })
		app.activateAction("delete")
	end

	local finalX = targetImgX
	local finalY = targetImgY

	if not finalX or not finalY then
		local cx, cy = getCenter()
		finalX = cx - (ICON_SIZE / 2)
		finalY = cy - (ICON_SIZE / 2)
	end

	app.addImages({
		images = {
			{
				data = generateSidebarSvg(currentCount, rawText .. textToStash .. DELIMITER),
				x = finalX,
				y = finalY,
				maxWidth = ICON_SIZE,
				maxHeight = ICON_SIZE,
				aspectRatio = true,
			},
		},
		allowUndoRedoAction = "none",
	})

	if chunkCount > 0 then
		app.clearSelection()
	end

	app.refreshPage()
	showNote(clipObj.type == "image" and "✅ Image stored in Sidebar!" or "✅ Text stored in Sidebar!")
end

function recallSidebar()
	local _, _, _, rawText, _ = findSidebarSVG()
	if rawText == "" then
		return showNote("📭 Sidebar is empty.")
	end

	local chunks = {}
	local escapedDelimiter = string.gsub(DELIMITER, "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
	for chunk in string.gmatch(rawText, "(.-)" .. escapedDelimiter) do
		local clean = chunk:match("^%s*(.-)%s*$")
		if clean and clean ~= "" then
			table.insert(chunks, clean)
		end
	end
	if #chunks == 0 then
		local clean = rawText:match("^%s*(.-)%s*$")
		if clean ~= "" then
			table.insert(chunks, clean)
		end
	end

	if #chunks == 0 then
		return
	end
	if #chunks == 1 then
		return triggerRecallAction(parseChunk(chunks[1]))
	end

	local dialogOptions, msg = {}, "📚 Sidebar contains the following items:\n\n"
	sidebarContext = {}
	for i, chunk in ipairs(chunks) do
		local parsed = parseChunk(chunk)
		local preview = parsed.type == "image"
				and string.format("🖼️ [Image] - %d KB", math.floor(#parsed.data / 1024))
			or (utf8sub(parsed.data:gsub("[\r\n\t]+", " "), 1, 25) .. "...")
		table.insert(dialogOptions, "📋 Item " .. i)
		table.insert(sidebarContext, parsed)
		msg = msg .. string.format("[%d] %s\n", i, preview)
	end
	table.insert(dialogOptions, "🚫 Cancel")
	table.insert(sidebarContext, "cancel")
	app.openDialog(msg, dialogOptions, "handleSidebarCallback", false)
end

function handleSidebarCallback(selectedIndex)
	if not sidebarContext or not selectedIndex then
		return
	end
	local idx = tonumber(selectedIndex)
	if not idx then
		return
	end
	local parsedObj = sidebarContext[idx] or sidebarContext[idx + 1]
	if parsedObj and parsedObj ~= "cancel" then
		triggerRecallAction(parsedObj)
	end
	sidebarContext = nil
end

function purgeSidebar()
	local targetImgRef, targetImgX, targetImgY, rawText, currentCount = findSidebarSVG()
	if not targetImgRef then
		return showNote("📭 No Sidebar found on this layer.")
	end

	local chunks = {}
	local escapedDelimiter = string.gsub(DELIMITER, "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
	for chunk in string.gmatch(rawText, "(.-)" .. escapedDelimiter) do
		local clean = chunk:match("^%s*(.-)%s*$")
		if clean and clean ~= "" then
			table.insert(chunks, clean)
		end
	end
	if #chunks == 0 then
		local clean = rawText:match("^%s*(.-)%s*$")
		if clean ~= "" then
			table.insert(chunks, clean)
		end
	end

	if #chunks <= 1 then
		app.clearSelection()
		app.addToSelection({ targetImgRef })
		app.activateAction("delete")
		app.refreshPage()
		showNote("🗑️ Sidebar has been deleted.")
		return
	end

	local dialogOptions, msg = {}, "🗑️ Select an item to delete:\n\n"
	sidebarDeleteContext = {
		chunks = chunks,
		imgRef = targetImgRef,
		imgX = targetImgX,
		imgY = targetImgY,
		currentCount = currentCount,
	}

	for i, chunk in ipairs(chunks) do
		local parsed = parseChunk(chunk)
		local preview = parsed.type == "image"
				and string.format("🖼️ [Image] - %d KB", math.floor(#parsed.data / 1024))
			or (utf8sub(parsed.data:gsub("[\r\n\t]+", " "), 1, 25) .. "...")
		table.insert(dialogOptions, "🗑️ Delete " .. i)
		msg = msg .. string.format("[%d] %s\n", i, preview)
	end
	table.insert(dialogOptions, "🚫 Cancel")
	app.openDialog(msg, dialogOptions, "handleDeleteSidebarCallback", false)
end

function handleDeleteSidebarCallback(selectedIndex)
	if not sidebarDeleteContext or not selectedIndex then
		return
	end
	local idx = tonumber(selectedIndex)
	if not idx then
		return
	end
	if idx > #sidebarDeleteContext.chunks then
		sidebarDeleteContext = nil
		return
	end

	local chunks = sidebarDeleteContext.chunks
	table.remove(chunks, idx)

	app.clearSelection()
	app.addToSelection({ sidebarDeleteContext.imgRef })
	app.activateAction("delete")

	local combinedText = ""
	for _, chunk in ipairs(chunks) do
		combinedText = combinedText .. chunk .. DELIMITER
	end
	if combinedText ~= "" then
		app.addImages({
			images = {
				{
					data = generateSidebarSvg(sidebarDeleteContext.currentCount, combinedText),
					x = sidebarDeleteContext.imgX,
					y = sidebarDeleteContext.imgY,
					maxWidth = ICON_SIZE,
					maxHeight = ICON_SIZE,
					aspectRatio = true,
				},
			},
			allowUndoRedoAction = "none",
		})
		app.clearSelection()
	end

	app.refreshPage()
	showNote("✂️ Item deleted.")
	sidebarDeleteContext = nil
end

function initUi()
	app.registerUi({ ["menu"] = "Sidebar: Stash Clipboard", ["callback"] = "stashSidebar", ["accelerator"] = "<Alt>1" })
	app.registerUi({ ["menu"] = "Sidebar: Recall & Read", ["callback"] = "recallSidebar", ["accelerator"] = "<Alt>2" })
	app.registerUi({ ["menu"] = "Sidebar: Purge Assets", ["callback"] = "purgeSidebar", ["accelerator"] = "<Alt>3" })
end
