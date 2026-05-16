local utils = require("utils")
local sequence = {}

local seqRefs = {}
local seqLastTime = 0
local seqNum = 1
local seqLastShapeType = 0

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

	local cx, cy = utils.getCenter()
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
		local splineCircle = utils.createSplineCircle(cx, cy, r, redColor, 20)
		splineCircle.width = 1.0
		table.insert(splines, splineCircle)
	else
		local triX, triY = {}, {}
		local pts = { { 0, -9.5 }, { 9, 5 }, { -9, 5 } }
		for _, pt in ipairs(pts) do
			table.insert(triX, cx + pt[1])
			table.insert(triY, cy + pt[2])
		end
		table.insert(triX, triX[1])
		table.insert(triY, triY[1])
		table.insert(strokes, utils.createStroke(triX, triY, redColor, 20))
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
			table.insert(strokes, utils.createStroke(px, py, redColor, 0))
		end
	end

	app.changeActionState("select-tool", app.C.Tool_pen)
	seqRefs = utils.renderAndSelect(strokes, splines)
end

function sequence.drawSeqCircle()
	insertSequenceMarker(1)
end
function sequence.drawSeqTriangle()
	insertSequenceMarker(2)
end

return sequence
