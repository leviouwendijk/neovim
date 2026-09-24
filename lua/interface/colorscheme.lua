local funcs = require("config.funcs")

local appearance = funcs.require_or_nil("utils.appearance", {
    message = "utils.appearance missing; using default theme",
})

local defaultColorSetting = "dawnfox"

local dayTheme = "dawnfox"
local nightTheme= "nightfox"

local function note(msg, level)
    level = level or vim.log.levels.INFO
    if vim.in_fast_event() then
        vim.schedule(function()
            if vim.notify then vim.notify(msg, level) end
            vim.api.nvim_echo({{msg, ""}}, true, {})
        end)
    else
        if vim.notify then vim.notify(msg, level) end
        vim.api.nvim_echo({{msg, ""}}, true, {})
    end
end

require("interface.colorscheme.themes")

function SetColor(color, transparent)
    local requested = color
    transparent = transparent or false

    -- map/prepare
    local mapped = FindColorscheme(requested)
    local used_default = false
    if not mapped then
        mapped = defaultColorSetting or "rose-pine"
        used_default = true
    end

    -- try to apply
    local ok = pcall(vim.cmd.colorscheme, mapped)
    if not ok then
        note(("Failed to load colorscheme '%s'; falling back to '%s'")
            :format(mapped, defaultColorSetting or "rose-pine"), vim.log.levels.WARN)

        ok = pcall(vim.cmd.colorscheme, defaultColorSetting or "rose-pine")
        if not ok then
            note(("Failed to load fallback '%s'; using 'rose-pine'")
                :format(defaultColorSetting or "rose-pine"), vim.log.levels.ERROR)
            pcall(vim.cmd.colorscheme, "rose-pine")
        end
    else
        if used_default and requested ~= mapped then
            note(("Unknown/unconfigured scheme '%s'; using '%s'")
                :format(requested, mapped), vim.log.levels.WARN)
        end
    end

    if transparent then MakeClear() end
end

function MakeClear()
    vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
    vim.api.nvim_set_hl(0, "NormalFloat",  { bg = "none" })
end

local mode = nil

if appearance and type(appearance.get_macos_appearance) == "function" then
    mode = appearance.get_macos_appearance()   -- "dark" | "light" | nil
end

if not mode then
    note("macOS appearance not detected; using default theme", vim.log.levels.INFO)
end
vim.o.background = (mode == "dark") and "dark" or "light"

local picked = (mode == "dark" and nightTheme) or (mode == "light" and dayTheme) or defaultColorSetting

SetColor(picked, false)
