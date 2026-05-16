local GLOBAL_RADIUS = 22

local lastDrawnRefs = {}
local lastDrawnPage = nil
local lastDrawnLayer = nil
local lastDrawTime = 0
local currentShapeIndex = 1

local seqRefs = {}
local seqLastTime = 0
local seqNum = 1
local seqLastShapeType = 0

local braceState = 1
local lastBraceTime = 0

local tblState = {
	lastTime = 0,
	page = nil,
	layer = nil,
	startX = 0,
	startY = 0,
	rows = 0,
	cols = 0,
	cellW = 30,
	cellH = 15,
	refs = {},
}

local function getCenter()
	local doc = app.getDocumentStructure()
	local pageNo = doc.currentPage
	local page = doc.pages[pageNo]
	local w = page.pageWidth or 595
	local h = page.pageHeight or 842
	return w / 2, h / 2
end

local function createStroke(px, py, color, fillValue)
	local pres = {}
	for i = 1, #px do
		table.insert(pres, 1.0)
	end
	return {
		x = px,
		y = py,
		pressure = pres,
		tool = "pen",
		width = 2.0,
		color = color,
		fill = fillValue,
		lineStyle = "solid",
	}
end

local function renderAndSelect(strokesTable, splinesTable)
	if strokesTable and #strokesTable > 0 then
		app.addStrokes({ strokes = strokesTable })
	end
	if splinesTable and #splinesTable > 0 then
		app.addSplines({ splines = splinesTable })
	end
	app.refreshPage()

	local doc = app.getDocumentStructure()
	lastDrawnPage = doc.currentPage
	lastDrawnLayer = doc.pages[lastDrawnPage].currentLayer

	local allStrokes = app.getStrokes("layer")
	lastDrawnRefs = {}

	local countStrokes = strokesTable and #strokesTable or 0
	local countSplines = splinesTable and #splinesTable or 0
	local totalAdded = countStrokes + countSplines

	if allStrokes and totalAdded > 0 then
		for i = #allStrokes, #allStrokes - totalAdded + 1, -1 do
			if allStrokes[i] and allStrokes[i].ref then
				table.insert(lastDrawnRefs, allStrokes[i].ref)
			end
		end
		if #lastDrawnRefs > 0 then
			app.addToSelection(lastDrawnRefs)
		end
	end

	return lastDrawnRefs
end

local function createSplineCircle(cx, cy, r, color, fillValue)
	local k = r * 0.55228475
	return {
		coordinates = {
			cx,
			cy - r,
			cx + k,
			cy - r,
			cx + r,
			cy - k,
			cx + r,
			cy,
			cx + r,
			cy,
			cx + r,
			cy + k,
			cx + k,
			cy + r,
			cx,
			cy + r,
			cx,
			cy + r,
			cx - k,
			cy + r,
			cx - r,
			cy + k,
			cx - r,
			cy,
			cx - r,
			cy,
			cx - r,
			cy - k,
			cx - k,
			cy - r,
			cx,
			cy - r,
		},
		tool = "pen",
		width = 2.0,
		color = color,
		fill = fillValue,
		lineStyle = "solid",
	}
end

local function createSplineHeart(cx, cy, r, color, fillValue)
	return {
		coordinates = {
			cx,
			cy - r * 0.3,
			cx + r * 1.2,
			cy - r * 1.2,
			cx + r * 1.2,
			cy + r * 0.4,
			cx,
			cy + r * 0.9,
			cx,
			cy + r * 0.9,
			cx - r * 1.2,
			cy + r * 0.4,
			cx - r * 1.2,
			cy - r * 1.2,
			cx,
			cy - r * 0.3,
		},
		tool = "pen",
		width = 2.0,
		color = color,
		fill = fillValue,
		lineStyle = "solid",
	}
end

local function insertHollowStar()
	local cx, cy = getCenter()
	local p = {}
	for i = 0, 4 do
		local angle = math.rad(-90 + i * 72)
		table.insert(p, { x = cx + GLOBAL_RADIUS * math.cos(angle), y = cy + GLOBAL_RADIUS * math.sin(angle) })
	end
	local px, py = {}, {}
	local order = { 1, 3, 5, 2, 4, 1 }
	for _, idx in ipairs(order) do
		table.insert(px, p[idx].x)
		table.insert(py, p[idx].y)
	end
	renderAndSelect({ createStroke(px, py, 0xFF0000, 0) })
end

local function insertSolidStar()
	local cx, cy = getCenter()
	local r = GLOBAL_RADIUS * 0.382
	local px, py = {}, {}
	for i = 0, 10 do
		local angle = math.rad(-90 + i * 36)
		local radius = (i % 2 == 0) and GLOBAL_RADIUS or r
		table.insert(px, cx + radius * math.cos(angle))
		table.insert(py, cy + radius * math.sin(angle))
	end
	renderAndSelect({ createStroke(px, py, 0xFF0000, 178) })
end

local function insertHeart()
	local cx, cy = getCenter()
	renderAndSelect(nil, { createSplineHeart(cx, cy, GLOBAL_RADIUS, 0xE74C3C, 178) })
end

local function insertCheckmark()
	local cx, cy = getCenter()
	local greenColor = 0x27AE60
	local s = GLOBAL_RADIUS / 35.0

	local px, py = {}, {}
	local pts = {
		{ -16 * s, 5 * s },
		{ -5 * s, 16 * s },
		{ 22 * s, -16 * s },
		{ 13 * s, -22 * s },
		{ -5 * s, 2 * s },
		{
			-11 * s,
			-3 * s,
		},
	}
	for _, pt in ipairs(pts) do
		table.insert(px, cx + pt[1])
		table.insert(py, cy + pt[2])
	end
	table.insert(px, cx + pts[1][1])
	table.insert(py, cy + pts[1][2])

	renderAndSelect(
		{ createStroke(px, py, greenColor, 255) },
		{ createSplineCircle(cx, cy, GLOBAL_RADIUS, greenColor, 60) }
	)
end

local function insertExclamation()
	local cx, cy = getCenter()
	local orangeColor = 0xF39C12
	local s = GLOBAL_RADIUS / 35.0

	local topX, topY = {}, {}
	local topPts = { { -5 * s, -27 * s }, { 5 * s, -27 * s }, { 3 * s, 10 * s }, { -3 * s, 10 * s } }
	for _, pt in ipairs(topPts) do
		table.insert(topX, cx + pt[1])
		table.insert(topY, cy + pt[2])
	end
	table.insert(topX, topX[1])
	table.insert(topY, topY[1])

	local dotX, dotY = {}, {}
	local r_dot = 5 * s
	for i = 0, 360, 20 do
		table.insert(dotX, cx + r_dot * math.cos(math.rad(i)))
		table.insert(dotY, cy + 22 * s + r_dot * math.sin(math.rad(i)))
	end
	table.insert(dotX, dotX[1])
	table.insert(dotY, dotY[1])

	renderAndSelect(
		{ createStroke(topX, topY, orangeColor, 255), createStroke(dotX, dotY, orangeColor, 255) },
		{ createSplineCircle(cx, cy, GLOBAL_RADIUS, orangeColor, 60) }
	)
end

local function insertCross()
	local cx, cy = getCenter()
	local redColor = 0xE74C3C
	local s = GLOBAL_RADIUS / 35.0

	local bar1X, bar1Y = {}, {}
	local b1Pts = { { -14 * s, -20 * s }, { -20 * s, -14 * s }, { 14 * s, 20 * s }, { 20 * s, 14 * s } }
	for _, pt in ipairs(b1Pts) do
		table.insert(bar1X, cx + pt[1])
		table.insert(bar1Y, cy + pt[2])
	end
	table.insert(bar1X, bar1X[1])
	table.insert(bar1Y, bar1Y[1])

	local bar2X, bar2Y = {}, {}
	local b2Pts = { { 20 * s, -14 * s }, { 14 * s, -20 * s }, { -20 * s, 14 * s }, { -14 * s, 20 * s } }
	for _, pt in ipairs(b2Pts) do
		table.insert(bar2X, cx + pt[1])
		table.insert(bar2Y, cy + pt[2])
	end
	table.insert(bar2X, bar2X[1])
	table.insert(bar2Y, bar2Y[1])

	renderAndSelect(
		{ createStroke(bar1X, bar1Y, redColor, 255), createStroke(bar2X, bar2Y, redColor, 255) },
		{ createSplineCircle(cx, cy, GLOBAL_RADIUS, redColor, 60) }
	)
end

local function insertQuestion()
	local cx, cy = getCenter()
	local color = 0xE5A50A
	local s = GLOBAL_RADIUS / 35.0

	local topX, topY = {}, {}
	for a = 140, 400, 10 do
		table.insert(topX, cx + 13 * s * math.cos(math.rad(a)))
		table.insert(topY, cy - 8 * s + 13 * s * math.sin(math.rad(a)))
	end
	table.insert(topX, cx + 4 * s)
	table.insert(topY, cy + 8 * s)
	table.insert(topX, cx + 4 * s)
	table.insert(topY, cy + 15 * s)
	table.insert(topX, cx - 4 * s)
	table.insert(topY, cy + 15 * s)
	table.insert(topX, cx - 4 * s)
	table.insert(topY, cy + 8 * s)
	for a = 400, 140, -10 do
		table.insert(topX, cx + 5 * s * math.cos(math.rad(a)))
		table.insert(topY, cy - 8 * s + 5 * s * math.sin(math.rad(a)))
	end
	table.insert(topX, topX[1])
	table.insert(topY, topY[1])

	local dotX, dotY = {}, {}
	local r_dot = 4.5 * s
	for i = 0, 360, 20 do
		table.insert(dotX, cx + r_dot * math.cos(math.rad(i)))
		table.insert(dotY, cy + 23 * s + r_dot * math.sin(math.rad(i)))
	end
	table.insert(dotX, dotX[1])
	table.insert(dotY, dotY[1])

	renderAndSelect(
		{ createStroke(topX, topY, color, 255), createStroke(dotX, dotY, color, 255) },
		{ createSplineCircle(cx, cy, GLOBAL_RADIUS, color, 60) }
	)
end

function drawHollowStar()
	insertHollowStar()
end
function drawSolidStar()
	insertSolidStar()
end
function drawSolidHeart()
	insertHeart()
end
function drawSolidCheckmark()
	insertCheckmark()
end
function drawSolidExclamation()
	insertExclamation()
end
function drawSolidCross()
	insertCross()
end
function drawSolidQuestion()
	insertQuestion()
end

function cycleShapes()
	local doc = app.getDocumentStructure()
	local pageNo = doc.currentPage
	local layerNo = doc.pages[pageNo].currentLayer
	local now = os.time()

	if (now - lastDrawTime > 3) or (lastDrawnPage ~= pageNo) or (lastDrawnLayer ~= layerNo) then
		lastDrawnRefs = {}
		currentShapeIndex = 1
	end

	if #lastDrawnRefs > 0 then
		app.addToSelection(lastDrawnRefs)
		app.activateAction("delete")
		app.refreshPage()
	end

	lastDrawnRefs = {}
	lastDrawTime = os.time()
	lastDrawnPage = pageNo
	lastDrawnLayer = layerNo

	local shapeFunctions = {
		insertHollowStar,
		insertSolidStar,
		insertHeart,
		insertCheckmark,
		insertExclamation,
		insertQuestion,
		insertCross,
	}

	app.changeActionState("select-tool", app.C.Tool_pen)
	shapeFunctions[currentShapeIndex]()

	currentShapeIndex = currentShapeIndex + 1
	if currentShapeIndex > #shapeFunctions then
		currentShapeIndex = 1
	end
end

local function insertSequenceMarker(shapeType)
	local doc = app.getDocumentStructure()
	local pageNo = doc.currentPage
	local layerNo = doc.pages[pageNo].currentLayer
	local now = os.time()

	if
		(now - seqLastTime > 3)
		or (lastDrawnPage ~= pageNo)
		or (lastDrawnLayer ~= layerNo)
		or (seqLastShapeType ~= shapeType)
	then
		seqNum = 1
		seqRefs = {}
		seqLastShapeType = shapeType
	else
		seqNum = seqNum + 1
	end

	if #seqRefs > 0 then
		app.addToSelection(seqRefs)
		app.activateAction("delete")
		app.refreshPage()
	end

	seqRefs = {}
	seqLastTime = os.time()
	lastDrawnPage = pageNo
	lastDrawnLayer = layerNo

	local cx, cy = getCenter()
	local redColor = 0xE74C3C
	local r = 8.5

	local s = 1.0 -- scale
	if shapeType == 1 then
		s = (seqNum < 10) and 2.5 or 1.85
	else
		s = (seqNum < 10) and 1.6 or 1.3
	end

	local strokes = {}
	local splines = {}

	if shapeType == 1 then
		table.insert(splines, createSplineCircle(cx, cy, r, redColor, 20))
	else
		local triX, triY = {}, {}
		local pts = { { 0, -9.5 }, { 9, 5 }, { -9, 5 } }
		for _, pt in ipairs(pts) do
			table.insert(triX, cx + pt[1])
			table.insert(triY, cy + pt[2])
		end
		table.insert(triX, triX[1])
		table.insert(triY, triY[1])
		table.insert(strokes, createStroke(triX, triY, redColor, 20))
	end

	local function getDigitPath(char)
		local pts = {}
		local function addLine(x, y)
			table.insert(pts, { x, y })
		end
		local function addArc(acx, acy, rx, ry, a1, a2, steps)
			for i = 0, steps do
				local a = math.rad(a1 + (a2 - a1) * (i / steps))
				addLine(acx + rx * math.cos(a), acy + ry * math.sin(a))
			end
		end

		if char == "0" then
			addArc(0, 0, 0.8, 1.8, 0, 360, 24)
		elseif char == "1" then
			addLine(-0.4, -1)
			addLine(0.2, -2)
			addLine(0.2, 2)
		elseif char == "2" then
			addArc(0, -1, 0.9, 1, 150, 360, 14)
			addLine(-1, 2)
			addLine(1, 2)
		elseif char == "3" then
			addArc(0, -1, 0.9, 1, 160, 450, 14)
			addArc(0, 1, 0.9, 1, 270, 520, 14)
		elseif char == "4" then
			addLine(0.6, 2)
			addLine(0.6, -2)
			addLine(-1.2, 0.5)
			addLine(1.2, 0.5)
		elseif char == "5" then
			addLine(0.8, -2)
			addLine(-0.8, -2)
			addLine(-0.8, -0.2)
			addArc(0, 0.8, 0.9, 1.2, 230, 500, 16)
		elseif char == "6" then
			addArc(0, 1, 0.9, 1, 180, 180 + 360, 20)
			addLine(0.8, -1.8)
		elseif char == "7" then
			addLine(-1, -2)
			addLine(1, -2)
			addLine(-0.3, 2)
		elseif char == "8" then
			addArc(0, -1, 0.8, 1, 90, 90 + 360, 16)
			addArc(0, 1, 0.9, 1, 270, 270 + 360, 16)
		elseif char == "9" then
			addArc(0, -1, 0.9, 1, 0, 360, 20)
			addLine(0.6, 2)
		end
		return pts
	end

	local numStr = tostring(seqNum)
	local len = #numStr
	local charWidth = 2.2
	local startOffset = -(len - 1) * charWidth / 2

	for i = 1, len do
		local char = numStr:sub(i, i)
		local path = getDigitPath(char)
		if path and #path > 0 then
			local px, py = {}, {}
			local offsetX = startOffset + (i - 1) * charWidth
			for _, pt in ipairs(path) do
				table.insert(px, cx + (pt[1] + offsetX) * s)
				table.insert(py, cy + pt[2] * s)
			end
			table.insert(strokes, createStroke(px, py, redColor, 0))
		end
	end

	app.changeActionState("select-tool", app.C.Tool_pen)
	seqRefs = renderAndSelect(strokes, splines)
end

function drawSeqCircle()
	insertSequenceMarker(1)
end
function drawSeqTriangle()
	insertSequenceMarker(2)
end

local function drawTableGrid()
	local strokes = {}
	local color = 0xE74C3C
	local totalW = tblState.cols * tblState.cellW
	local totalH = tblState.rows * tblState.cellH

	for r = 0, tblState.rows do
		local y = tblState.startY + r * tblState.cellH
		table.insert(strokes, createStroke({ tblState.startX, tblState.startX + totalW }, { y, y }, color, 0))
	end

	for c = 0, tblState.cols do
		local x = tblState.startX + c * tblState.cellW
		table.insert(strokes, createStroke({ x, x }, { tblState.startY, tblState.startY + totalH }, color, 0))
	end

	app.changeActionState("select-tool", app.C.Tool_pen)
	return renderAndSelect(strokes)
end

local function handleTableAction(action)
	local doc = app.getDocumentStructure()
	local pageNo = doc.currentPage
	local layerNo = doc.pages[pageNo].currentLayer
	local now = os.time()

	if (now - tblState.lastTime > 5) or (tblState.page ~= pageNo) or (tblState.layer ~= layerNo) then
		local cx, cy = getCenter()
		tblState.startX = cx - 60
		tblState.startY = cy - 17.5
		tblState.rows = 1
		tblState.cols = 1
		tblState.cellW = 30
		tblState.cellH = 15
		tblState.refs = {}

		if action == "makeSquare" then
			tblState.cellW = tblState.cellH
		end
	else
		if action == "addCol" then
			tblState.cols = tblState.cols + 1
		elseif action == "addRow" then
			tblState.rows = tblState.rows + 1
		elseif action == "cycleW" then
			tblState.cellW = tblState.cellW + 10
			if tblState.cellW > 200 then
				tblState.cellW = 30
			end
		elseif action == "cycleH" then
			tblState.cellH = tblState.cellH + 5
			if tblState.cellH > 100 then
				tblState.cellH = 15
			end
		elseif action == "makeSquare" then
			tblState.cellW = tblState.cellH
		end
	end

	tblState.lastTime = os.time()
	tblState.page = pageNo
	tblState.layer = layerNo

	if #tblState.refs > 0 then
		app.addToSelection(tblState.refs)
		app.activateAction("delete")
		app.refreshPage()
	end

	tblState.refs = drawTableGrid()
end

function drawTableCol()
	handleTableAction("addCol")
end
function drawTableRow()
	handleTableAction("addRow")
end
function cycleTableWidth()
	handleTableAction("cycleW")
end
function cycleTableHeight()
	handleTableAction("cycleH")
end
function makeTableSquare()
	handleTableAction("makeSquare")
end

-- ============================================================================
-- Smart Wavy Toggle
-- ============================================================================

local function analyzeStroke(stroke)
	if not stroke or not stroke.x or #stroke.x < 2 then
		return "unknown"
	end

	local maxDist, furthestIdx = 0, 1
	local totalLen = 0

	for i = 2, #stroke.x do
		local dx_step = stroke.x[i] - stroke.x[i - 1]
		local dy_step = stroke.y[i] - stroke.y[i - 1]
		totalLen = totalLen + math.sqrt(dx_step * dx_step + dy_step * dy_step)

		local dx = stroke.x[i] - stroke.x[1]
		local dy = stroke.y[i] - stroke.y[1]
		local d = math.sqrt(dx * dx + dy * dy)
		if d > maxDist then
			maxDist = d
			furthestIdx = i
		end
	end

	if maxDist < 5 then
		return "unknown"
	end

	local x1, y1 = stroke.x[1], stroke.y[1]
	local x2, y2 = stroke.x[furthestIdx], stroke.y[furthestIdx]
	local endX, endY = stroke.x[#stroke.x], stroke.y[#stroke.y]

	local startEndDist = math.sqrt((endX - x1) ^ 2 + (endY - y1) ^ 2)
	local isClosed = startEndDist < maxDist * 0.3

	local maxDeviation = 0
	for i = 1, #stroke.x do
		local distToLine = math.abs((x2 - x1) * (y1 - stroke.y[i]) - (x1 - stroke.x[i]) * (y2 - y1)) / maxDist
		if distToLine > maxDeviation then
			maxDeviation = distToLine
		end
	end

	if isClosed and maxDeviation > math.max(4.0, maxDist * 0.05) then
		return "unknown"
	end

	if maxDeviation > maxDist * 0.20 then
		return "unknown"
	end

	local lengthRatio = totalLen / maxDist

	if lengthRatio > 1.15 then
		if isClosed then
			return "straight", x1, y1, x2, y2, maxDist
		else
			if startEndDist < 5 then
				endX, endY = x2, y2
			end
			return "curved", x1, y1, endX, endY, startEndDist
		end
	elseif maxDeviation > math.max(3.0, maxDist * 0.05) then
		return "curved", x1, y1, endX, endY, startEndDist
	else
		return "straight", x1, y1, x2, y2, maxDist
	end
end

function toggleWavyLine()
	local success, selectedStrokes = pcall(app.getStrokes, "selection")
	if not success or type(selectedStrokes) ~= "table" or #selectedStrokes == 0 then
		return
	end

	local newStrokes = {}
	local newSplines = {}
	local refsToDelete = {}

	for _, stroke in ipairs(selectedStrokes) do
		local shapeType, sx, sy, ex, ey, dist = analyzeStroke(stroke)

		if shapeType == "straight" then
			local angle = math.atan2 and math.atan2(ey - sy, ex - sx) or math.atan(ey - sy, ex - sx)
			local cos_a, sin_a = math.cos(angle), math.sin(angle)

			local amplitude = 0.7 + (stroke.width or 2.0) * 0.2
			local wavelength = 6.0
			local hw = dist / math.max(1, math.floor(dist / (wavelength / 2)))
			local n_waves = math.floor(dist / hw + 0.5)

			local coords = {}

			local function rot(lx, ly)
				return sx + lx * cos_a - ly * sin_a, sy + lx * sin_a + ly * cos_a
			end

			for i = 0, n_waves - 1 do
				local t0 = i * hw
				local t3 = (i + 1) * hw
				local sign = (i % 2 == 0) and 1 or -1

				local env_mid = (t0 + t3) / 2
				local env = 1.0
				if env_mid < wavelength / 2 then
					env = env_mid / (wavelength / 2)
				end
				if dist - env_mid < wavelength / 2 then
					env = (dist - env_mid) / (wavelength / 2)
				end

				local cur_A = amplitude * env * sign * 1.333
				local cp_dist = hw / 3

				local p0x, p0y = rot(t0, 0)
				local p1x, p1y = rot(t0 + cp_dist, cur_A)
				local p2x, p2y = rot(t3 - cp_dist, cur_A)
				local p3x, p3y = rot(t3, 0)

				table.insert(coords, p0x)
				table.insert(coords, p0y)
				table.insert(coords, p1x)
				table.insert(coords, p1y)
				table.insert(coords, p2x)
				table.insert(coords, p2y)
				table.insert(coords, p3x)
				table.insert(coords, p3y)
			end

			if #coords > 0 then
				table.insert(newSplines, {
					coordinates = coords,
					tool = stroke.tool,
					width = stroke.width,
					color = stroke.color,
					fill = stroke.fill,
					lineStyle = stroke.lineStyle,
				})
				table.insert(refsToDelete, stroke.ref)
			end
		elseif shapeType == "curved" then
			table.insert(newStrokes, {
				x = { sx, ex },
				y = { sy, ey },
				pressure = { 1.0, 1.0 },
				tool = stroke.tool,
				width = stroke.width,
				color = stroke.color,
				fill = stroke.fill,
				lineStyle = stroke.lineStyle,
			})
			table.insert(refsToDelete, stroke.ref)
		end
	end

	if #refsToDelete > 0 then
		app.clearSelection()
		app.addToSelection(refsToDelete)
		app.activateAction("delete")

		if #newStrokes > 0 then
			app.addStrokes({ strokes = newStrokes })
		end
		if #newSplines > 0 then
			app.addSplines({ splines = newSplines })
		end
		app.refreshPage()
	end
end

-- ============================================================================
-- Smart Arrow Toggle
-- ============================================================================

local function hasStartArrowSignature(px, py)
	if #px < 4 then
		return false
	end
	if math.abs(px[2] - px[4]) > 0.05 or math.abs(py[2] - py[4]) > 0.05 then
		return false
	end
	local d1 = math.sqrt((px[1] - px[2]) ^ 2 + (py[1] - py[2]) ^ 2)
	local d2 = math.sqrt((px[3] - px[2]) ^ 2 + (py[3] - py[2]) ^ 2)
	return math.abs(d1 - d2) < 2.0
end

local function hasEndArrowSignature(px, py)
	local m = #px
	if m < 4 then
		return false
	end
	if math.abs(px[m - 1] - px[m - 3]) > 0.05 or math.abs(py[m - 1] - py[m - 3]) > 0.05 then
		return false
	end
	local d1 = math.sqrt((px[m] - px[m - 1]) ^ 2 + (py[m] - py[m - 1]) ^ 2)
	local d2 = math.sqrt((px[m - 2] - px[m - 1]) ^ 2 + (py[m - 2] - py[m - 1]) ^ 2)
	return math.abs(d1 - d2) < 2.0
end

function toggleArrowLine()
	local success, selectedStrokes = pcall(app.getStrokes, "selection")
	if not success or type(selectedStrokes) ~= "table" or #selectedStrokes == 0 then
		return
	end

	local newStrokes = {}
	local refsToDelete = {}
	local convertedAny = false

	for _, stroke in ipairs(selectedStrokes) do
		if stroke.tool == "pen" or stroke.tool == "highlighter" then
			local px, py, pp = stroke.x, stroke.y, stroke.pressure
			local has_pres = (type(pp) == "table" and #pp == #px)

			local hasStart = hasStartArrowSignature(px, py)
			local hasEnd = hasEndArrowSignature(px, py)

			local currentState = 0
			if hasStart and hasEnd then
				currentState = 3
			elseif hasStart then
				currentState = 2
			elseif hasEnd then
				currentState = 1
			end

			local startIdx = hasStart and 4 or 1
			local endIdx = hasEnd and (#px - 3) or #px

			if endIdx >= startIdx then
				local bx, by, bp = {}, {}, {}
				for i = startIdx, endIdx do
					table.insert(bx, px[i])
					table.insert(by, py[i])
					if has_pres then
						table.insert(bp, pp[i])
					end
				end

				local maxDist, furthestIdx = 0, 1
				for i = 2, #bx do
					local d = math.sqrt((bx[i] - bx[1]) ^ 2 + (by[i] - by[1]) ^ 2)
					if d > maxDist then
						maxDist = d
						furthestIdx = i
					end
				end

				local startEndDist = math.sqrt((bx[#bx] - bx[1]) ^ 2 + (by[#by] - by[1]) ^ 2)
				local isOpen = startEndDist >= maxDist * 0.15

				local maxDeviation = 0
				if maxDist > 0 then
					local x1, y1 = bx[1], by[1]
					local x2, y2 = bx[furthestIdx], by[furthestIdx]
					for i = 1, #bx do
						local distToLine = math.abs((x2 - x1) * (y1 - by[i]) - (x1 - bx[i]) * (y2 - y1)) / maxDist
						if distToLine > maxDeviation then
							maxDeviation = distToLine
						end
					end
				end

				local isFlattened = maxDeviation <= math.max(4.0, maxDist * 0.05)

				if maxDist >= 10 and (isOpen or isFlattened) then
					if not isOpen and isFlattened then
						bx = { bx[1], bx[furthestIdx] }
						by = { by[1], by[furthestIdx] }
						if has_pres then
							bp = { bp[1], bp[furthestIdx] }
						end
					end
					local nextState = (currentState + 1) % 4
					local nx, ny, np = {}, {}, {}
					local L = 8.0 + (stroke.width or 2.0) * 1.5
					local angle_offset = math.pi / 6
					local atan2 = math.atan2 and math.atan2 or math.atan

					for i = 1, #bx do
						table.insert(nx, bx[i])
						table.insert(ny, by[i])
						if has_pres then
							table.insert(np, bp[i])
						end
					end

					if nextState == 2 or nextState == 3 then
						local sx, sy = bx[1], by[1]
						local angle = 0
						for i = 2, #bx do
							if math.sqrt((bx[i] - sx) ^ 2 + (by[i] - sy) ^ 2) > 3 then
								angle = atan2(by[i] - sy, bx[i] - sx)
								break
							end
						end
						local b1x, b1y =
							sx + L * math.cos(angle - angle_offset), sy + L * math.sin(angle - angle_offset)
						local b2x, b2y =
							sx + L * math.cos(angle + angle_offset), sy + L * math.sin(angle + angle_offset)

						table.insert(nx, 1, b2x)
						table.insert(ny, 1, b2y)
						if has_pres then
							table.insert(np, 1, bp[1])
						end
						table.insert(nx, 1, sx)
						table.insert(ny, 1, sy)
						if has_pres then
							table.insert(np, 1, bp[1])
						end
						table.insert(nx, 1, b1x)
						table.insert(ny, 1, b1y)
						if has_pres then
							table.insert(np, 1, bp[1])
						end
					end

					if nextState == 1 or nextState == 3 then
						local m = #bx
						local ex, ey = bx[m], by[m]
						local angle = 0
						for i = m - 1, 1, -1 do
							if math.sqrt((ex - bx[i]) ^ 2 + (ey - by[i]) ^ 2) > 3 then
								angle = atan2(ey - by[i], ex - bx[i])
								break
							end
						end
						local b1x, b1y =
							ex - L * math.cos(angle - angle_offset), ey - L * math.sin(angle - angle_offset)
						local b2x, b2y =
							ex - L * math.cos(angle + angle_offset), ey - L * math.sin(angle + angle_offset)

						table.insert(nx, b1x)
						table.insert(ny, b1y)
						if has_pres then
							table.insert(np, bp[m])
						end
						table.insert(nx, ex)
						table.insert(ny, ey)
						if has_pres then
							table.insert(np, bp[m])
						end
						table.insert(nx, b2x)
						table.insert(ny, b2y)
						if has_pres then
							table.insert(np, bp[m])
						end
					end

					table.insert(newStrokes, {
						x = nx,
						y = ny,
						pressure = has_pres and np or nil,
						tool = stroke.tool,
						width = stroke.width,
						color = stroke.color,
						fill = stroke.fill,
						lineStyle = stroke.lineStyle,
					})
					table.insert(refsToDelete, stroke.ref)
					convertedAny = true
				end
			end
		end
	end

	if convertedAny and #refsToDelete > 0 then
		app.clearSelection()
		app.addToSelection(refsToDelete)
		app.activateAction("delete")

		app.addStrokes({ strokes = newStrokes })

		local allStrokes = app.getStrokes("layer")
		local newRefs = {}
		if type(allStrokes) == "table" and #allStrokes >= #newStrokes then
			for i = #allStrokes, #allStrokes - #newStrokes + 1, -1 do
				if allStrokes[i] and allStrokes[i].ref then
					table.insert(newRefs, allStrokes[i].ref)
				end
			end
		end

		if #newRefs > 0 then
			app.addToSelection(newRefs)
		end

		app.refreshPage()
	end
end

-- ============================================================================
-- Smart Curly Brace Toggle
-- ============================================================================

function toggleCurlyBrace()
	local success, selectedStrokes = pcall(app.getStrokes, "selection")
	if not success or type(selectedStrokes) ~= "table" or #selectedStrokes == 0 then
		return
	end

	local newStrokes = {}
	local refsToDelete = {}
	local convertedAny = false

	local now = os.time()
	local isNewInteraction = (now - lastBraceTime > 3)
	lastBraceTime = now
	local stateUpdated = false

	for _, stroke in ipairs(selectedStrokes) do
		if stroke.tool == "pen" or stroke.tool == "highlighter" then
			local bx, by = stroke.x, stroke.y

			local maxDist, furthestIdx = 0, 1
			for i = 2, #bx do
				local d = math.sqrt((bx[i] - bx[1]) ^ 2 + (by[i] - by[1]) ^ 2)
				if d > maxDist then
					maxDist = d
					furthestIdx = i
				end
			end

			local startEndDist = math.sqrt((bx[#bx] - bx[1]) ^ 2 + (by[#by] - by[1]) ^ 2)
			local sx, sy, ex, ey

			if startEndDist < 15 then
				sx, sy = bx[1], by[1]
				ex, ey = bx[furthestIdx], by[furthestIdx]
			else
				sx, sy = bx[1], by[1]
				ex, ey = bx[#bx], by[#by]
			end

			if ey < sy then
				sx, ex = ex, sx
				sy, ey = ey, sy
			end

			local dist = math.sqrt((ex - sx) ^ 2 + (ey - sy) ^ 2)

			if dist > 15 then
				local angle = math.atan2(ey - sy, ex - sx)
				local cos_a, sin_a = math.cos(angle), math.sin(angle)

				local max_abs_dev = 0
				local dev_sign = 0
				local best_peak_lx = dist * 0.5

				for i = 1, #bx do
					local lx = (bx[i] - sx) * cos_a + (by[i] - sy) * sin_a
					local ly = -(bx[i] - sx) * sin_a + (by[i] - sy) * cos_a
					local abs_ly = math.abs(ly)

					if abs_ly > max_abs_dev then
						max_abs_dev = abs_ly
						dev_sign = ly > 0 and 1 or -1
						best_peak_lx = lx
					end
				end

				if not stateUpdated then
					if isNewInteraction then
						if max_abs_dev > 4.0 then
							braceState = (dev_sign < 0) and 1 or 2
						else
							braceState = 1
						end
					else
						braceState = (braceState % 4) + 1
					end
					stateUpdated = true
				end

				local peak_ratio = 0.5
				if max_abs_dev > 4.0 then
					peak_ratio = math.max(0.15, math.min(0.85, best_peak_lx / dist))
				end

				local bulge_width = 16 + (stroke.width or 2.0) * 1.5
				if max_abs_dev > 8.0 then
					bulge_width = max_abs_dev
				end

				local W_local = (braceState == 1 or braceState == 3) and -bulge_width or bulge_width
				local p0x, p0y = 0, 0
				local p1x, p1y, p2x, p2y, p3x, p3y
				local p4x, p4y, p5x, p5y, p6x, p6y, p7x, p7y

				local pr = peak_ratio
				local inv_pr = 1.0 - pr

				if braceState == 1 or braceState == 2 then
					p1x, p1y = dist * (pr * 0.2), W_local * 0.8
					p2x, p2y = dist * (pr * 0.8), W_local * 0.2
					p3x, p3y = dist * pr, W_local

					p4x, p4y = dist * pr, W_local
					p5x, p5y = dist * (pr + inv_pr * 0.2), W_local * 0.2
					p6x, p6y = dist * (pr + inv_pr * 0.8), W_local * 0.8
					p7x, p7y = dist, 0
				else
					p1x, p1y = dist * (pr * 0.3), 0
					p2x, p2y = dist * pr, W_local * 0.15
					p3x, p3y = dist * pr, W_local

					p4x, p4y = dist * pr, W_local
					p5x, p5y = dist * pr, W_local * 0.15
					p6x, p6y = dist * (pr + inv_pr * 0.7), 0
					p7x, p7y = dist, 0
				end

				local function rot(lx, ly)
					return sx + lx * cos_a - ly * sin_a, sy + lx * sin_a + ly * cos_a
				end

				local function bezier(t, p0, p1, p2, p3)
					local u = 1 - t
					return u * u * u * p0 + 3 * u * u * t * p1 + 3 * u * t * t * p2 + t * t * t * p3
				end

				local nx, ny, np = {}, {}, {}
				local steps = math.max(20, math.floor(dist / 2.0))

				for i = 0, steps do
					local t = i / steps
					local lx = bezier(t, p0x, p1x, p2x, p3x)
					local ly = bezier(t, p0y, p1y, p2y, p3y)
					local gx, gy = rot(lx, ly)
					table.insert(nx, gx)
					table.insert(ny, gy)
					table.insert(np, 1.0)
				end

				for i = 1, steps do
					local t = i / steps
					local lx = bezier(t, p4x, p5x, p6x, p7x)
					local ly = bezier(t, p4y, p5y, p6y, p7y)
					local gx, gy = rot(lx, ly)
					table.insert(nx, gx)
					table.insert(ny, gy)
					table.insert(np, 1.0)
				end

				table.insert(newStrokes, {
					x = nx,
					y = ny,
					pressure = np,
					tool = stroke.tool,
					width = stroke.width,
					color = stroke.color,
					fill = stroke.fill,
					lineStyle = stroke.lineStyle,
				})

				table.insert(refsToDelete, stroke.ref)
				convertedAny = true
			end
		end
	end

	if convertedAny and #refsToDelete > 0 then
		app.clearSelection()
		app.addToSelection(refsToDelete)
		app.activateAction("delete")

		if #newStrokes > 0 then
			app.addStrokes({ strokes = newStrokes })
		end

		local allStrokes = app.getStrokes("layer")
		local newRefs = {}
		if type(allStrokes) == "table" and #allStrokes >= #newStrokes then
			for i = #allStrokes, #allStrokes - #newStrokes + 1, -1 do
				if allStrokes[i] and allStrokes[i].ref then
					table.insert(newRefs, allStrokes[i].ref)
				end
			end
		end
		if #newRefs > 0 then
			app.addToSelection(newRefs)
		end

		app.refreshPage()
	end
end

function initUi()
	app.registerUi({ menu = "Cycle Shapes", callback = "cycleShapes", accelerator = "<Alt>s" })

	app.registerUi({
		menu = "Shape: Seq Circle",
		callback = "drawSeqCircle",
		accelerator = "<Alt>c",
	})

	app.registerUi({
		menu = "Shape: Seq Triangle",
		callback = "drawSeqTriangle",
		accelerator = "<Alt>v",
	})

	app.registerUi({ menu = "Shape: Table Add Column", callback = "drawTableCol", accelerator = "<Alt>t" })
	app.registerUi({ menu = "Shape: Table New Row", callback = "drawTableRow", accelerator = "<Alt>r" })
	app.registerUi({ menu = "Shape: Table Cycle Width", callback = "cycleTableWidth", accelerator = "<Alt>h" })
	app.registerUi({ menu = "Shape: Table Cycle Height", callback = "cycleTableHeight", accelerator = "<Alt>l" })
	app.registerUi({ menu = "Shape: Table Make Square", callback = "makeTableSquare", accelerator = "<Alt>k" })
	app.registerUi({ menu = "Shape: Toggle Wavy Line", callback = "toggleWavyLine", accelerator = "w" })
	app.registerUi({ menu = "Shape: Toggle Arrows", callback = "toggleArrowLine", accelerator = "a" })
	app.registerUi({ menu = "Shape: Toggle Curly Brace", callback = "toggleCurlyBrace", accelerator = "b" })
end
