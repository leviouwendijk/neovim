return function(context)
    vim.diagnostic.config(
        {
            virtual_text = { spacing = 2, prefix = "●" },
            signs = true,
            underline = true,
            update_in_insert = false,
            severity_sort = true,
            float = {
                focusable = false,
                border = "rounded",
                source = true,
                -- source = "if_many",  -- valid values: true | false | "if_many"
                header = "",
                prefix = "",
            },
        }
    )

    local function diag_jump(delta, severity)
        return function()
            local opts = { count = delta, float = true } -- float=true shows the message on jump
            if severity then
                opts.severity = vim.diagnostic.severity[severity]
            end
            vim.diagnostic.jump(opts)
        end
    end

    return {
        jump = diag_jump,
    }
end
