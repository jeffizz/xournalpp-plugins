local metadata = require("metadata")

local savedPages = {}
local teleportStations = {}
local lastClickTime = 0

local slotStates = {
	[1] = { lastTime = 0, originPage = 0 },
	[2] = { lastTime = 0, originPage = 0 },
	[3] = { lastTime = 0, originPage = 0 },
}

local metadataCache = {
	fileKey = nil,
	db = nil,
}

pendingJumpContext = nil
pendingJumpTargets = nil

local ITEMS_PER_PAGE = 6

local function getTmpDir()
	local dir = os.getenv("TMPDIR") or os.getenv("TEMP") or os.getenv("TMP") or "/tmp"
	if dir:sub(-1) == "/" or dir:sub(-1) == "\\" then
		return dir:sub(1, -2)
	end
	return dir
end

local dataFile = getTmpDir() .. "/xournalpp_saved_pages.lua"

local function showNote(msg)
	if app.openDialog then
		app.openDialog(msg, { ["OK"] = "ok" })
	end
end

local function getFileKey()
	local doc = app.getDocumentStructure()
	local path = (doc.pdfBackgroundFilename and doc.pdfBackgroundFilename ~= "") and doc.pdfBackgroundFilename
		or "default"
	local hash = 0
	for i = 1, #path do
		hash = (hash * 31 + string.byte(path, i)) % 2147483647
	end
	return tostring(hash)
end

local function fetchMetadata()
	local currentKey = getFileKey()
	if metadataCache.fileKey == currentKey and metadataCache.db then
		return metadataCache.db
	end
	local text = metadata.getMetadataText()
	local db = metadata.parseINI(text)
	metadataCache.fileKey = currentKey
	metadataCache.db = db
	return db
end

local function updateMetadata(db)
	if metadata.writeMetadata(db) then
		metadataCache.db = db
		return true
	end
	return false
end

local function getClipboardText()
	local os_name = package.config:sub(1, 1) == "\\" and "win" or "unix"
	local text = ""
	if os_name == "win" then
		local f = io.popen("powershell -command Get-Clipboard", "r")
		if f then
			text = f:read("*a")
			f:close()
		end
	else
		local f = io.popen("uname -s", "r")
		local uname = f and f:read("*a") or ""
		if f then
			f:close()
		end
		if uname:match("Darwin") then
			f = io.popen("pbpaste 2>/dev/null", "r")
			if f then
				text = f:read("*a")
				f:close()
			end
		else
			f = io.popen("xclip -selection clipboard -o 2>/dev/null", "r")
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
	end
	return text and text:match("^%s*(.-)%s*$") or ""
end

function processClipboardConfig()
	local txt = getClipboardText()
	local db = fetchMetadata()
	db["Common"] = db["Common"] or {}
	db["PageJumpper"] = db["PageJumpper"] or {}

	if txt:match("[/\\]mutool%.?e?x?e?$") or txt:match("^mutool$") then
		db["Common"]["MutoolPath"] = txt
		if updateMetadata(db) then
			showNote("✅ Mutool path configured:\n" .. txt)
		end
	elseif tonumber(txt) then
		db["PageJumpper"]["PrintedOffset"] = txt
		if updateMetadata(db) then
			showNote("✅ Printed offset set to: " .. txt)
		end
	else
		showNote("❓ Unrecognized clipboard content.\nProvide a mutool path or a numeric offset.")
	end
end

local function extractNumbersFromPage(doc, current)
	local uniqueNums = {}
	local db = fetchMetadata()
	local mutoolExec = (db["Common"] and db["Common"]["MutoolPath"]) or "mutool"

	local allTexts = app.getTexts("page") or {}
	for _, txt in pairs(allTexts) do
		if type(txt) == "table" and txt.text then
			for numStr in txt.text:gmatch("%f[%w][Pp]age%s*(%d+)") do
				uniqueNums[tonumber(numStr)] = true
			end
			for numStr in txt.text:gmatch("%f[%w][Pp]%s*(%d+)") do
				uniqueNums[tonumber(numStr)] = true
			end
		end
	end

	local pageInfo = doc.pages[current]
	local pdfBgNo = pageInfo and pageInfo.pdfBackgroundPageNo or 0
	local pdfPath = doc.pdfBackgroundFilename

	if pdfPath and pdfPath ~= "" and pdfBgNo > 0 then
		local os_name = package.config:sub(1, 1) == "\\" and "win" or "unix"
		local safePath = '"' .. pdfPath:gsub('"', '\\"') .. '"'
		local cmd = string.format(
			'"%s" draw -F txt -o - %s %d 2>%s',
			mutoolExec,
			safePath,
			pdfBgNo,
			os_name == "win" and "nul" or "/dev/null"
		)
		local f = io.popen(cmd, "r")
		if f then
			local pdfText = f:read("*a")
			f:close()
			if pdfText and pdfText ~= "" then
				for numStr in pdfText:gmatch("%f[%w][%w]?[Pp]age%s*(%d+)") do
					uniqueNums[tonumber(numStr)] = true
				end
				for numStr in pdfText:gmatch("%f[%w][Pp]%s*(%d+)") do
					uniqueNums[tonumber(numStr)] = true
				end
			end
		end
	end

	local nums = {}
	for n, _ in pairs(uniqueNums) do
		table.insert(nums, n)
	end
	table.sort(nums)
	return nums
end

local function scrollToPage(target)
	if target and target > 0 then
		app.scrollToPage(target, false)
	end
end

function utf8sub(str, startChar, numChars)
	local startIndex = 1
	while startChar > 1 do
		local byte = string.byte(str, startIndex)
		startIndex = startIndex + getByteCount(byte)
		startChar = startChar - 1
	end

	local currentIndex = startIndex
	while numChars > 0 and currentIndex <= #str do
		local byte = string.byte(str, currentIndex)
		currentIndex = currentIndex + getByteCount(byte)
		numChars = numChars - 1
	end

	return str:sub(startIndex, currentIndex - 1)
end

function getByteCount(byte)
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

function previewPdfPage(targetInternal)
	local doc = app.getDocumentStructure()
	if not doc or not doc.pages or not doc.pages[targetInternal] then
		return
	end

	local pdfBgNo = doc.pages[targetInternal].pdfBackgroundPageNo
	local pdfPath = doc.pdfBackgroundFilename

	if not pdfPath or pdfPath == "" or not pdfBgNo or pdfBgNo <= 0 then
		showNote("❌ Invalid PDF background or page for preview.")
		return
	end

	local db = fetchMetadata()
	local mutoolExec = (db["Common"] and db["Common"]["MutoolPath"]) or "mutool"
	local os_name = package.config:sub(1, 1) == "\\" and "win" or "unix"

	local tmpImg = getTmpDir() .. "/xo_preview.png"
	local safePath = '"' .. pdfPath:gsub('"', '\\"') .. '"'
	local nullDev = os_name == "win" and "nul" or "/dev/null"

	-- 150 dpi
	local cmdDraw = string.format('"%s" draw -r 150 -o "%s" %s %d 2>%s', mutoolExec, tmpImg, safePath, pdfBgNo, nullDev)
	os.execute(cmdDraw)

	if os_name == "unix" then
		local f = io.popen("uname -s", "r")
		local uname = f and f:read("*a") or ""
		if f then
			f:close()
		end

		if uname:match("Darwin") then
			local cmdCopy = string.format(
				"osascript -e 'set the clipboard to (read (POSIX file \"%s\") as «class PNGf»)'",
				tmpImg
			)
			os.execute(cmdCopy)
			os.execute('open "raycast://extensions/codiy/clipboard-preview/clipboard-preview"')
		else
			os.execute(
				string.format(
					"xclip -selection clipboard -t image/png -i '%s' 2>/dev/null || wl-copy < '%s'",
					tmpImg,
					tmpImg
				)
			)
			os.execute('xdg-open "raycast://extensions/codiy/clipboard-preview/clipboard-preview" 2>/dev/null')
		end
	else
		os.execute(string.format("powershell -command \"Set-Clipboard -Path '%s'\"", tmpImg))
		os.execute('start "raycast://extensions/codiy/clipboard-preview/clipboard-preview"')
	end
end

function renderJumpDialog()
	if not pendingJumpContext then
		return
	end

	local items = pendingJumpContext.allTargets
	local totalItems = #items
	local totalPages = math.ceil(totalItems / ITEMS_PER_PAGE)
	local p = pendingJumpContext.dialogPage

	local startIdx = (p - 1) * ITEMS_PER_PAGE + 1
	local endIdx = math.min(p * ITEMS_PER_PAGE, totalItems)

	local dialogOptions = {}
	local dialogTargets = {}

	pendingJumpContext.actionMode = pendingJumpContext.actionMode or "jump"
	if pendingJumpContext.actionMode == "jump" then
		table.insert(dialogOptions, "🚀")
	else
		table.insert(dialogOptions, "👁️")
	end
	table.insert(dialogTargets, "toggle_mode")

	local message = ""
	local prefix = (pendingJumpContext.mode == "search") and "🔍 Search Results"
		or string.format("Smart Jump (Mode %d)", pendingJumpContext.mode)

	if totalPages > 1 then
		message = string.format("%s (Page %d/%d):\n\n", prefix, p, totalPages)
	else
		message = string.format("%s:\n\n", prefix)
	end

	if p > 1 then
		table.insert(dialogOptions, "⬅️ Prev")
		table.insert(dialogTargets, "prev")
	end

	local term = pendingJumpContext.searchTerm or ""

	for i = startIdx, endIdx do
		table.insert(dialogOptions, items[i].label)
		table.insert(dialogTargets, items[i].target)
		if items[i].snippet then
			local snippet = utf8sub(items[i].snippet, 1, 100)
			local highlightedSnippet = highlightKeyword(snippet, term)
			message = message .. string.format("[%s%d] %s\n", items[i].prefix, items[i].pageNo, highlightedSnippet)
		end
	end

	if p < totalPages then
		table.insert(dialogOptions, "Next ➡️")
		table.insert(dialogTargets, "next")
	end

	table.insert(dialogOptions, "🚫 Cancel")
	table.insert(dialogTargets, "cancel")

	pendingJumpTargets = dialogTargets

	app.openDialog(message, dialogOptions, "handleJumpDialogResult")
end

function handleJumpDialogResult(selectedIndex)
	if not pendingJumpContext or not pendingJumpTargets or not selectedIndex then
		return
	end
	local idx = tonumber(selectedIndex)
	if not idx then
		return
	end

	local target = pendingJumpTargets[idx] or pendingJumpTargets[idx + 1]

	if target == "toggle_mode" then
		pendingJumpContext.actionMode = (pendingJumpContext.actionMode == "jump") and "preview" or "jump"
		renderJumpDialog()
		return
	elseif target == "next" then
		pendingJumpContext.dialogPage = pendingJumpContext.dialogPage + 1
		renderJumpDialog()
		return
	elseif target == "prev" then
		pendingJumpContext.dialogPage = pendingJumpContext.dialogPage - 1
		renderJumpDialog()
		return
	elseif target == "cancel" then
		pendingJumpContext = nil
		pendingJumpTargets = nil
		return
	elseif target then
		if pendingJumpContext.actionMode == "preview" then
			previewPdfPage(target)
		else
			local key = getFileKey()
			if not teleportStations[key] then
				teleportStations[key] = { a = 0, b = 0 }
			end
			teleportStations[key].a = pendingJumpContext.origin
			teleportStations[key].b = target
			scrollToPage(target)
		end
	end

	pendingJumpContext = nil
	pendingJumpTargets = nil
end

function highlightKeyword(text, term)
	if not text or not term or term == "" then
		return text
	end

	local escapedTerm = term:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%1")

	local caseInsensitivePattern = escapedTerm:gsub("%a", function(char)
		return string.format("[%s%s]", string.lower(char), string.upper(char))
	end)

	local pattern = "(" .. caseInsensitivePattern .. ")"
	local highlighted, _ = text:gsub(pattern, "⭐%1", 1)
	return highlighted
end

function searchAndJump()
	local doc = app.getDocumentStructure()
	if not doc or not doc.pages then
		return
	end

	local current = doc.currentPage
	local pdfPath = doc.pdfBackgroundFilename
	local pdfToInternalMap = buildPdfToInternalMap(doc)

	if not pdfPath or pdfPath == "" then
		showNote("❌ No PDF background found for search.")
		return
	end

	local txt = getClipboardText()
	if not txt or txt == "" then
		showNote("❌ Clipboard is empty.")
		return
	end

	local db = fetchMetadata()
	local mutoolExec = (db["Common"] and db["Common"]["MutoolPath"]) or "mutool"
	local printedOffset = tonumber(db["PageJumpper"] and db["PageJumpper"]["PrintedOffset"]) or 0

	local os_name = package.config:sub(1, 1) == "\\" and "win" or "unix"
	local nullDev = os_name == "win" and "nul" or "/dev/null"
	local safePath = '"' .. pdfPath:gsub('"', '\\"') .. '"'

	local safeTerm = ""
	if os_name == "win" then
		safeTerm = '"' .. txt:gsub('"', '""') .. '"'
	else
		safeTerm = "'" .. txt:gsub("'", "'\\''") .. "'"
	end

	local searchTerm = txt:lower()
	local allTargets = {}

	-- --- A: mutool PDF search ---
	local seenPages = {}

	local cmd = string.format('"%s" grep -i -n %s %s 2>%s', mutoolExec, safeTerm, safePath, nullDev)
	local f = io.popen(cmd, "r")
	if f then
		local output = f:read("*a")
		f:close()

		for line in output:gmatch("[^\r\n]+") do
			local pageStr, lineTxt = line:match("^(%d+)%s+(.*)$")
			if pageStr then
				local pageNo = tonumber(pageStr)

				if not seenPages[pageNo] then
					local targetInternal = pdfToInternalMap[pageNo]
					if targetInternal then
						seenPages[pageNo] = true
						local displayPageNo = pageNo - printedOffset
						table.insert(allTargets, {
							label = string.format("P%d", displayPageNo),
							target = targetInternal,
							pageNo = displayPageNo,
							prefix = "P",
							snippet = lineTxt,
						})
					end
				end
			end
		end
	end

	-- --- B: Xournal++ Note Search ---
	local seenXoPages = {}
	local allXoppTexts = app.getTexts("all") or {}
	for _, txtObj in pairs(allXoppTexts) do
		if type(txtObj) == "table" and txtObj.text and txtObj.text:lower():find(searchTerm, 1, true) then
			local xoPage = txtObj.page
			if not seenXoPages[xoPage] then
				seenXoPages[xoPage] = true
				table.insert(allTargets, {
					label = string.format("X%d", xoPage),
					target = xoPage,
					pageNo = xoPage,
					prefix = "X",
					snippet = txtObj.text:gsub("[\r\n]+", " "),
				})
			end
		end
	end

	if #allTargets == 0 then
		local displayTxt = #txt > 20 and (txt:sub(1, 20) .. "...") or txt
		showNote("🔍 Text not found in PDF:\n" .. displayTxt)
		return
	end

	table.sort(allTargets, function(a, b)
		return a.target < b.target
	end)

	pendingJumpContext = {
		origin = current,
		mode = "search",
		allTargets = allTargets,
		searchTerm = txt,
		dialogPage = 1,
	}

	renderJumpDialog()
end

function autoParseAndJump()
	local doc = app.getDocumentStructure()
	if not doc or not doc.pages then
		return
	end

	local current = doc.currentPage
	local db = fetchMetadata()
	local pdfPath = doc.pdfBackgroundFilename
	local mode = 1
	local printedOffset = 0
	local mutoolExec = db["Common"] and db["Common"]["MutoolPath"]

	if pdfPath and pdfPath ~= "" then
		if db["PageJumpper"] and db["PageJumpper"]["PrintedOffset"] then
			mode = 3
			printedOffset = tonumber(db["PageJumpper"]["PrintedOffset"]) or 0
		else
			mode = 2
		end
	end

	local nums = extractNumbersFromPage(doc, current)
	if #nums == 0 then
		showNote("🔍 No page markers found on the current page.")
		return
	end

	local outlineMap = {}
	if pdfPath and pdfPath ~= "" and mutoolExec and mutoolExec ~= "" then
		local os_name = package.config:sub(1, 1) == "\\" and "win" or "unix"
		local safePath = '"' .. pdfPath:gsub('"', '\\"') .. '"'
		local cmd =
			string.format('"%s" show %s outline 2>%s', mutoolExec, safePath, os_name == "win" and "nul" or "/dev/null")
		local f = io.popen(cmd, "r")
		if f then
			local output = f:read("*a")
			f:close()
			if output and output ~= "" then
				for line in output:gmatch("[^\r\n]+") do
					local symbol, indent, title, page = line:match('^([%+|%-])(%s*)"(.*)".-#page=(%d+)')
					if symbol and title and page then
						local displayPage = tonumber(page) - printedOffset
						if not outlineMap[displayPage] then
							outlineMap[displayPage] = title
						end
					end
				end
			end
		end
	end

	local allTargets = {}
	local pdfToInternalMap = buildPdfToInternalMap(doc)

	for _, n in ipairs(nums) do
		local targetInternal = nil
		if mode == 1 then
			if n > 0 and n <= #doc.pages then
				targetInternal = n
			end
		else
			local targetPdfNo = (mode == 3) and (n + printedOffset) or n
			targetInternal = pdfToInternalMap[targetPdfNo]
		end

		if targetInternal then
			local item =
				{ label = string.format("P%d", n), target = targetInternal, pageNo = n, prefix = "P", snippet = "" }

			if outlineMap[n] then
				item.snippet = outlineMap[n]
			end

			table.insert(allTargets, item)
		end
	end

	if #allTargets == 0 then
		showNote("❌ Parsed successfully but unable to locate target page.")
		return
	end

	pendingJumpContext = { origin = current, mode = mode, allTargets = allTargets, dialogPage = 1 }
	renderJumpDialog()
end

function toggleTeleport()
	local key = getFileKey()
	local current = app.getDocumentStructure().currentPage
	local now = os.clock()
	if (now - lastClickTime) < 0.1 then
		teleportStations[key] = nil
		showNote("Teleport Points Reset")
		lastClickTime = 0
		return
	end
	lastClickTime = now
	if not teleportStations[key] then
		teleportStations[key] = { a = 0, b = 0 }
	end
	local tp = teleportStations[key]
	if tp.a == 0 then
		tp.a = current
		showNote("Point A set: " .. current)
	elseif tp.b == 0 then
		if current == tp.a then
			showNote("Point B not set.")
		else
			tp.b = current
			scrollToPage(tp.a)
		end
	else
		local distA = math.abs(current - tp.a)
		local distB = math.abs(current - tp.b)
		if distA <= distB then
			tp.a = current
			scrollToPage(tp.b)
		else
			tp.b = current
			scrollToPage(tp.a)
		end
	end
end

function openSlotManager()
	local doc = app.getDocumentStructure()
	if not doc then
		return
	end

	local current = doc.currentPage
	local key = getFileKey()
	local slots = savedPages[key] or {}

	local db = fetchMetadata()
	local mutoolExec = db["Common"] and db["Common"]["MutoolPath"]
	local printedOffset = tonumber(db["PageJumpper"] and db["PageJumpper"]["PrintedOffset"]) or 0

	local outlineMap = {}
	local pdfPath = doc.pdfBackgroundFilename
	if pdfPath and pdfPath ~= "" and mutoolExec and mutoolExec ~= "" then
		local os_name = package.config:sub(1, 1) == "\\" and "win" or "unix"
		local safePath = '"' .. pdfPath:gsub('"', '\\"') .. '"'
		local cmd =
			string.format('"%s" show %s outline 2>%s', mutoolExec, safePath, os_name == "win" and "nul" or "/dev/null")
		local f = io.popen(cmd, "r")
		if f then
			local output = f:read("*a")
			f:close()
			if output and output ~= "" then
				for line in output:gmatch("[^\r\n]+") do
					local symbol, indent, title, page = line:match('^([%+|%-])(%s*)"(.*)".-#page=(%d+)')
					if symbol and title and page then
						local displayPage = tonumber(page) - printedOffset
						if not outlineMap[displayPage] then
							outlineMap[displayPage] = title
						end
					end
				end
			end
		end
	end

	local function getDisplayPage(internalPage)
		if not internalPage or internalPage == 0 then
			return nil
		end
		local pdfBgNo = doc.pages[internalPage] and doc.pages[internalPage].pdfBackgroundPageNo or 0
		if pdfBgNo > 0 then
			return pdfBgNo - printedOffset
		end
		return internalPage
	end

	local currentDisplayPage = getDisplayPage(current)

	local msg = "📍 Teleport Slot Manager\n\n"
	msg = msg
		.. string.format(
			"▶ Current Page: [P%s] %s\n\n",
			tostring(currentDisplayPage),
			outlineMap[currentDisplayPage] or "Unknown Chapter"
		)

	local dialogOptions = {}
	local dialogTargets = {}

	for i = 1, 3 do
		local targetInternal = slots[i]

		if targetInternal and targetInternal > 0 then
			local targetDisplay = getDisplayPage(targetInternal)
			table.insert(dialogOptions, string.format("🚀 (P%s)", tostring(targetDisplay)))
			table.insert(dialogTargets, { action = "go", slot = i, target = targetInternal })

			msg = msg
				.. string.format("Slot %d: [P%s] %s\n", i, tostring(targetDisplay), outlineMap[targetDisplay] or "")
		else
			table.insert(dialogOptions, "⭕ (Empty)")
			table.insert(dialogTargets, { action = "go", slot = i, target = 0 })

			msg = msg .. string.format("Slot %d: (Empty)\n", i)
		end

		table.insert(dialogOptions, string.format("💾 Slot%d", i))
		table.insert(dialogTargets, { action = "set", slot = i, target = current, display = currentDisplayPage })
	end

	table.insert(dialogOptions, "🚫 Cancel")
	table.insert(dialogTargets, { action = "cancel" })

	pendingJumpContext = { dialogTargets = dialogTargets, origin = current }
	app.openDialog(msg, dialogOptions, "handleSlotManagerResult")
end

function handleSlotManagerResult(selectedIndex)
	if not pendingJumpContext or not pendingJumpContext.dialogTargets or not selectedIndex then
		return
	end
	local idx = tonumber(selectedIndex)
	if not idx then
		return
	end

	local targetInfo = pendingJumpContext.dialogTargets[idx] or pendingJumpContext.dialogTargets[idx + 1]

	if not targetInfo or targetInfo.action == "cancel" then
		pendingJumpContext = nil
		return
	end

	if targetInfo.action == "go" and (not targetInfo.target or targetInfo.target == 0) then
		pendingJumpContext = nil
		return
	end

	local key = getFileKey()
	if not savedPages[key] then
		savedPages[key] = {}
	end

	if targetInfo.action == "go" then
		if not teleportStations[key] then
			teleportStations[key] = { a = 0, b = 0 }
		end
		teleportStations[key].a = pendingJumpContext.origin
		teleportStations[key].b = targetInfo.target
		scrollToPage(targetInfo.target)
	elseif targetInfo.action == "set" then
		savedPages[key][targetInfo.slot] = targetInfo.target
		saveSavedPages()
		showNote("✅ Slot " .. targetInfo.slot .. " has been set to [P" .. tostring(targetInfo.display) .. "]")
	end

	pendingJumpContext = nil
end

function gotoPage()
	local key = getFileKey()
	teleportStations[key] = { a = 0, b = 0 }
	teleportStations[key].a = app.getDocumentStructure().currentPage
	app.activateAction("goto-page")
end

function showPageInfo()
	local doc = app.getDocumentStructure()
	if not doc then
		return
	end
	local pageNo = doc.currentPage or 0
	local page = doc.pages[pageNo] or {}
	local db = fetchMetadata()
	local mutoolPath = (db["Common"] and db["Common"]["MutoolPath"]) or "mutool"

	local width = page.pageWidth or "Unknown"
	local height = page.pageHeight or "Unknown"
	local format = page.pageTypeFormat or "Unknown"
	local config = page.pageTypeConfig or "Unknown"
	local bgColor = page.backgroundColor or "Unknown"
	local pdfBgPage = page.pdfBackgroundPageNo or 0
	local pdfPath = doc.pdfBackgroundFilename or "Unknown"

	showNote(
		string.format(
			"📄 Page: %d / %d\n🖼️ pdfPageNo: %s\n🛠️ Mutool: %s\n📏 Size: %s x %s\n📝 Format: %s\n🎨 BgColor: %s\n📁Path:%s",
			pageNo,
			#doc.pages,
			tostring(pdfBgPage),
			mutoolPath,
			tostring(width),
			tostring(height),
			tostring(format),
			tostring(bgColor),
			tostring(pdfPath)
		)
	)
end

function buildPdfToInternalMap(doc)
	local map = {}
	if not doc or not doc.pages then
		return map
	end
	for i = 1, #doc.pages do
		local bgNo = doc.pages[i].pdfBackgroundPageNo
		if bgNo and bgNo > 0 and not map[bgNo] then
			map[bgNo] = i
		end
	end
	return map
end

local function parseOutlineTree(text, printedOffset, pdfToInternalMap)
	local lines = {}
	for line in text:gmatch("[^\r\n]+") do
		if not line:match("^warning:") then
			table.insert(lines, line)
		end
	end

	local root = { children = {}, title = "ROOT", level = -1 }
	local stack = { [-1] = root }

	local isFlat = not text:match("[%+%-]")
	local startRecording = isFlat

	for _, line in ipairs(lines) do
		local symbol, indent, title, page = line:match('^([%+|%-])(%s*)"(.*)".-#page=(%d+)')
		if symbol then
			local level = #indent
			local isLeaf = (symbol == "|")
			local targetPage = tonumber(page)
			local displayPage = targetPage - (printedOffset or 0)
			local targetInternal = pdfToInternalMap[targetPage]
			local node = {
				title = title,
				targetPage = targetInternal,
				displayPage = displayPage,
				isLeaf = isLeaf,
				level = level,
				children = {},
			}

			if not startRecording and not isLeaf then
				startRecording = true
			end

			if startRecording then
				local parentLevel = level - 1
				while parentLevel >= -1 and not stack[parentLevel] do
					parentLevel = parentLevel - 1
				end
				local parent = stack[parentLevel] or root

				table.insert(parent.children, node)
				stack[level] = node

				for i = level + 1, 20 do
					stack[i] = nil
				end
			end
		end
	end
	return root
end

local function getChapterPrefix(title)
	-- 1. trim
	local t = title:match("^[ \t]*(.-)[ \t]*$")
	if not t or t == "" then
		return nil
	end

	-- 2. eg: Chapter 1, Part II, Appendix A
	local p1_num = t:match("^(%a+[ \t]+%d+)[%.%:]?[ \t\194\227]")
	if p1_num then
		return p1_num
	end

	local p1_rom = t:match("^(%a+[ \t]+[IVX]+)[%.%:]?[ \t\194\227]")
	if p1_rom then
		return p1_rom
	end

	local p1_let = t:match("^(%a+[ \t]+%u)[%.%:]?[ \t\194\227]")
	if p1_let then
		return p1_let
	end

	-- eg: Volume 1
	local e1_num = t:match("^(%a+[ \t]+%d+)$")
	if e1_num then
		return e1_num
	end

	local e1_rom = t:match("^(%a+[ \t]+[IVX]+)$")
	if e1_rom then
		return e1_rom
	end

	local e1_let = t:match("^(%a+[ \t]+%u)$")
	if e1_let then
		return e1_let
	end

	-- 3. Digits, eg:10.2, 1.1.3, 3
	local num_prefix = t:match("^([%d%.]+)[ \t\194\227]")
	if num_prefix and num_prefix:match("%d") then
		return num_prefix
	end

	local num_exact = t:match("^([%d%.]+)$")
	if num_exact and num_exact:match("%d") then
		return num_exact
	end

	-- 4. Chinese "第x章", "第x部分"
	local zh_chapter = t:match("^(第.-章)")
	if zh_chapter and #zh_chapter <= 30 then
		return zh_chapter
	end

	local zh_part = t:match("^(第.-部分)")
	if zh_part and #zh_part <= 30 then
		return zh_part
	end

	local zh_section = t:match("^(第.-节)")
	if zh_section and #zh_section <= 30 then
		return zh_section
	end

	-- 5. colons
	local colon_pos = t:find("[:：]")
	if colon_pos and colon_pos <= 30 then
		local prefix = t:sub(1, colon_pos - 1)
		return prefix:match("^[ \t]*(.-)[ \t]*$")
	end

	return nil
end

function renderOutlineDialog()
	if not pendingJumpContext or not pendingJumpContext.allNodes then
		return
	end

	local nodes = pendingJumpContext.allNodes
	local totalItems = #nodes
	local totalPages = math.ceil(totalItems / ITEMS_PER_PAGE)
	local p = pendingJumpContext.dialogPage

	local startIdx = (p - 1) * ITEMS_PER_PAGE + 1
	local endIdx = math.min(p * ITEMS_PER_PAGE, totalItems)

	local dialogOptions = {}
	local dialogTargets = {}

	local message = "📖 Outline: " .. pendingJumpContext.parentTitle .. "\n"
	if totalPages > 1 then
		message = message .. "(Page " .. p .. "/" .. totalPages .. ")\n"
	end
	message = message .. "\n"

	if pendingJumpContext.history and #pendingJumpContext.history > 0 then
		table.insert(dialogOptions, "⬆️ Back")
		table.insert(dialogTargets, "back")
	end
	if p > 1 then
		table.insert(dialogOptions, "⬅️ Prev")
		table.insert(dialogTargets, "prev")
	end

	for i = startIdx, endIdx do
		local node = nodes[i]
		local marker = (node.isLeaf or #node.children == 0) and "" or "📂"
		local prefix = getChapterPrefix(node.title)
		local btnLabel = ""
		if prefix then
			btnLabel = string.format("%s%s", prefix, marker)
		else
			btnLabel = string.format("P%d%s", node.displayPage, marker)
		end
		table.insert(dialogOptions, btnLabel)
		table.insert(dialogTargets, i)
		message = message .. string.format("[P%d]\t %s%s\n", node.displayPage, node.title, marker)
	end

	if p < totalPages then
		table.insert(dialogOptions, "Next ➡️")
		table.insert(dialogTargets, "next")
	end

	table.insert(dialogOptions, "🚫 Close")
	table.insert(dialogTargets, "cancel")

	pendingJumpTargets = dialogTargets
	app.openDialog(message, dialogOptions, "handleOutlineDialogResult")
end

function handleOutlineDialogResult(selectedIndex)
	if not pendingJumpContext or not pendingJumpTargets or not selectedIndex then
		return
	end
	local idx = tonumber(selectedIndex)
	if not idx then
		return
	end

	local cmd = pendingJumpTargets[idx] or pendingJumpTargets[idx + 1]

	if cmd == "next" then
		pendingJumpContext.dialogPage = pendingJumpContext.dialogPage + 1
		renderOutlineDialog()
	elseif cmd == "prev" then
		pendingJumpContext.dialogPage = pendingJumpContext.dialogPage - 1
		renderOutlineDialog()
	elseif cmd == "cancel" then
		pendingJumpContext = nil
	elseif cmd == "back" then
		local lastContext = table.remove(pendingJumpContext.history)
		pendingJumpContext.allNodes = lastContext.nodes
		pendingJumpContext.parentTitle = lastContext.title
		pendingJumpContext.dialogPage = lastContext.page or 1
		renderOutlineDialog()
	elseif type(cmd) == "number" then
		local selectedNode = pendingJumpContext.allNodes[cmd]

		if selectedNode.isLeaf or #selectedNode.children == 0 then
			local key = getFileKey()
			if not teleportStations[key] then
				teleportStations[key] = { a = 0, b = 0 }
			end
			teleportStations[key].a = app.getDocumentStructure().currentPage
			teleportStations[key].b = selectedNode.targetPage
			scrollToPage(selectedNode.targetPage)
			pendingJumpContext = nil
		else
			table.insert(pendingJumpContext.history, {
				nodes = pendingJumpContext.allNodes,
				title = pendingJumpContext.parentTitle,
				page = pendingJumpContext.dialogPage,
			})
			pendingJumpContext.allNodes = selectedNode.children
			pendingJumpContext.parentTitle = selectedNode.title
			pendingJumpContext.dialogPage = 1
			renderOutlineDialog()
		end
	end
end

function showPdfOutline()
	local doc = app.getDocumentStructure()
	if not doc or not doc.pdfBackgroundFilename or doc.pdfBackgroundFilename == "" then
		showNote("❌ No PDF background found.")
		return
	end

	local db = fetchMetadata()
	local mutoolExec = db["Common"] and db["Common"]["MutoolPath"]

	if not mutoolExec or mutoolExec == "" then
		showNote(
			"⚠️ Mutool is not configured!\n\nPlease copy the mutool executable path to your clipboard, then use the menu:\n[Config from Clipboard (Path/Offset)]"
		)
		return
	end
	local printedOffset = tonumber(db["PageJumpper"] and db["PageJumpper"]["PrintedOffset"]) or 0

	local os_name = package.config:sub(1, 1) == "\\" and "win" or "unix"
	local safePath = '"' .. doc.pdfBackgroundFilename:gsub('"', '\\"') .. '"'

	local cmd =
		string.format('"%s" show %s outline 2>%s', mutoolExec, safePath, os_name == "win" and "nul" or "/dev/null")

	local f = io.popen(cmd, "r")
	if not f then
		showNote("❌ Failed to run mutool.")
		return
	end
	local output = f:read("*a")
	f:close()

	if not output or output == "" then
		showNote("🔍 No outline found in this PDF.")
		return
	end

	local pdfToInternalMap = buildPdfToInternalMap(doc)
	local tree = parseOutlineTree(output, printedOffset, pdfToInternalMap)
	if #tree.children == 0 then
		showNote("🔍 Outline is empty after filtering.")
		return
	end

	pendingJumpContext = {
		origin = doc.currentPage,
		mode = "outline",
		parentTitle = "Table of Contents",
		allNodes = tree.children,
		dialogPage = 1,
		history = {},
	}

	renderOutlineDialog()
end

function insertChapterToc()
	local doc = app.getDocumentStructure()
	if not doc or not doc.pdfBackgroundFilename or doc.pdfBackgroundFilename == "" then
		showNote("❌ No PDF background found.")
		return
	end

	local db = fetchMetadata()
	local mutoolExec = db["Common"] and db["Common"]["MutoolPath"]

	if not mutoolExec or mutoolExec == "" then
		showNote(
			"⚠️ Mutool is not configured!\n\nPlease copy the mutool executable path to your clipboard, then use the menu:\n[Config from Clipboard (Path/Offset)]"
		)
		return
	end

	local printedOffset = tonumber(db["PageJumpper"] and db["PageJumpper"]["PrintedOffset"]) or 0
	local os_name = package.config:sub(1, 1) == "\\" and "win" or "unix"
	local safePath = '"' .. doc.pdfBackgroundFilename:gsub('"', '\\"') .. '"'
	local cmd =
		string.format('"%s" show %s outline 2>%s', mutoolExec, safePath, os_name == "win" and "nul" or "/dev/null")

	local f = io.popen(cmd, "r")
	if not f then
		showNote("❌ Failed to run mutool.")
		return
	end
	local output = f:read("*a")
	f:close()

	if not output or output == "" then
		showNote("🔍 No outline found in this PDF.")
		return
	end

	local pdfToInternalMap = buildPdfToInternalMap(doc)
	local tree = parseOutlineTree(output, printedOffset, pdfToInternalMap)
	if #tree.children == 0 then
		showNote("🔍 Outline is empty after parsing.")
		return
	end

	local current = doc.currentPage
	local currentChapter = nil

	for i = #tree.children, 1, -1 do
		local node = tree.children[i]
		local startPg = node.targetPage or 0
		if startPg > 0 and startPg <= current then
			currentChapter = node
			break
		end
	end

	if not currentChapter and #tree.children > 0 then
		currentChapter = tree.children[1]
	end

	if not currentChapter then
		showNote("❌ Could not determine current chapter.")
		return
	end

	local lines = {}
	local function traverse(node, depth)
		if node.title and node.displayPage then
			local indent = string.rep("    ", depth)
			table.insert(lines, string.format("%s[P%d] %s", indent, node.displayPage, node.title))
		end
		if node.children then
			for _, child in ipairs(node.children) do
				traverse(child, depth + 1)
			end
		end
	end

	traverse(currentChapter, 0)
	local resultText = table.concat(lines, "\n")

	local font = app.getFont()
	app.addTexts({
		texts = {
			{
				text = resultText,
				x = 50,
				y = 50,
				color = 0x000000,
				font = font,
			},
		},
	})

	app.refreshPage()
end

function loadSavedPages()
	local file = io.open(dataFile, "r")
	if file then
		local content = file:read("*a")
		file:close()
		local chunk = load(content)
		if chunk then
			savedPages = chunk()
		end
	end
	if not savedPages then
		savedPages = {}
	end
end

function saveSavedPages()
	local file = io.open(dataFile, "w")
	if file then
		file:write("return " .. serializeTable(savedPages))
		file:close()
	end
end

function serializeTable(val)
	if type(val) == "table" then
		local res = "{"
		for k, v in pairs(val) do
			local k_str = (type(k) == "string") and '["' .. k .. '"]' or "[" .. k .. "]"
			res = res .. k_str .. "=" .. serializeTable(v) .. ","
		end
		return res .. "}"
	elseif type(val) == "string" then
		return '"' .. val .. '"'
	else
		return tostring(val)
	end
end

function renderPageMentionsDialog()
	if not pendingJumpContext or not pendingJumpContext.rankedMentions then
		return
	end

	local items = pendingJumpContext.rankedMentions
	local totalItems = #items
	local totalPages = math.ceil(totalItems / ITEMS_PER_PAGE)
	local p = pendingJumpContext.dialogPage

	local startIdx = (p - 1) * ITEMS_PER_PAGE + 1
	local endIdx = math.min(p * ITEMS_PER_PAGE, totalItems)

	local dialogOptions = {}
	local dialogTargets = {}

	local message = "📊 Global Page Mentions:\n\n"
	if totalPages > 1 then
		message = message .. string.format("(Page %d/%d)\n\n", p, totalPages)
	end

	if p > 1 then
		table.insert(dialogOptions, "⬅️ Prev")
		table.insert(dialogTargets, "prev")
	end

	for i = startIdx, endIdx do
		local item = items[i]
		local pre = item.prefix or "P"

		if item.isCurrent then
			if item.count == 0 then
				table.insert(dialogOptions, string.format("📍 %s%d (0)", pre, item.displayPage))
				table.insert(dialogTargets, "cancel")
				message = message .. string.format("[%s%d](0)\t%s📍\n", pre, item.displayPage, item.title)
			else
				table.insert(dialogOptions, string.format("📍 %s%d (%d)", pre, item.displayPage, item.count))
				table.insert(dialogTargets, { action = "show_backlinks", item = item })
				message = message
					.. string.format("[%s%d](%d)\t%s📍\n", pre, item.displayPage, item.count, item.title)
			end
		else
			table.insert(dialogOptions, string.format("%s%d (%d)", pre, item.displayPage, item.count))
			table.insert(dialogTargets, { action = "jump", target = item.target })
			message = message .. string.format("[%s%d](%d)\t%s\n", pre, item.displayPage, item.count, item.title)
		end
	end

	if p < totalPages then
		table.insert(dialogOptions, "Next ➡️")
		table.insert(dialogTargets, "next")
	end

	table.insert(dialogOptions, "🚫 Cancel")
	table.insert(dialogTargets, "cancel")

	pendingJumpTargets = dialogTargets
	app.openDialog(message, dialogOptions, "handlePageMentionsDialogResult")
end

function handlePageMentionsDialogResult(selectedIndex)
	if not pendingJumpContext or not pendingJumpTargets or not selectedIndex then
		return
	end
	local idx = tonumber(selectedIndex)
	if not idx then
		return
	end

	local target = pendingJumpTargets[idx] or pendingJumpTargets[idx + 1]

	if target == "next" then
		pendingJumpContext.dialogPage = pendingJumpContext.dialogPage + 1
		renderPageMentionsDialog()
	elseif target == "prev" then
		pendingJumpContext.dialogPage = pendingJumpContext.dialogPage - 1
		renderPageMentionsDialog()
	elseif target == "cancel" then
		pendingJumpContext = nil
		pendingJumpTargets = nil
	elseif type(target) == "table" then
		if target.action == "jump" then
			local key = getFileKey()
			if not teleportStations[key] then
				teleportStations[key] = { a = 0, b = 0 }
			end
			teleportStations[key].a = pendingJumpContext.origin
			teleportStations[key].b = target.target
			scrollToPage(target.target)
			pendingJumpContext = nil
			pendingJumpTargets = nil
		elseif target.action == "show_backlinks" then
			pendingJumpContext.targetMention = target.item
			pendingJumpContext.backlinksDialogPage = 1
			renderBacklinksDialog()
		end
	end
end

function renderBacklinksDialog()
	if not pendingJumpContext or not pendingJumpContext.targetMention then
		return
	end

	local sources = pendingJumpContext.targetMention.sources
	local targetPageNum = pendingJumpContext.targetMention.displayPage
	local targetPrefix = pendingJumpContext.targetMention.prefix or "P"
	local totalItems = #sources
	local totalPages = math.ceil(totalItems / ITEMS_PER_PAGE)
	local p = pendingJumpContext.backlinksDialogPage

	local startIdx = (p - 1) * ITEMS_PER_PAGE + 1
	local endIdx = math.min(p * ITEMS_PER_PAGE, totalItems)

	local pageTitles = {}
	if totalItems > 0 then
		local sourceSet = {}
		for i = startIdx, endIdx do
			sourceSet[sources[i]] = true
		end

		local allTexts = app.getTexts("all") or {}
		for _, txtObj in pairs(allTexts) do
			if type(txtObj) == "table" and sourceSet[txtObj.page] and txtObj.text then
				if not pageTitles[txtObj.page] then
					local pat1 = "%f[%w][Pp]age[ \t]*" .. targetPageNum .. "%f[%W]"
					local pat2 = "%f[%w][Pp][ \t]*" .. targetPageNum .. "%f[%W]"

					local start_idx, end_idx = txtObj.text:find(pat1)
					if not start_idx then
						start_idx, end_idx = txtObj.text:find(pat2)
					end

					if start_idx then
						local clean = txtObj.text:sub(1, start_idx - 1) .. txtObj.text:sub(end_idx + 1)

						clean = clean:gsub("[ \t\n\r]+", " ")
						clean = clean:match("^[ \t\n\r]*(.-)[ \t\n\r]*$")

						if clean and clean ~= "" then
							pageTitles[txtObj.page] = clean
						end
					end
				end
			end
		end
	end

	local dialogOptions = {}
	local dialogTargets = {}

	local message = string.format(
		"🔗 Backlinks for [%s%d] (%s):\n\n",
		targetPrefix,
		targetPageNum,
		pendingJumpContext.targetMention.title
	)
	if totalPages > 1 then
		message = message .. string.format("(Page %d/%d)\n\n", p, totalPages)
	end

	table.insert(dialogOptions, "⬆️ Back")
	table.insert(dialogTargets, "back")

	if p > 1 then
		table.insert(dialogOptions, "⬅️ Prev")
		table.insert(dialogTargets, "prev")
	end

	for i = startIdx, endIdx do
		local xoPage = sources[i]
		local displayP, pre = pendingJumpContext.getDisplayPage(xoPage)

		local noteTitle = pageTitles[xoPage]
		local title = noteTitle
			or (pendingJumpContext.outlineMap and pendingJumpContext.outlineMap[displayP])
			or "No title"

		local preview = utf8sub(title, 1, 125)
		if #title > 125 then
			preview = preview .. "..."
		end

		table.insert(dialogOptions, string.format("%s%s", pre, tostring(displayP)))
		table.insert(dialogTargets, { action = "jump", target = xoPage })

		local marker = noteTitle and "📝 " or "📖 "
		message = message .. string.format("▪ %s[%s%s] %s\n", marker, pre, tostring(displayP), preview)
	end

	if p < totalPages then
		table.insert(dialogOptions, "Next ➡️")
		table.insert(dialogTargets, "next")
	end

	table.insert(dialogOptions, "🚫 Cancel")
	table.insert(dialogTargets, "cancel")

	pendingJumpTargets = dialogTargets
	app.openDialog(message, dialogOptions, "handleBacklinksDialogResult")
end

function handleBacklinksDialogResult(selectedIndex)
	if not pendingJumpContext or not pendingJumpTargets or not selectedIndex then
		return
	end
	local idx = tonumber(selectedIndex)
	if not idx then
		return
	end

	local target = pendingJumpTargets[idx] or pendingJumpTargets[idx + 1]

	if target == "next" then
		pendingJumpContext.backlinksDialogPage = pendingJumpContext.backlinksDialogPage + 1
		renderBacklinksDialog()
	elseif target == "prev" then
		pendingJumpContext.backlinksDialogPage = pendingJumpContext.backlinksDialogPage - 1
		renderBacklinksDialog()
	elseif target == "back" then
		renderPageMentionsDialog()
	elseif target == "cancel" then
		pendingJumpContext = nil
		pendingJumpTargets = nil
	elseif type(target) == "table" and target.action == "jump" then
		local key = getFileKey()
		if not teleportStations[key] then
			teleportStations[key] = { a = 0, b = 0 }
		end
		teleportStations[key].a = pendingJumpContext.origin
		teleportStations[key].b = target.target
		scrollToPage(target.target)
		pendingJumpContext = nil
		pendingJumpTargets = nil
	end
end

local function prepareMentionsContext()
	local doc = app.getDocumentStructure()
	if not doc or not doc.pages then
		return false
	end

	local db = fetchMetadata()
	local pdfPath = doc.pdfBackgroundFilename
	local mutoolExec = db["Common"] and db["Common"]["MutoolPath"]
	local printedOffset = tonumber(db["PageJumpper"] and db["PageJumpper"]["PrintedOffset"]) or 0

	local mode = 1
	if pdfPath and pdfPath ~= "" then
		if db["PageJumpper"] and db["PageJumpper"]["PrintedOffset"] then
			mode = 3
		else
			mode = 2
		end
	end

	local function getDisplayPage(internalPage)
		if not internalPage or internalPage == 0 then
			return internalPage, "X"
		end
		local bgNo = doc.pages[internalPage] and doc.pages[internalPage].pdfBackgroundPageNo or 0
		if bgNo > 0 then
			return bgNo - printedOffset, "P"
		else
			return internalPage, "X"
		end
	end

	local currentDisplayPage, currentPrefix = getDisplayPage(doc.currentPage)

	local outlineMap = {}
	if pdfPath and pdfPath ~= "" and mutoolExec and mutoolExec ~= "" then
		local os_name = package.config:sub(1, 1) == "\\" and "win" or "unix"
		local safePath = '"' .. pdfPath:gsub('"', '\\"') .. '"'
		local cmd =
			string.format('"%s" show %s outline 2>%s', mutoolExec, safePath, os_name == "win" and "nul" or "/dev/null")
		local f = io.popen(cmd, "r")
		if f then
			local output = f:read("*a")
			f:close()
			if output and output ~= "" then
				for line in output:gmatch("[^\r\n]+") do
					local symbol, indent, title, page = line:match('^([%+|%-])(%s*)"(.*)".-#page=(%d+)')
					if symbol and title and page then
						local displayPage = tonumber(page) - printedOffset
						if not outlineMap[displayPage] then
							outlineMap[displayPage] = title
						end
					end
				end
			end
		end
	end

	local pageAggregator = {}
	local allTexts = app.getTexts("all") or {}

	for _, txtObj in pairs(allTexts) do
		if type(txtObj) == "table" and txtObj.text then
			local sourceXoPage = txtObj.page

			if not pageAggregator[sourceXoPage] then
				pageAggregator[sourceXoPage] = { nums = {}, count = 0 }
			end

			local function collectLocal(n)
				table.insert(pageAggregator[sourceXoPage].nums, n)
				pageAggregator[sourceXoPage].count = pageAggregator[sourceXoPage].count + 1
			end

			for numStr in txtObj.text:gmatch("%f[%w][Pp]age[ \t]*(%d+)") do
				collectLocal(tonumber(numStr))
			end
			for numStr in txtObj.text:gmatch("%f[%w][Pp][ \t]*(%d+)") do
				collectLocal(tonumber(numStr))
			end
		end
	end

	local TOC_THRESHOLD = 15
	local mentions = {}

	for p, data in pairs(pageAggregator) do
		if data.count > 0 and data.count <= TOC_THRESHOLD then
			for _, n in ipairs(data.nums) do
				if not mentions[n] then
					mentions[n] = { count = 0, sources = {}, sourceSet = {} }
				end
				mentions[n].count = mentions[n].count + 1

				if not mentions[n].sourceSet[p] then
					mentions[n].sourceSet[p] = true
					table.insert(mentions[n].sources, p)
				end
			end
		end
	end

	local pdfToInternalMap = buildPdfToInternalMap(doc)
	local rankedMentions = {}

	for n, data in pairs(mentions) do
		if n ~= currentDisplayPage then
			local targetInternal = nil
			if mode == 1 then
				if n > 0 and n <= #doc.pages then
					targetInternal = n
				end
			else
				local targetPdfNo = (mode == 3) and (n + printedOffset) or n
				targetInternal = pdfToInternalMap[targetPdfNo]
			end

			if targetInternal then
				local _, targetPrefix = getDisplayPage(targetInternal)

				table.insert(rankedMentions, {
					displayPage = n,
					prefix = targetPrefix,
					target = targetInternal,
					count = data.count,
					title = outlineMap[n] or "N/A",
					sources = data.sources,
				})
			end
		end
	end

	table.sort(rankedMentions, function(a, b)
		if a.count == b.count then
			return a.displayPage < b.displayPage
		end
		return a.count > b.count
	end)

	table.insert(rankedMentions, 1, {
		isCurrent = true,
		displayPage = currentDisplayPage,
		prefix = currentPrefix,
		count = mentions[currentDisplayPage] and mentions[currentDisplayPage].count or 0,
		title = outlineMap[currentDisplayPage] or "",
		sources = mentions[currentDisplayPage] and mentions[currentDisplayPage].sources or {},
	})

	pendingJumpContext = {
		origin = doc.currentPage,
		rankedMentions = rankedMentions,
		dialogPage = 1,
		getDisplayPage = getDisplayPage,
		outlineMap = outlineMap,
	}

	return true
end

function showPageMentions()
	if prepareMentionsContext() then
		if #pendingJumpContext.rankedMentions == 1 and pendingJumpContext.rankedMentions[1].count == 0 then
			showNote("🔍 No page references found in your notes.")
			pendingJumpContext = nil
			return
		end
		renderPageMentionsDialog()
	end
end

function showCurrentPageBacklinks()
	if prepareMentionsContext() then
		local currentItem = pendingJumpContext.rankedMentions[1]

		if currentItem.count == 0 then
			showNote("🔍 No pages mention the current page.")
			pendingJumpContext = nil
			return
		end

		pendingJumpContext.targetMention = currentItem
		pendingJumpContext.backlinksDialogPage = 1
		renderBacklinksDialog()
	end
end

function initUi()
	app.registerUi({ ["menu"] = "Teleport: Switch A/B", ["callback"] = "toggleTeleport", ["accelerator"] = "<Alt>w" })
	app.registerUi({ ["menu"] = "Slot Manager", ["callback"] = "openSlotManager", ["accelerator"] = "<Alt>d" })
	app.registerUi({ ["menu"] = "Page Mentions", ["callback"] = "showPageMentions", ["accelerator"] = "<Alt>m" })
	app.registerUi({
		["menu"] = "Page Backlinks",
		["callback"] = "showCurrentPageBacklinks",
		["accelerator"] = "<Alt>b",
	})
	app.registerUi({ ["menu"] = "PDF Outline", ["callback"] = "showPdfOutline", ["accelerator"] = "<Alt>a" })
	app.registerUi({ ["menu"] = "Clipboard Search", ["callback"] = "searchAndJump", ["accelerator"] = "<Alt>f" })
	app.registerUi({ ["menu"] = "Smart Jump", ["callback"] = "autoParseAndJump", ["accelerator"] = "<Alt>g" })
	app.registerUi({ ["menu"] = "Go to Page (g)", ["callback"] = "gotoPage", ["accelerator"] = "g" })
	app.registerUi({ ["menu"] = "Config from Clipboard (Path/Offset)", ["callback"] = "processClipboardConfig" })
	app.registerUi({ ["menu"] = "Debug: Page Info", ["callback"] = "showPageInfo" })
	app.registerUi({ ["menu"] = "Insert Chapter TOC", ["callback"] = "insertChapterToc", ["accelerator"] = "<Alt>o" })
	loadSavedPages()
end
