local acc = require("accessor")
local funcs = require("config.funcs")

--vim.opt.guicursor = ""
vim.g.query_lint_on = { "BufEnter", "BufWrite" }
vim.g.mapleader = " "
vim.opt.nu = true
vim.opt.relativenumber = true
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.smartindent = false
vim.opt.wrap = false
vim.g.netrw_localrm_cmd = acc.bin.trash -- configure Netrw to use Trash for deletions
vim.g.netrw_localrmdir_cmd = acc.bin.trash

local existing = vim.g.netrw_list_hide or ""
local ds_pattern = '\\(^\\.DS_Store$\\)'  -- vim regex for a literal ".DS_Store"
if existing == "" then
    vim.g.netrw_list_hide = ds_pattern
elseif not existing:find("DS_Store") then
    vim.g.netrw_list_hide = existing .. '\\|' .. ds_pattern
end

-- global: tell vim wildignore to ignore .DS_Store (useful for completion / globbing)
vim.opt.wildignore:append("**/.DS_Store")
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.hidden = true
vim.opt.autoread = true
vim.opt.undofile = true
vim.opt.undodir = acc.paths.undodir
vim.opt.hlsearch = false
vim.opt.incsearch = true
vim.opt.termguicolors = true
vim.opt.cursorline = true
vim.opt.mouse = "a"
vim.opt.scrolloff = 8
vim.opt.signcolumn = "yes"
vim.opt.isfname:append("@-@")
vim.opt.updatetime = 50
vim.opt.colorcolumn = "80"


-- vim.g.clipboard = {
--     name = 'macOS-pbpaste-pbcopy',
--     copy = {
--         ['+'] = 'pbcopy',
--         ['*'] = 'pbcopy',
--     },
--     paste = {
--         ['+'] = 'pbpaste',
--         ['*'] = 'pbpaste',
--     },
--     cache_enabled = 0,
-- }

-- vim.opt.clipboard:append('unnamedplus')
-- vim.opt.clipboard = "unnamed"
vim.opt.clipboard = "unnamedplus"

-- CMP config
vim.o.completeopt = 'menu,menuone,noselect'

vim.api.nvim_create_user_command("ClipShow", function()
    local plus = vim.fn.getreg("+")
    local pb, ok = funcs.system(acc.bin.pbpaste)

    print("getreg(+): " .. plus:gsub("%s+$", ""))

    if ok and type(pb) == "string" then
        print("pbpaste  : " .. pb:gsub("%s+$", ""))
    else
        print("pbpaste  : unavailable")
    end
end, {})

-- local grp = vim.api.nvim_create_augroup('CLIP_SYNC_YANK', { clear = true })
-- vim.api.nvim_create_autocmd('TextYankPost', {
--     group = grp,
--     callback = function()
--         if vim.v.event.operator ~= 'y' then return end  -- only yanks
--         -- Prefer regcontents to preserve lines and regtype (char/line/block)
--         local lines = vim.v.event.regcontents
--         if type(lines) ~= 'table' or #lines == 0 then return end
--         local text   = table.concat(lines, '\n')
--         local regtyp = vim.v.event.regtype or 'v'       -- charwise fallback

--         -- 1) Update Neovim’s + register immediately
--         pcall(vim.fn.setreg, '+', text, regtyp)

--         -- 2) Also update macOS pasteboard (blocking) so new sessions read it right away
--         --    (Safe even if OSC52 already copied; this just keeps everyone in sync.)
--         pcall(vim.fn.system, 'pbcopy', text)
--     end,
-- })

-- vim.api.nvim_create_autocmd({ 'VimEnter', 'FocusGained' }, {
--     group = grp,
--     callback = function()
--         -- pull live clipboard, write to '+'
--         local ok, s = pcall(vim.fn.system, 'pbpaste')
--         if ok and type(s) == 'string' and #s > 0 then
--             -- use charwise by default; adapt if you prefer linewise: 'V'
--             pcall(vim.fn.setreg, '+', s, 'v')
--         end
--     end,
-- })
