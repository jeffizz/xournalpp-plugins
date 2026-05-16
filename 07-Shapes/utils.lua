local utils = {}

utils.GLOBAL_RADIUS = 22
utils.lastDrawnRefs = {}
utils.lastDrawnPage = nil
utils.lastDrawnLayer = nil

function utils.getCenter()
	local doc = app.getDocumentStructure()
	local pageNo = doc.currentPage
	local page = doc.pages[pageNo]
	local w = page.pageWidth or 595
	local h = page.pageHeight or 842
	return w / 2, h / 2
end

function utils.createStroke(px, py, color, fillValue)
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

function utils.renderAndSelect(strokesTable, splinesTable)
	if strokesTable and #strokesTable > 0 then
		app.addStrokes({ strokes = strokesTable })
	end
	if splinesTable and #splinesTable > 0 then
		app.addSplines({ splines = splinesTable })
	end
	app.refreshPage()

	local doc = app.getDocumentStructure()
	utils.lastDrawnPage = doc.currentPage
	utils.lastDrawnLayer = doc.pages[utils.lastDrawnPage].currentLayer

	local allStrokes = app.getStrokes("layer")
	utils.lastDrawnRefs = {}

	local countStrokes = strokesTable and #strokesTable or 0
	local countSplines = splinesTable and #splinesTable or 0
	local totalAdded = countStrokes + countSplines

	if allStrokes and type(allStrokes) == "table" and totalAdded > 0 then
		for i = #allStrokes, #allStrokes - totalAdded + 1, -1 do
			if allStrokes[i] and allStrokes[i].ref then
				table.insert(utils.lastDrawnRefs, allStrokes[i].ref)
			end
		end
		if #utils.lastDrawnRefs > 0 then
			app.addToSelection(utils.lastDrawnRefs)
		end
	end

	return utils.lastDrawnRefs
end

function utils.createSplineCircle(cx, cy, r, color, fillValue)
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

function utils.createSplineHeart(cx, cy, r, color, fillValue)
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

return utils
