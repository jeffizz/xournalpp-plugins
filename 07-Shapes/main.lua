local source = debug.getinfo(1, "S").source
if source:sub(1, 1) == "@" then
	local plugin_dir = source:sub(2):match("(.*[/\\])") or ""
	package.path = package.path .. ";" .. plugin_dir .. "?.lua"
end

local shapes = require("shapes")
local sequence = require("sequence")
local tables = require("tables")
local toggles = require("toggles")

function cycleShapes()
	shapes.cycleShapes()
end
function drawSeqCircle()
	sequence.drawSeqCircle()
end
function drawSeqTriangle()
	sequence.drawSeqTriangle()
end

function drawTableCol()
	tables.drawTableCol()
end
function drawTableRow()
	tables.drawTableRow()
end
function cycleTableWidth()
	tables.cycleTableWidth()
end
function cycleTableHeight()
	tables.cycleTableHeight()
end
function makeTableSquare()
	tables.makeTableSquare()
end

function toggleWavyLine()
	toggles.toggleWavyLine()
end
function toggleArrowLine()
	toggles.toggleArrowLine()
end
function toggleCurlyBrace()
	toggles.toggleCurlyBrace()
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
	app.registerUi({ menu = "Shape: Table Cycle Width", callback = "cycleTableWidth", accelerator = "<Alt>l" })
	app.registerUi({ menu = "Shape: Table Cycle Height", callback = "cycleTableHeight", accelerator = "<Alt>h" })
	app.registerUi({ menu = "Shape: Table Make Square", callback = "makeTableSquare", accelerator = "<Alt>k" })
	app.registerUi({ menu = "Shape: Toggle Wavy Line", callback = "toggleWavyLine", accelerator = "w" })
	app.registerUi({ menu = "Shape: Toggle Arrows", callback = "toggleArrowLine", accelerator = "a" })
	app.registerUi({ menu = "Shape: Toggle Curly Brace", callback = "toggleCurlyBrace", accelerator = "b" })
end
