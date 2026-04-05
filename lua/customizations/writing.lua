local acc = require("accessor")
local path = require("config.path")

local prose_roots = {
    acc.paths.writing_root,
    acc.paths.neorg.root,
}

local function set_wrap(enabled)
    vim.opt_local.wrap = enabled
    vim.opt_local.linebreak = enabled
end

local function toggle_wrap()
    local enabled = not vim.wo.wrap
    set_wrap(enabled)

    if enabled then
        print("Auto-wrap enabled.")
    else
        print("Wrap disabled.")
    end
end

local function is_prose_file(bufnr)
    bufnr = bufnr or 0

    local current_path = vim.api.nvim_buf_get_name(bufnr)
    if current_path == "" then
        return false
    end

    for _, root in ipairs(prose_roots) do
        if path.is_relative_to(current_path, root) then
            return true
        end
    end

    return false
end

local function reformat_if_prose_buffer()
    if not is_prose_file(0) then
        return
    end

    local save_cursor = vim.api.nvim_win_get_cursor(0)
    vim.cmd("normal! gg")
    vim.cmd("normal! gqG")
    vim.api.nvim_win_set_cursor(0, save_cursor)
end

vim.api.nvim_create_user_command("Wrap", toggle_wrap, {})

vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
    pattern = vim.tbl_map(function(root)
        return path.glob(root)
    end, prose_roots),
    callback = function()
        -- muted because of excessive red lines::
        -- vim.opt_local.spell = true
        -- vim.opt_local.spelllang = "en_us,nl,he"
        vim.opt_local.spell = true
        vim.opt_local.spelllang = "he"
        set_wrap(true)
        -- vim.opt_local.textwidth = 80  -- Uncomment if needed
    end,
})

vim.api.nvim_create_autocmd("VimResized", {
    pattern = "*",
    callback = reformat_if_prose_buffer,
})

-- local function activate_goyo_limelight()
--      if vim.fn.expand('%:p'):find(writing_dir, 1, true) then
--         vim.cmd(':lua writingFocus()')
--     end
-- end

-- local function writingFocus()
--     vim.cmd(":Goyo")
--     vim.cmd(":Goyo")
--     vim.cmd(":Goyo")
--     vim.cmd(":Limelight")
-- end


-- local function markdownToPDF()
--     local current_file = vim.fn.expand("%:t")
--     local output_dir = "~/myworkdir/pdf_output/"
--     local output_file = output_dir .. current_file:gsub(".md", ".pdf")
--     local command = "!pandoc -s -o " .. output_file .. " %"
--     vim.cmd(command)
-- end

-- vim.keymap.set("n", "<leader>pdf", ":lua markdownToPDF()<CR>", { noremap = true, silent = true })

-- local function markdownToPDF_JetBrains()
--     local current_file = vim.fn.expand("%:t")
--     local output_dir = "~/myworkdir/pdf_output/"
--     local output_file = output_dir .. current_file:gsub(".md", ".pdf")
--     local command = "!pandoc -s --pdf-engine=xelatex -V mainfont=\"JetBrains Mono\" -V fontsize=12 -o " .. output_file .. " %"
--     vim.cmd(command)
-- end

-- vim.keymap.set("n", "<leader>jpdf", ":lua markdownToPDF_JetBrains()<CR>", { noremap = true, silent = true })
