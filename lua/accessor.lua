local defaults = require("config.defaults")
local local_ok, local_cfg = pcall(require, "config.local")
local path = require("config.path")

if not local_ok then
    local_cfg = {}
end

local cfg = vim.tbl_deep_extend("force", defaults, local_cfg)

local function expand_strings_deep(value)
    if type(value) == "string" then
        return path.expand(value)
    end

    if type(value) == "table" then
        local out = {}
        for k, v in pairs(value) do
            out[k] = expand_strings_deep(v)
        end
        return out
    end

    return value
end

if cfg.paths then
    cfg.paths = expand_strings_deep(cfg.paths)
end

cfg.path = path

return cfg
