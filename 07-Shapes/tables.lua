local utils = require("utils")
local tables = {}

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

local function drawTableGrid()
	local strokes = {}
	local color = 0xE74C3C
	local totalW = tblState.cols * tblState.cellW
	local totalH = tblState.rows * tblState.cellH

	for r = 0, tblState.rows do
		local y = tblState.startY + r * tblState.cellH
		table.insert(strokes, utils.createStroke({ tblState.startX, tblState.startX + totalW }, { y, y }, color, 0))
	end

	for c = 0, tblState.cols do
		local x = tblState.startX + c * tblState.cellW
		table.insert(strokes, utils.createStroke({ x, x }, { tblState.startY, tblState.startY + totalH }, color, 0))
	end

	app.changeActionState("select-tool", app.C.Tool_pen)
	return utils.renderAndSelect(strokes)
end

local function checkSelectedRectangle()
	local success, selectedStrokes = pcall(app.getStrokes, "selection")
	if not success or type(selectedStrokes) ~= "table" or #selectedStrokes ~= 1 then
		return false
	end

	local stroke = selectedStrokes[1]
	if not stroke.x or #stroke.x < 4 then
		return false
	end

	local minX, maxX = math.huge, -math.huge
	local minY, maxY = math.huge, -math.huge
	local totalLen = 0

	for i = 1, #stroke.x do
		local x, y = stroke.x[i], stroke.y[i]
		if x < minX then
			minX = x
		end
		if x > maxX then
			maxX = x
		end
		if y < minY then
			minY = y
		end
		if y > maxY then
			maxY = y
		end
		if i > 1 then
			totalLen = totalLen + math.sqrt((stroke.x[i] - stroke.x[i - 1]) ^ 2 + (stroke.y[i] - stroke.y[i - 1]) ^ 2)
		end
	end

	local w = maxX - minX
	local h = maxY - minY
	local bboxPerimeter = 2 * (w + h)
	local startEndDist = math.sqrt((stroke.x[#stroke.x] - stroke.x[1]) ^ 2 + (stroke.y[#stroke.y] - stroke.y[1]) ^ 2)

	if startEndDist < 15 and w > 10 and h > 5 and math.abs(totalLen - bboxPerimeter) < bboxPerimeter * 0.20 then
		return true, minX, minY, w, h, stroke.ref
	end
	return false
end

local function handleTableAction(action)
	local doc = app.getDocumentStructure()
	local pageNo = doc.currentPage
	local layerNo = doc.pages[pageNo].currentLayer
	local now = os.time()

	local success, sel = pcall(app.getStrokes, "selection")
	local selCount = (success and type(sel) == "table") and #sel or 0

	local isRect, rx, ry, rw, rh, rref = checkSelectedRectangle()

	local isSelectingCurrentTable = false
	if selCount > 0 and #tblState.refs > 0 then
		local matchCount = 0
		for _, s in ipairs(sel) do
			for _, r in ipairs(tblState.refs) do
				if s.ref == r then
					matchCount = matchCount + 1
					break
				end
			end
		end
		if matchCount > 0 and matchCount == selCount then
			isSelectingCurrentTable = true
		end
	end

	if selCount > 0 and not isRect and not isSelectingCurrentTable then
		return
	end

	local shouldInit = (now - tblState.lastTime > 5) or (tblState.page ~= pageNo) or (tblState.layer ~= layerNo)
	if isRect then
		shouldInit = true
	end

	if shouldInit then
		if #tblState.refs > 0 then
			app.clearSelection()
			app.addToSelection(tblState.refs)
			app.activateAction("delete")
		end

		if isRect then
			tblState.startX = rx
			tblState.startY = ry
			tblState.cellW = rw
			tblState.cellH = rh
			tblState.rows = 1
			tblState.cols = 1
			tblState.refs = {}

			if action == "addCol" then
				tblState.cols = 2
			elseif action == "addRow" then
				tblState.rows = 2
			elseif action == "makeSquare" then
				tblState.cellW = tblState.cellH
			end

			app.clearSelection()
			app.addToSelection({ rref })
			app.activateAction("delete")
		else
			local cx, cy = utils.getCenter()
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
		app.clearSelection()
		app.addToSelection(tblState.refs)
		app.activateAction("delete")
	end

	tblState.refs = drawTableGrid()
end

function tables.drawTableCol()
	handleTableAction("addCol")
end
function tables.drawTableRow()
	handleTableAction("addRow")
end
function tables.cycleTableWidth()
	handleTableAction("cycleW")
end
function tables.cycleTableHeight()
	handleTableAction("cycleH")
end
function tables.makeTableSquare()
	handleTableAction("makeSquare")
end

return tables
