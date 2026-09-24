local function set_statusline_variants()
    local ok, base = pcall(vim.api.nvim_get_hl, 0, { name = "StatusLine", link = false })
    if not ok or not base then return end
    local bold, italic = { bold = true }, { italic = true }
    if base.fg then bold.fg, italic.fg = base.fg, base.fg end
    if base.bg then bold.bg, italic.bg = base.bg, base.bg end
    if base.sp then bold.sp, italic.sp = base.sp, base.sp end
    vim.api.nvim_set_hl(0, "StatusLineBold", bold)
    vim.api.nvim_set_hl(0, "StatusLineItalic", italic)
end
vim.api.nvim_create_autocmd({ "VimEnter", "ColorScheme" }, { callback = set_statusline_variants })
_G._StatusLineVariants_refresh = set_statusline_variants
