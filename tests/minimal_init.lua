local source = debug.getinfo(1, "S").source
local path = source:sub(1, 1) == "@" and source:sub(2) or source
local root = vim.fn.fnamemodify(path, ":p:h:h")

vim.g.nvim_config_test_root = root

-- Keep the headless harness isolated from this config's normal plugin and
-- after/plugin startup. Neovim's builtin directory browser must also be
-- disabled before startup finishes so the explicitly loaded Netrw owns
-- directory buffers.
vim.g.loaded_nvim_dir_plugin = 1
vim.o.loadplugins = false

vim.opt.runtimepath:prepend(root)

vim.g.netrw_banner = 0
vim.g.netrw_liststyle = 0

vim.cmd("filetype plugin on")
vim.cmd("packadd netrw")
