local funcs = require("config.funcs")
local acc = require("accessor")

---@enum ThemeMode
local ThemeMode = {
    dark = "dark",
    light = "light",
    system = "system",
}

local theme = acc.theme or {}
local dayTheme = theme.light or "dawnfox"
local nightTheme = theme.dark or "nightfox"
local defaultColorSetting = dayTheme

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

local last_mode = nil

local function apply_mode(mode)
    if mode ~= "dark" and mode ~= "light" then
        return
    end

    if last_mode == mode then
        return
    end

    last_mode = mode
    vim.o.background = mode
    SetColor(mode == "dark" and nightTheme or dayTheme, false)
end

local theme_mode = ThemeMode[theme.mode or ThemeMode.system]
if not theme_mode then
    note(("Unknown theme.mode '%s'; expected dark, light or system. Using system.")
        :format(tostring(theme.mode)), vim.log.levels.WARN)
    theme_mode = ThemeMode.system
end

if theme_mode ~= ThemeMode.system then
    apply_mode(theme_mode)
    return
end

local appearance = funcs.require_or_nil("utils.appearance", {
    message = "utils.appearance missing; using default theme",
})

local mode = appearance and appearance.get_macos_appearance()

if mode then
    apply_mode(mode)
else
    note("macOS appearance not detected; using default theme", vim.log.levels.INFO)
    vim.o.background = "light"
    SetColor(defaultColorSetting, false)
end

if appearance and type(appearance.watch_macos_appearance) == "function" then
    vim.api.nvim_create_autocmd("User", {
        group = vim.api.nvim_create_augroup("SystemAppearanceTheme", { clear = true }),
        pattern = "SystemAppearanceChanged",
        callback = function(event)
            apply_mode(event.data and event.data.mode)
        end,
    })

    appearance.watch_macos_appearance()
end
