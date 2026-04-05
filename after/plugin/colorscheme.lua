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

function FindColorscheme(color)
    if color == "tokyoday" then
        local ok, t = pcall(require, "tokyonight")
        if not ok then return nil end
        t.setup({
            style = "day",
            transparent = false,
            terminal_colors = true,
            styles = {
                sidebars = "transparent",
                floats = "transparent",
            }
        })
        return "tokyonight"

    elseif color == "tokyonight" then
        local ok, t = pcall(require, "tokyonight")
        if not ok then return nil end
        t.setup({
            style = "night",
            transparent = false,
            terminal_colors = true,
            styles = {
                sidebars = "transparent",
                floats = "transparent",
            }
        })
        return "tokyonight"

    elseif color == "tokyostorm" then
        local ok, t = pcall(require, "tokyonight")
        if not ok then return nil end
        t.setup({ style = "storm" })
        return "tokyonight"

    elseif color == "kanagawa" then
        local ok, k = pcall(require, "kanagawa")
        if not ok then return nil end
        k.setup({ theme = "wave" }) -- default
        return "kanagawa"

    elseif color == "kanagawa-dragon" then
        local ok, k = pcall(require, "kanagawa")
        if not ok then return nil end
        k.setup({ theme = "dragon" })
        return "kanagawa"

    elseif color == "oxocarbon" then
        return "oxocarbon"

    elseif color == "gruvbox-hard" then
        local ok = pcall(require, "gruvbox-material")
        if not ok then return nil end
        vim.g.gruvbox_material_background = "hard"
        return "gruvbox-material"

    elseif color == "catppuccin-latte" then
        local ok, cat = pcall(require, "catppuccin")
        if not ok then return nil end
        cat.setup({
            flavour = "mocha", -- latte, frappe, macchiato, mocha
            background = { -- :h background
                light = "latte",
                dark = "mocha",
            },
            transparent_background = false, -- disables setting the background color.
            show_end_of_buffer = false, -- shows the '~' characters after the end of buffers
            term_colors = false, -- sets terminal colors (e.g. `g:terminal_color_0`)
            dim_inactive = {
                enabled = false, -- dims the background color of inactive window
                shade = "dark",
                percentage = 0.15, -- percentage of the shade to apply to the inactive window
            },
            no_italic = false, -- Force no italic
            no_bold = false, -- Force no bold
            no_underline = false, -- Force no underline
            styles = { -- Handles the styles of general hi groups (see `:h highlight-args`):
                comments = { "italic" }, -- Change the style of comments
                conditionals = { "italic" },
                loops = {},
                functions = {},
                keywords = {},
                strings = {},
                variables = {},
                numbers = {},
                booleans = {},
                properties = {},
                types = {},
                operators = {},
                -- miscs = {}, -- Uncomment to turn off hard-coded styles
            },
            color_overrides = {},
            custom_highlights = {},
            default_integrations = true,
            integrations = {
                cmp = true,
                gitsigns = true,
                nvimtree = true,
                treesitter = true,
                notify = false,
                mini = {
                    enabled = true,
                    indentscope_color = "",
                },
            }
        })
        return "catppuccin"

    elseif color == "catppuccin-dark" then
        local ok, cat = pcall(require, "catppuccin")
        if not ok then return nil end
        cat.setup({
            flavour = "mocha",
            background = { light = "latte", dark = "mocha" },
        })
        return "catppuccin"

    elseif color == "dayfox" then
        local ok, nf = pcall(require, "nightfox")
        if not ok then return nil end
        nf.setup({
            options = {
                styles = {
                    comments = "italic",
                    keywords = "bold",
                    types = "italic,bold",
                }
            }
        })
        return "dayfox"

    elseif color == "dawnfox" then
        local ok, nf = pcall(require, "nightfox")
        if not ok then return nil end
        nf.setup({
            options = {
                styles = {
                    comments = "italic",
                    keywords = "bold",
                    types = "italic,bold",
                }
            }
        })
        return "dawnfox"

    elseif color == "rosedawn" then
        local ok, rp = pcall(require, "rose-pine")
        if not ok then return nil end
        rp.setup({
            variant = "dawn",
        })
        return "rose-pine"

    elseif color == "nightfox" then
        return "nightfox"

    end

    -- Return nil if no custom setup is found, so SetColor defaults to "rose-pine"
    return nil
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
