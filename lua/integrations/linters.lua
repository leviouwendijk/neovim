local funcs = require("config.funcs")
local lint = funcs.require_or_nil("lint", {
    message = "nvim-lint missing; external linter diagnostics unavailable",
})
if not lint then return end

lint.linters_by_ft = {
    swift = { "swiftlint" },
    sh = { "shellcheck" },
    bash = { "shellcheck" },
}

local function run(bufnr)
    if not vim.api.nvim_buf_is_valid(bufnr)
        or vim.bo[bufnr].buftype ~= "" then
        return
    end
    local names = lint.linters_by_ft[vim.bo[bufnr].filetype]
    if not names then return end

    -- Missing Mason tools should not prevent LSP diagnostics or spam errors.
    local available = {}
    for _, name in ipairs(names) do
        if vim.fn.executable(name) == 1 then
            available[#available + 1] = name
        end
    end
    if #available > 0 then lint.try_lint(available) end
end

local group = vim.api.nvim_create_augroup("nvim_external_lint", {
    clear = true,
})
vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost" }, {
    group = group,
    callback = function(event)
        run(event.buf)
    end,
})
vim.api.nvim_create_user_command("ToolLint", function()
    run(vim.api.nvim_get_current_buf())
end, { desc = "Run SwiftLint or ShellCheck for this buffer" })
