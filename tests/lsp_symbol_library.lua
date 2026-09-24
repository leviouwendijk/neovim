local testing = require("testing")
local expect = testing.expect
local model =
    require(
        "integrations.lsp.interaction.symbol-library.model"
    )

local function contains(text, expected)
    return text:find(
        expected,
        1,
        true
    ) ~= nil
end

return testing.suite(
    "lsp_symbol_library",
    {
        testing.test(
            "infers_supported_swift_library_paths",
            function()
                local cases = {
                    {
                        "/tmp/App/.build/index-build/checkouts/swift-collections/Sources/Collections/Tree.swift",
                        "swift-collections",
                        "spm",
                    },
                    {
                        "/tmp/App/.build/checkouts/swift-argument-parser/Sources/ArgumentParser/Parsable.swift",
                        "swift-argument-parser",
                        "spm",
                    },
                    {
                        "/tmp/DerivedData/App/SourcePackages/checkouts/swift-log/Sources/Logging/Logging.swift",
                        "swift-log",
                        "spm",
                    },
                    {
                        "/tmp/App/Sources/AppCore/App.swift",
                        "AppCore",
                        "local",
                    },
                    {
                        "/usr/lib/swift/macosx/Foundation.swift",
                        "macosx",
                        "toolchain",
                    },
                }

                for _, case in ipairs(cases) do
                    local lib, kind, path =
                        model.infer_library_from_uri(
                            vim.uri_from_fname(
                                case[1]
                            )
                        )

                    expect.equal(lib, case[2])
                    expect.equal(kind, case[3])
                    expect.equal(path, case[1])
                end
            end
        ),

        testing.test(
            "selects_only_definition_capable_client",
            function()
                local incapable = {
                    id = 1,
                    server_capabilities = {},
                }
                local disabled = {
                    id = 2,
                    server_capabilities = {
                        definitionProvider = false,
                    },
                }
                local capable = {
                    id = 3,
                    server_capabilities = {
                        definitionProvider = {
                            workDoneProgress = true,
                        },
                    },
                }

                expect.equal(
                    model.definition_client({
                        incapable,
                        disabled,
                        capable,
                    }),
                    capable
                )
                expect.nil_value(
                    model.definition_client({
                        incapable,
                        disabled,
                    })
                )
            end
        ),

        testing.test(
            "renders_location_and_location_link_results",
            function()
                local first =
                    "/tmp/App/.build/index-build/checkouts/swift-collections/Sources/Collections/Tree.swift"
                local second =
                    "/tmp/App/.build/index-build/checkouts/swift-collections/Sources/Collections/Node.swift"

                local lines =
                    model.definition_lines({
                        {
                            uri =
                                vim.uri_from_fname(first),
                            range = {
                                start = {
                                    line = 4,
                                    character = 2,
                                },
                            },
                        },
                        {
                            targetUri =
                                vim.uri_from_fname(second),
                            targetRange = {
                                start = {
                                    line = 8,
                                    character = 5,
                                },
                            },
                        },
                    })

                assert(
                    lines ~= nil,
                    "definition result did not produce preview lines"
                )

                local rendered =
                    table.concat(lines, "\n")

                expect.truthy(
                    contains(
                        rendered,
                        "in **swift-collections**:"
                    )
                )
                expect.truthy(
                    contains(
                        rendered,
                        "- **Parent:** swift-collections  _(spm)_"
                    )
                )
                expect.truthy(
                    contains(
                        rendered,
                        first .. "` ➜ 5:3"
                    )
                )
                expect.truthy(
                    contains(
                        rendered,
                        second .. "` ➜ 9:6"
                    )
                )

                local _, parent_count =
                    rendered:gsub(
                        "%- %*%*Parent:%*%*",
                        ""
                    )

                expect.equal(parent_count, 1)
            end
        ),

        testing.test(
            "empty_definition_results_have_no_preview_lines",
            function()
                expect.nil_value(
                    model.definition_lines(nil)
                )
                expect.nil_value(
                    model.definition_lines({})
                )
            end
        ),
    },
    {
        title = "LSP symbol library",
    }
)
