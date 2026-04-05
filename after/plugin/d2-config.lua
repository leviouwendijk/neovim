local function set_d2_width_from_columns()
    vim.g.d2_ascii_preview_width = math.floor(
        vim.o.columns * 0.60
    )
end

set_d2_width_from_columns()

vim.api.nvim_create_autocmd("VimResized",
    {
        callback = set_d2_width_from_columns,
    }
)
