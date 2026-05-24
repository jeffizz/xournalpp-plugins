-- ============================================================================
-- main.lua | ENTRY POINT & PLUGIN REGISTRATION
-- ============================================================================
local actions = require("actions")

function addTagAndNote()
	actions.addTagAndNote()
end
function deleteTagUI()
	actions.deleteTagUI()
end
function browseOrNextTag()
	actions.browseOrNextTag()
end
function addVocabTag()
	actions.addVocabTag()
end
function sanitizeWorkspace()
	actions.sanitizeWorkspace()
end
function browseChapterTags()
	actions.browseChapterTags()
end
function setupToolbarIcons()
	actions.setupToolbarIcons()
end

-- Callbacks
function onTagDialogResult(idx)
	actions.onTagDialogResult(idx)
end
function onFinishBrowse(idx)
	actions.onFinishBrowse(idx)
end
function onDeleteTagResult(idx)
	actions.onDeleteTagResult(idx)
end
function onQuickTagResult(idx)
	actions.onQuickTagResult(idx)
end
function onChapmarkConfirmResult(idx)
	actions.onChapmarkConfirmResult(idx)
end

-- Toolbar Quick Tags
function toolbarQuickTag_chapter()
	actions.toolbarQuickTag("@chapter")
end
function toolbarQuickTag_1()
	actions.toolbarQuickTagSlot(1)
end
function toolbarQuickTag_2()
	actions.toolbarQuickTagSlot(2)
end
function toolbarQuickTag_3()
	actions.toolbarQuickTagSlot(3)
end
function toolbarQuickTag_4()
	actions.toolbarQuickTagSlot(4)
end
function toolbarQuickTag_5()
	actions.toolbarQuickTagSlot(5)
end
function toolbarQuickTag_6()
	actions.toolbarQuickTagSlot(6)
end

function initUi()
	app.registerUi({ menu = "Tagger: Add Tag", callback = "addTagAndNote", accelerator = "<Ctrl>w" })
	app.registerUi({ menu = "Tagger: Delete Tag", callback = "deleteTagUI", accelerator = "<Ctrl>d" })
	app.registerUi({ menu = "Tagger: Browse Full Book", callback = "browseOrNextTag", accelerator = "<Ctrl>f" })
	app.registerUi({ menu = "Tagger: Browse Chapter", callback = "browseChapterTags", accelerator = "<Ctrl>r" })
	app.registerUi({
		menu = "Tagger: Add Vocab",
		callback = "addVocabTag",
		toolbarId = "tag_vocab",
		iconName = "tag_icon_vocab",
	})
	app.registerUi({ menu = "Tagger: Sanitize Workspace", callback = "sanitizeWorkspace", accelerator = "<Ctrl>z" })
	app.registerUi({ menu = "Tagger: Setup Quick Tags", callback = "setupToolbarIcons" })

	app.registerUi({
		menu = "    ├─ Tag Slot 0 (built-in: @chapter)",
		callback = "toolbarQuickTag_chapter",
		toolbarId = "tag_chapter",
		iconName = "tag_icon_chapter",
	})
	app.registerUi({
		menu = "    ├─ Tag Slot 1 (default: core)",
		callback = "toolbarQuickTag_1",
		toolbarId = "tag_slot_1",
		iconName = "tag_icon_1",
	})
	app.registerUi({
		menu = "    ├─ Tag Slot 2 (default: key)",
		callback = "toolbarQuickTag_2",
		toolbarId = "tag_slot_2",
		iconName = "tag_icon_2",
	})
	app.registerUi({
		menu = "    ├─ Tag Slot 3 (default: insight)",
		callback = "toolbarQuickTag_3",
		toolbarId = "tag_slot_3",
		iconName = "tag_icon_3",
	})
	app.registerUi({
		menu = "    ├─ Tag Slot 4 (default: code)",
		callback = "toolbarQuickTag_4",
		toolbarId = "tag_slot_4",
		iconName = "tag_icon_4",
	})
	app.registerUi({
		menu = "    ├─ Tag Slot 5 (default: todo)",
		callback = "toolbarQuickTag_5",
		toolbarId = "tag_slot_5",
		iconName = "tag_icon_5",
	})
	app.registerUi({
		menu = "    └─ Tag Slot 6 (default: skip)",
		callback = "toolbarQuickTag_6",
		toolbarId = "tag_slot_6",
		iconName = "tag_icon_6",
	})
end
