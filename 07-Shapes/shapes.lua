local utils = require("utils")
local shapes = {}

local lastDrawTime = 0
local currentShapeIndex = 1

local function insertHollowStar()
	local cx, cy = utils.getCenter()
	local p = {}
	for i = 0, 4 do
		local angle = math.rad(-90 + i * 72)
		table.insert(
			p,
			{ x = cx + utils.GLOBAL_RADIUS * math.cos(angle), y = cy + utils.GLOBAL_RADIUS * math.sin(angle) }
		)
	end
	local px, py = {}, {}
	local order = { 1, 3, 5, 2, 4, 1 }
	for _, idx in ipairs(order) do
		table.insert(px, p[idx].x)
		table.insert(py, p[idx].y)
	end
	utils.renderAndSelect({ utils.createStroke(px, py, 0xFF0000, 0) })
end

local function insertSolidStar()
	local cx, cy = utils.getCenter()
	local r = utils.GLOBAL_RADIUS * 0.382
	local px, py = {}, {}
	for i = 0, 10 do
		local angle = math.rad(-90 + i * 36)
		local radius = (i % 2 == 0) and utils.GLOBAL_RADIUS or r
		table.insert(px, cx + radius * math.cos(angle))
		table.insert(py, cy + radius * math.sin(angle))
	end
	utils.renderAndSelect({ utils.createStroke(px, py, 0xFF0000, 178) })
end

local function insertHeart()
	local cx, cy = utils.getCenter()
	utils.renderAndSelect(nil, { utils.createSplineHeart(cx, cy, utils.GLOBAL_RADIUS, 0xE74C3C, 178) })
end

local function insertCheckmark()
	local cx, cy = utils.getCenter()
	local greenColor = 0x27AE60
	local s = utils.GLOBAL_RADIUS / 35.0

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

	utils.renderAndSelect(
		{ utils.createStroke(px, py, greenColor, 255) },
		{ utils.createSplineCircle(cx, cy, utils.GLOBAL_RADIUS, greenColor, 60) }
	)
end

local function insertExclamation()
	local cx, cy = utils.getCenter()
	local orangeColor = 0xF39C12
	local s = utils.GLOBAL_RADIUS / 35.0

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

	utils.renderAndSelect(
		{ utils.createStroke(topX, topY, orangeColor, 255), utils.createStroke(dotX, dotY, orangeColor, 255) },
		{ utils.createSplineCircle(cx, cy, utils.GLOBAL_RADIUS, orangeColor, 60) }
	)
end

local function insertCross()
	local cx, cy = utils.getCenter()
	local redColor = 0xE74C3C
	local s = utils.GLOBAL_RADIUS / 35.0

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

	utils.renderAndSelect(
		{ utils.createStroke(bar1X, bar1Y, redColor, 255), utils.createStroke(bar2X, bar2Y, redColor, 255) },
		{ utils.createSplineCircle(cx, cy, utils.GLOBAL_RADIUS, redColor, 60) }
	)
end

local function insertQuestion()
	local cx, cy = utils.getCenter()
	local color = 0xE5A50A
	local s = utils.GLOBAL_RADIUS / 35.0

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

	utils.renderAndSelect(
		{ utils.createStroke(topX, topY, color, 255), utils.createStroke(dotX, dotY, color, 255) },
		{ utils.createSplineCircle(cx, cy, utils.GLOBAL_RADIUS, color, 60) }
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

function shapes.cycleShapes()
	local doc = app.getDocumentStructure()
	local pageNo = doc.currentPage
	local layerNo = doc.pages[pageNo].currentLayer
	local now = os.time()

	if (now - lastDrawTime > 3) or (utils.lastDrawnPage ~= pageNo) or (utils.lastDrawnLayer ~= layerNo) then
		utils.lastDrawnRefs = {}
		currentShapeIndex = 1
	end

	if #utils.lastDrawnRefs > 0 then
		app.addToSelection(utils.lastDrawnRefs)
		app.activateAction("delete")
		app.refreshPage()
	end

	utils.lastDrawnRefs = {}
	lastDrawTime = os.time()
	utils.lastDrawnPage = pageNo
	utils.lastDrawnLayer = layerNo

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

return shapes
