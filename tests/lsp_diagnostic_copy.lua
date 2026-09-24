local testing = require("testing")
local expect = testing.expect
local make_diagnostic_copy =
    require(
        "integrations.lsp.interaction.diagnostic-copy"
    )

local diagnostic_copy =
    make_diagnostic_copy({
        funcs = {
            safe_notify = function() end,
        },
    })

local function contains(text, expected)
    return text:find(
        expected,
        1,
        true
    ) ~= nil
end

local function with_buffer(lines, body)
    local buf =
        vim.api.nvim_create_buf(
            false,
            true
        )

    vim.api.nvim_buf_set_lines(
        buf,
        0,
        -1,
        false,
        lines
    )

    local ok, result =
        pcall(body, buf)

    if vim.api.nvim_buf_is_valid(buf) then
        pcall(
            vim.api.nvim_buf_delete,
            buf,
            {
                force = true,
            }
        )
    end

    if not ok then
        error(result, 0)
    end

    return result
end

return testing.suite(
    "lsp_diagnostic_copy",
    {
        testing.test(
            "snippet_places_caret_after_target_line",
            function()
                with_buffer(
                    {
                        "alpha",
                        "beta value",
                        "gamma",
                    },
                    function(buf)
                        local snippet =
                            diagnostic_copy.snippet(
                                buf,
                                1,
                                4,
                                1
                            )

                        expect.truthy(
                            contains(
                                snippet,
                                "1 | alpha\n"
                                    .. "2 | beta value\n"
                                    .. "        ^\n"
                                    .. "3 | gamma"
                            ),
                            "caret follows the target source line"
                        )
                    end
                )
            end
        ),

        testing.test(
            "format_keeps_snippet_and_flattens_multiline_message",
            function()
                with_buffer(
                    {
                        "let before = 0",
                        "let value = 1",
                        "let after = 2",
                    },
                    function(buf)
                        local rendered =
                            diagnostic_copy.format({
                                bufnr = buf,
                                lnum = 1,
                                col = 4,
                                severity =
                                    vim.diagnostic.severity.ERROR,
                                message =
                                    "first line\nsecond line",
                                source = "sourcekit",
                                code = "example-code",
                            })

                        assert(
                            rendered ~= nil,
                            "diagnostic formatter returned nil"
                        )

                        expect.truthy(
                            contains(
                                rendered,
                                "2 | let value = 1\n"
                                    .. "        ^\n"
                                    .. "3 | let after = 2"
                            ),
                            "formatted diagnostic keeps the caret next to its source line"
                        )
                        expect.truthy(
                            contains(
                                rendered,
                                "> first line second line"
                            ),
                            "multiline message is flattened"
                        )
                        expect.truthy(
                            contains(
                                rendered,
                                "source=sourcekit"
                            )
                        )
                        expect.truthy(
                            contains(
                                rendered,
                                "code=example-code"
                            )
                        )
                        expect.truthy(
                            rendered:find(
                                "ts=%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ"
                            ) ~= nil,
                            "UTC timestamp is retained"
                        )
                    end
                )
            end
        ),

        testing.test(
            "format_loads_named_unloaded_buffer_for_context",
            function(context)
                local fixture =
                    context:fixture({
                        files = {
                            ["Diagnostic.swift"] =
                                "let first = 1\n"
                                .. "let second = 2\n"
                                .. "let third = 3\n",
                        },
                    })
                local source =
                    fixture:path(
                        "Diagnostic.swift"
                    )
                local buf =
                    vim.fn.bufadd(source)

                expect.falsy(
                    vim.api.nvim_buf_is_loaded(buf),
                    "fixture buffer starts unloaded"
                )

                local ok, rendered =
                    pcall(
                        diagnostic_copy.format,
                        {
                            bufnr = buf,
                            lnum = 1,
                            col = 4,
                            severity =
                                vim.diagnostic.severity.WARN,
                            message = "warning",
                        }
                    )

                if vim.api.nvim_buf_is_valid(buf) then
                    pcall(
                        vim.api.nvim_buf_delete,
                        buf,
                        {
                            force = true,
                        }
                    )
                end

                if not ok then
                    error(rendered, 0)
                end

                expect.truthy(
                    contains(
                        rendered,
                        "2 | let second = 2\n"
                            .. "        ^\n"
                            .. "3 | let third = 3"
                    ),
                    "unloaded source is loaded once and formatted with context"
                )
            end
        ),
    },
    {
        title = "LSP diagnostic copy",
    }
)
