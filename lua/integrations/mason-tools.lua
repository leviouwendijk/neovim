local funcs = require("config.funcs")

local mason_tool_installer = funcs.require_or_nil("mason-tool-installer", {
    message = "mason-tool-installer missing; skipping development tool installation",
})

if not mason_tool_installer then
    return
end

mason_tool_installer.setup({
    ensure_installed = {
        "stylua",
        "swiftlint",
        "shellcheck",
        "shfmt",
    },
    auto_update = false,
    run_on_start = true,
})
