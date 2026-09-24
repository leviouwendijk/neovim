local Loader = require("boot.loader")
local imports = require("boot.imports")
local acc = require("accessor")

local production_order = {
    "config",
    "packages",
    "core",
    "interface",
    "customizations",
    "extensions",
    "utils",
    "commands",
    "integrations",
    "testing",
}

local loader = Loader.new({
    imports = imports,
    order = production_order,
})

local function get_hostname()
    local ok, name = pcall(vim.loop.os_gethostname)
    if not ok or not name then
        return "unknown"
    end

    return (name:gsub("%s+", ""))
end

local hostname = get_hostname()
local short = hostname:match("^[^.]+") or hostname

local selections = require("boot.selections")

local host_selections =
    (acc.boot and acc.boot.host_selections) or {}
local default_selection =
    (acc.boot and acc.boot.default_selection) or "minimal"

local selected_name =
    host_selections[hostname]
    or host_selections[short]
    or default_selection

local selected_config =
    selections[selected_name]
    or selections.minimal

local state = loader:process(selected_config)

local M = {
    state = state,
    acc = acc,
}

function M.get(category, id)
    return loader:get(category, id)
end

function M.config(id)
    return loader:get("config", id)
end

return M
