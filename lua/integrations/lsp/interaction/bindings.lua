return function(context, interaction)
    local lsp_zero = context.lsp_zero
    local diag_jump = interaction.diagnostics.jump
    local copy_current_diagnostic =
        interaction.diagnostic_copy.copy_current
    local open_float_and_copy =
        interaction.diagnostic_copy.open_float_and_copy
    local copy_buffer_diags =
        interaction.diagnostic_copy.copy_buffer
    local symbol_library_preview =
        interaction.symbol_library.preview

    lsp_zero.on_attach(function(client, bufnr)
        local opts = {buffer = bufnr, remap = false}

        vim.keymap.set("n", "gd", function() vim.lsp.buf.definition() end, opts)
        vim.keymap.set("n", "K", function() vim.lsp.buf.hover() end, opts)
        vim.keymap.set("n", "<leader>vws", function() vim.lsp.buf.workspace_symbol() end, opts)
        vim.keymap.set("n", "<leader>vd", function() vim.diagnostic.open_float() end, opts)
        -- vim.keymap.set("n", "[d", function() vim.diagnostic.goto_next() end, opts)
        -- vim.keymap.set("n", "]d", function() vim.diagnostic.goto_prev() end, opts)

        -- BEGIN OF NEW
        -- yank diagnostic under cursor
        vim.keymap.set("n", "<leader>vy", copy_current_diagnostic, opts)

        -- open float and also copy it
        vim.keymap.set("n", "<leader>vD", open_float_and_copy, opts)

        -- copy ALL diags in buffer
        vim.keymap.set("n", "<leader>vA", copy_buffer_diags(), opts)

        -- copy only specific severities
        vim.keymap.set("n", "<leader>vE", copy_buffer_diags("ERROR"), opts)
        vim.keymap.set("n", "<leader>vW", copy_buffer_diags("WARN"),  opts)
        vim.keymap.set("n", "<leader>vI", copy_buffer_diags("INFO"),  opts)
        vim.keymap.set("n", "<leader>vH", copy_buffer_diags("HINT"),  opts)
        -- EONEW

        vim.keymap.set("n", "[d", diag_jump(-1), opts)
        vim.keymap.set("n", "]d", diag_jump( 1), opts)

        vim.keymap.set("n", "[e", diag_jump(-1, "ERROR"), opts)
        vim.keymap.set("n", "]e", diag_jump( 1, "ERROR"), opts)

        vim.keymap.set("n", "[w", diag_jump(-1, "WARN"),  opts)
        vim.keymap.set("n", "]w", diag_jump( 1, "WARN"),  opts)

        vim.keymap.set("n", "[i", diag_jump(-1, "INFO"),  opts)
        vim.keymap.set("n", "]i", diag_jump( 1, "INFO"),  opts)

        vim.keymap.set("n", "[h", diag_jump(-1, "HINT"),  opts)
        vim.keymap.set("n", "]h", diag_jump( 1, "HINT"),  opts)

        vim.keymap.set("n", "<leader>vca", function() vim.lsp.buf.code_action() end, opts)
        vim.keymap.set("n", "<leader>vrr", function() vim.lsp.buf.references() end, opts)
        vim.keymap.set("n", "<leader>vrn", function() vim.lsp.buf.rename() end, opts)
        vim.keymap.set("i", "<C-h>", function() vim.lsp.buf.signature_help() end, opts)

        -- new for checking source lib
        vim.keymap.set("n", "<leader>vL", symbol_library_preview, {
            buffer = bufnr,
            silent = true,
            desc = "Symbol → Library",
        })
    end)
end
