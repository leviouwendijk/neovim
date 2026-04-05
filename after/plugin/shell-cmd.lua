local funcs = require("config.funcs")

vim.api.nvim_create_user_command("ShellHere", function(opts)
    local shell = funcs.require_or_nil("extensions.shell", {
        message = "extensions.shell missing; ShellHere unavailable",
    })

    if not shell then
        return
    end

    shell.run_here_with_visual_stdin(table.concat(opts.fargs, " "))
end, {
    range = true,
    nargs = "+"
})
