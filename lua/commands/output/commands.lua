return function(context)
    local output = context.output
    local acc = context.acc

    vim.api.nvim_create_user_command(
        "OutputRunSplit",
        function(opts)
            local cmd = opts.fargs[1]
            output.run_file_in_split(cmd, vim.fn.expand("%:p"), 0)
        end, {
            nargs = 1,
            complete = function()
                return {
                    acc.bin.python,
                    acc.bin.swift,
                    acc.bin.bash,
                    acc.bin.node,
                }
            end
        }
    )

    vim.api.nvim_create_user_command(
        "OutputRunFloat",
        function(opts)
            local cmd = opts.fargs[1]
            output.run_file_in_float(cmd, vim.fn.expand("%:p"), 0)
        end, {
            nargs = 1,
            complete = function()
                return {
                    acc.bin.python,
                    acc.bin.swift,
                    acc.bin.bash,
                    acc.bin.node,
                }
            end
        }
    )

    vim.api.nvim_create_user_command(
        "OutputToggle",
        function(opts)
            output.toggle(opts.args ~= "" and opts.args or nil) -- args: "float" | "split" | ""
        end, {
            nargs = "?",
            complete = function()
                return { "float", "split" }
            end
        }
    )
end
