-- Insert the “Task Set” template at the cursor and jump to <name>
local function insert_task_set_template()
    local template = [[
* Task Set

** <name>

   REQUIRES: <dependency, or project to be finished first>

   SERVES: <over-arching purpose>
   PRIORITY: <LOW | MEDIUM | HIGH | CRITICAL>

* Milestone
  - ( ) <list>
    

* Actions (time-tracking)
  - (<leader>tsl) <what you did>
    ]]

    -- Split into lines (keep empty lines)
    local lines = vim.split(template, "\n", { plain = true })

    -- Insert after current line
    local row = vim.api.nvim_win_get_cursor(0)[1]
    vim.api.nvim_buf_set_lines(0, row, row, false, lines)

    -- Move cursor to the first "<name>" placeholder
    vim.fn.search([[\\V<name>]], "W")
end

-- Normal-mode mapping: <leader>npi
vim.keymap.set("n", "<leader>npi", insert_task_set_template, {
    noremap = true,
    silent = true,
    desc = "Insert Task Set template",
})
