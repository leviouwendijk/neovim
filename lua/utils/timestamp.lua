local templates = {
    default = "%Y-%m-%d %H:%M:%S %Z",
    parens  = "(%Y-%m-%d %H:%M:%S %Z)",
    log  = "(%Y-%m-%d @ %H:%M %Z)",
    short   = "%H:%M",
    date    = "%Y-%m-%d",
    bracket = "[%Y/%m/%d %H:%M]",
}

local function insert_timestamp(opts)
    local key = opts.args ~= "" and opts.args or "default"
    local format = templates[key]

    if not format then
        print("Unknown template: " .. key)
        return
    end

    local cmd = string.format("date '+%s'", format)
    local handle = io.popen(cmd)
    if not handle then
        print("Error: Could not run date command")
        return
    end

    local result = handle:read("*a")
    handle:close()
    result = result:gsub("%s+$", "")

    vim.api.nvim_put({ result }, "c", true, true)
end

vim.api.nvim_create_user_command("Timestamp", insert_timestamp, {
    nargs = "?",
    complete = function() return vim.tbl_keys(templates) end,
})

vim.keymap.set("n", "<leader>tsd", ":Timestamp default<CR>", { noremap = true, silent = true })
vim.keymap.set("n", "<leader>tsl", ":Timestamp log<CR>", { noremap = true, silent = true })
vim.keymap.set("n", "<leader>tss", ":Timestamp short<CR>", { noremap = true, silent = true })
