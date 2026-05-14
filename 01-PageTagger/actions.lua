-- ============================================================================
-- actions.lua | ACTION FACADE (Aggregates sub-modules for UI bindings)
-- ============================================================================
local browse = require("action_browse")
local tag = require("action_tag")
local sys = require("action_sys")

local actions = {}

for k, v in pairs(browse) do
	actions[k] = v
end
for k, v in pairs(tag) do
	actions[k] = v
end
for k, v in pairs(sys) do
	actions[k] = v
end

return actions
