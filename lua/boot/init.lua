local loader = require("boot.loader")
local acc = require("accessor")
-- local notify = require("utils.notify")

local function get_hostname()
    local ok, name = pcall(vim.loop.os_gethostname)  -- more robust than io.popen
    if not ok or not name then return "unknown" end
    return (name:gsub("%s+", ""))
end

local hostname = get_hostname()
-- notify.info("Hostname: " .. hostname)
local short = hostname:match("^[^.]+") or hostname

local selections = require("boot.selections")

local host_selections = (acc.boot and acc.boot.host_selections) or {}
local default_selection = (acc.boot and acc.boot.default_selection) or "minimal"

local selected_name =
    host_selections[hostname]
    or host_selections[short]
    or default_selection

local selected_config = selections[selected_name] or selections.minimal
local state = loader.process(selected_config)

local M = {
    state = state,
    acc = acc,
}

function M.get(category, id)
    return loader.get(category, id)
end

function M.config(id)
    return loader.get("config", id)
end

return M
