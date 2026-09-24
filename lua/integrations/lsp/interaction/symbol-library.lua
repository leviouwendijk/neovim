local model =
    require(
        "integrations.lsp.interaction.symbol-library.model"
    )

return function(context)
    local funcs = context.funcs

    -- lib checker (custom)
    -- === Symbol → Library inspector =============================================
    local function make_position_params_safe(client, win)
        local enc = client.offset_encoding or "utf-16"
        win = win or 0
        local params = vim.lsp.util.make_position_params(win, enc)
        return params
    end

    local function symbol_library_preview()
        local bufnr = vim.api.nvim_get_current_buf()
        local clients = vim.lsp.get_clients({ bufnr = bufnr })  -- new API
        if #clients == 0 then
            funcs.safe_notify("No LSP client attached.", vim.log.levels.WARN)
            return
        end

        -- Prefer a client that supports definitionProvider
        local client =
            model.definition_client(clients)

        if not client then
            funcs.safe_notify(
                "No attached LSP client supports definitions.",
                vim.log.levels.WARN
            )
            return
        end

        local params = make_position_params_safe(client, 0)

        -- Method call (self): use colon syntax
        local dispatched =
            client:request(
                "textDocument/definition",
                params,
                function(err, result)
                    if err then
                        local message =
                            type(err) == "table"
                            and err.message
                            or tostring(err)

                        funcs.safe_notify(
                            "Definition request failed: "
                                .. tostring(message),
                            vim.log.levels.WARN
                        )
                        return
                    end

                    local lines =
                        model.definition_lines(result)

                    if not lines then
                        funcs.safe_notify(
                            "No definition found for symbol under cursor.",
                            vim.log.levels.INFO
                        )
                        return
                    end

                    vim.lsp.util.open_floating_preview(
                        lines,
                        "markdown",
                        {
                            border = "rounded",
                            focusable = false,
                        }
                    )
                end,
                bufnr
            )

        if not dispatched then
            funcs.safe_notify(
                "Definition request could not be started.",
                vim.log.levels.WARN
            )
        end
    end

    vim.api.nvim_create_user_command("SymbolLibrary", function()
        symbol_library_preview()
    end, { desc = "Show which library the symbol under cursor belongs to" })
    -- ============================================================================

    return {
        preview = symbol_library_preview,
    }
end
