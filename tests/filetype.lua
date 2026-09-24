local testing = require("testing")
local expect = testing.expect
local layout = require("core.filetype.layout")
local stats = require("core.filetype.stats")
local path = require("core.filetype.path")
local inspector = require("core.filetype.inspect")

local function rendered_text(chunks)
    local parts = {}

    for _, chunk in ipairs(chunks) do
        table.insert(parts, chunk[1])
    end

    return table.concat(parts)
end

local function width(text)
    return vim.fn.strdisplaywidth(text)
end

return testing.suite("filetype", {
    testing.test(
        "metadata_budget_reserves_path_and_caps_right_side",
        function()
            expect.equal(
                layout.metadata_budget({
                    window_width = 100,
                    textoff = 4,
                    line = string.rep("x", 10),
                }),
                38
            )

            expect.equal(
                layout.metadata_budget({
                    window_width = 100,
                    textoff = 4,
                    line = string.rep("x", 90),
                }),
                3
            )
        end
    ),

    testing.test(
        "metadata_budget_uses_display_width_for_unicode",
        function()
            expect.equal(
                vim.fn.strdisplaywidth("éééé"),
                4
            )

            expect.equal(
                layout.metadata_budget({
                    window_width = 20,
                    textoff = 0,
                    line = "éééé",
                    gap = 2,
                    cap_fraction = 1,
                }),
                14
            )
        end
    ),

    testing.test(
        "fit_drops_stats_before_permissions_and_reports_overflow",
        function()
            local permission =
                " rwxr-xr-x 0755"
            local first =
                ".swift: 50% "
            local marker =
                "+2 "

            local fitted =
                layout.fit(
                    {
                        {
                            text = first,
                            highlight = "Swift",
                            priority = layout.priority.stats,
                            group = "stats",
                        },
                        {
                            text = ".lua: 30% ",
                            highlight = "Lua",
                            priority = layout.priority.stats,
                            group = "stats",
                        },
                        {
                            text = ".md: 20% ",
                            highlight = "Markdown",
                            priority = layout.priority.stats,
                            group = "stats",
                        },
                        {
                            text = permission,
                            highlight = "ChmodColor",
                            priority = layout.priority.permission,
                        },
                    },
                    width(first)
                        + width(marker)
                        + width(permission)
                )

            expect.equal(
                rendered_text(fitted),
                first
                    .. marker
                    .. permission
            )
        end
    ),

    testing.test(
        "fit_preserves_path_when_no_metadata_space_remains",
        function()
            expect.equal(
                #layout.fit(
                    {
                        {
                            text = ".swift: 100% ",
                            highlight = "Swift",
                            priority = layout.priority.stats,
                            group = "stats",
                        },
                    },
                    0
                ),
                0
            )
        end
    ),

    testing.test(
        "stats_sort_by_percentage_then_extension",
        function(context)
            local fixture =
                context:fixture({
                    directories = {
                        "mixed",
                    },
                    files = {
                        ["mixed/a.swift"] = "",
                        ["mixed/b.swift"] = "",
                        ["mixed/a.lua"] = "",
                        ["mixed/a.md"] = "",
                    },
                })

            local chunks =
                stats.get_filetype_virtualtext(
                    fixture:path("mixed")
                )

            expect.equal(
                chunks[1][1],
                ".swift: 50% "
            )
            expect.equal(
                chunks[2][1],
                ".lua: 25% "
            )
            expect.equal(
                chunks[3][1],
                ".md: 25% "
            )
        end
    ),

    testing.test(
        "stats_scan_exposes_full_directory_model",
        function(context)
            local fixture =
                context:fixture({
                    directories = {
                        "mixed",
                        "mixed/child",
                    },
                    files = {
                        ["mixed/a.swift"] = "",
                        ["mixed/b.swift"] = "",
                        ["mixed/a.lua"] = "",
                        ["mixed/notes"] = "",
                        ["mixed/ignored.tmp"] = "",
                    },
                })

            local model =
                assert(
                    stats.scan(
                        fixture:path("mixed")
                    )
                )

            expect.equal(model.files, 5)
            expect.equal(model.directories, 1)
            expect.equal(
                model.counted_files,
                3
            )
            expect.equal(
                model.types[1].ext,
                ".swift"
            )
            expect.equal(
                model.types[1].count,
                2
            )
            expect.equal(
                model.types[2].ext,
                ".lua"
            )
            expect.equal(
                model.entries[1].name,
                "a.lua"
            )
            expect.equal(
                model.entries[#model.entries].name,
                "notes"
            )
        end
    ),

    testing.test(
        "netrw_entry_resolution_handles_dot_and_parent",
        function(context)
            local fixture =
                context:fixture({
                    directories = {
                        "parent/current/child",
                    },
                })
            local current =
                fixture:path("parent/current")

            local dot, dot_type =
                path.resolve_entry(
                    current,
                    "."
                )
            local parent, parent_type =
                path.resolve_entry(
                    current,
                    ".."
                )
            local child, child_type =
                path.resolve_entry(
                    current,
                    "child/"
                )

            expect.equal(
                dot,
                vim.fs.normalize(current)
            )
            expect.equal(
                dot_type,
                "directory"
            )
            expect.equal(
                parent,
                vim.fs.normalize(
                    fixture:path("parent")
                )
            )
            expect.equal(
                parent_type,
                "directory"
            )
            expect.equal(
                child,
                vim.fs.normalize(
                    fixture:path(
                        "parent/current/child"
                    )
                )
            )
            expect.equal(
                child_type,
                "directory"
            )
        end
    ),

    testing.test(
        "inspector_lines_show_resolved_parent_and_full_tables",
        function(context)
            local fixture =
                context:fixture({
                    directories = {
                        "parent/current",
                    },
                    files = {
                        ["parent/a.swift"] = "",
                        ["parent/b.lua"] = "",
                    },
                })
            local model =
                assert(
                    stats.scan(
                        fixture:path("parent")
                    )
                )
            local lines =
                inspector.lines(
                    model,
                    "../"
                )
            local rendered =
                table.concat(lines, "\n")

            expect.truthy(
                rendered:find(
                    "Selected   ..",
                    1,
                    true
                )
            )
            expect.truthy(
                rendered:find(
                    "File types",
                    1,
                    true
                )
            )
            expect.truthy(
                rendered:find(
                    ".swift",
                    1,
                    true
                )
            )
            expect.truthy(
                rendered:find(
                    "Contents",
                    1,
                    true
                )
            )
            expect.truthy(
                rendered:find(
                    "a.swift",
                    1,
                    true
                )
            )
        end
    ),

    testing.test(
        "inspector_attaches_buffer_local_stats_key",
        function()
            local previous =
                vim.api.nvim_get_current_buf()
            local buf =
                vim.api.nvim_create_buf(
                    false,
                    true
                )

            local ok, err =
                pcall(function()
                    vim.api.nvim_set_current_buf(buf)
                    inspector.attach(buf)

                    local mapping =
                        vim.fn.maparg(
                            "<leader>fs",
                            "n",
                            false,
                            true
                        )

                    expect.truthy(
                        type(mapping) == "table"
                            and next(mapping) ~= nil
                    )
                    expect.equal(
                        mapping.buffer,
                        1
                    )
                end)

            if
                vim.api.nvim_buf_is_valid(
                    previous
                )
            then
                pcall(
                    vim.api.nvim_set_current_buf,
                    previous
                )
            end

            if
                vim.api.nvim_buf_is_valid(buf)
            then
                pcall(
                    vim.api.nvim_buf_delete,
                    buf,
                    {
                        force = true,
                    }
                )
            end

            if not ok then
                error(err, 0)
            end
        end
    ),
}, {
    title = "Filetype metadata layout",
})
