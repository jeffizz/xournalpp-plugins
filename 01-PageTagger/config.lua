-- ============================================================================
-- config.lua | PLUGIN CONFIGURATION & CONSTANTS
-- ============================================================================
local config = {}

config.TAG_COLORS = {
	0xFF0000,
	0xFF6F00,
	0x9400D3,
	0x228B22,
	0x1E60FF,
	0x424242,
}

config.CUSTOM_TAG_COLORS = {
	0xFFFF00,
	0x00BFFF,
	0xADFF2F,
	0xFF00FF,
	0xDAA520,
	0x40E0D0,
	0xCD5C5C,
	0x6B8E23,
	0x9370DB,
	0xFFA07A,
}

-- Default fallback tag pool. Actual configuration is loaded from the PDF's @metadata layer.
config.DEFAULT_QUICK_TAGS = { "core", "key", "insight", "code", "todo", "skip" }

config.TAGS_PER_DIALOG = 6
config.MAX_TAGS_PER_PAGE = 8

return config
