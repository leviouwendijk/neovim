local testing = require("testing")
local expect = testing.expect
local core = require("extensions.filemover.core")
local netrw = require("extensions.filemover.netrw")
local uv = vim.uv or vim.loop

local root = vim.g.nvim_config_test_root
local fixture_spec = dofile(
    vim.fs.joinpath(root, "tests", "fixtures", "filemover.lua")
)

local function fixture(context)
    return context:fixture(fixture_spec)
end

local function contains_path(paths, expected)
    for _, path in ipairs(paths) do
        if core.normalize_path(path) == expected then
            return true
        end
    end

    return false
end

return testing.suite("filemover", {
    testing.test("move_file", function(context)
        local f = fixture(context)
        local source = f:path("source/file.txt")
        local target = f:path("target")

        local result = core.move_entry(
            {
                path = core.normalize_path(source),
                kind = "file",
            },
            core.normalize_path(target)
        )

        expect.equal(result.status, "moved")
        expect.not_exists(source)
        expect.exists(f:path("target/file.txt"))
        expect.file_contents(
            f:path("target/file.txt"),
            "file\n"
        )
    end),

    testing.test("move_deep_directory", function(context)
        local f = fixture(context)
        local source = f:path("source/directory") .. "/"
        local target = f:path("target")

        local compacted = core.compact_sources({ source })
        expect.equal(#compacted, 1)
        expect.equal(compacted[1].kind, "directory")

        local result = core.move_entry(
            compacted[1],
            core.normalize_path(target)
        )

        expect.equal(result.status, "moved")
        expect.not_exists(f:path("source/directory"))
        expect.file_contents(
            f:path("target/directory/child.txt"),
            "child\n"
        )
        expect.file_contents(
            f:path("target/directory/nested/deep.txt"),
            "deep\n"
        )
    end),

    testing.test("same_path_is_noop", function(context)
        local f = fixture(context)
        local source = core.normalize_path(
            f:path("source/file.txt")
        )
        local parent = core.normalize_path(
            f:path("source")
        )

        local result = core.move_entry(
            {
                path = source,
                kind = "file",
            },
            parent
        )

        expect.equal(result.status, "noop")
        expect.exists(source)
    end),

    testing.test("existing_destination_is_rejected", function(context)
        local f = fixture(context)
        local source = core.normalize_path(
            f:path("source/directory")
        )
        local target = core.normalize_path(
            f:path("collision")
        )

        local result = core.move_entry(
            {
                path = source,
                kind = "directory",
            },
            target
        )

        expect.equal(result.status, "error")
        expect.equal(
            result.message,
            "Destination already exists"
        )
        expect.exists(source)
        expect.exists(f:path("collision/directory/existing.txt"))
    end),

    testing.test("descendant_target_is_rejected", function(context)
        local f = fixture(context)
        local source = core.normalize_path(
            f:path("source/directory")
        )
        local target = core.normalize_path(
            f:path("source/directory/nested")
        )

        local result = core.move_entry(
            {
                path = source,
                kind = "directory",
            },
            target
        )

        expect.equal(result.status, "error")
        expect.exists(source)
        expect.exists(f:path("source/directory/nested/deep.txt"))
    end),

    testing.test("overlapping_marks_are_compacted", function(context)
        local f = fixture(context)

        local directory = f:path("source/directory") .. "/"
        local child = f:path("source/directory/child.txt")
        local deep = f:path("source/directory/nested/deep.txt")

        local compacted = core.compact_sources({
            child,
            directory,
            deep,
        })

        expect.equal(#compacted, 1)
        expect.equal(
            compacted[1].path,
            core.normalize_path(directory)
        )
        expect.equal(compacted[1].kind, "directory")
    end),

    testing.test("descendant_targets_are_filtered", function(context)
        local f = fixture(context)
        local source = core.compact_sources({
            f:path("source/directory"),
        })

        local cwd = core.normalize_path(f:path("source"))
        local directories = core.target_directories(cwd, source)

        expect.truthy(contains_path(directories, cwd))

        for _, directory in ipairs(directories) do
            expect.falsy(
                core.path_is_within(
                    core.normalize_path(directory),
                    source[1].path
                ),
                "selected directory subtree must not be offered as a target"
            )
        end
    end),

    testing.test("symlink_moves_as_entry", function(context)
        local f = fixture(context)
        local source = core.normalize_path(
            f:path("source/link-to-file")
        )
        local target = core.normalize_path(
            f:path("target")
        )

        local source_stat = expect.not_nil(
            uv.fs_lstat(source),
            "symlink lstat"
        )
        expect.equal(source_stat.type, "link")

        local result = core.move_entry(
            {
                path = source,
                kind = "link",
            },
            target
        )

        expect.equal(result.status, "moved")
        expect.not_exists(source)

        local moved = f:path("target/link-to-file")
        local moved_stat = expect.not_nil(
            uv.fs_lstat(moved),
            "moved symlink lstat"
        )

        expect.equal(moved_stat.type, "link")
        expect.file_contents(
            f:path("source/file.txt"),
            "file\n"
        )
    end),

    testing.test("netrw_mf_marks_directory", function(context)
        local f = fixture(context)
        local source_dir = core.normalize_path(
            f:path("source")
        )
        local expected = core.normalize_path(
            f:path("source/directory")
        )

        vim.cmd(
            "silent Explore " .. vim.fn.fnameescape(source_dir)
        )

        local opened = vim.wait(500, function()
            return vim.bo.filetype == "netrw"
        end, 10)

        expect.truthy(opened, "Netrw opened")

        local mapping = vim.fn.maparg(
            "mf",
            "n",
            false,
            true
        )

        expect.truthy(
            type(mapping) == "table" and next(mapping) ~= nil,
            "Netrw mf mapping exists"
        )
        expect.truthy(
            type(mapping.rhs) == "string"
                and mapping.rhs:find(
                    "NetrwMarkFile",
                    1,
                    true
                ) ~= nil,
            "mf mapping targets NetrwMarkFile"
        )

        local row = nil
        for index, line in ipairs(
            vim.api.nvim_buf_get_lines(0, 0, -1, false)
        ) do
            if line:find("directory", 1, true) then
                row = index
                break
            end
        end

        expect.not_nil(row, "directory row exists in Netrw")

        vim.api.nvim_win_set_cursor(0, { row, 0 })

        local selected = vim.fn["netrw#Call"]("NetrwGetWord")

        expect.truthy(
            type(selected) == "string" and selected ~= "",
            "Netrw resolves an entry under the cursor"
        )
        expect.equal(
            selected:gsub("/+$", ""),
            "directory",
            "cursor resolves to fixture directory"
        )

        local before, before_error = netrw.marked_paths()
        expect.nil_value(before_error, "read initial Netrw marks")
        expect.equal(#before, 0, "Netrw starts with no marks")

        local marked_ok, marked_result = pcall(
            vim.fn["netrw#Call"],
            "NetrwMarkFile",
            1,
            selected
        )

        expect.truthy(
            marked_ok,
            "Netrw mark action executes: "
                .. tostring(marked_result)
        )

        local marked, mark_error = netrw.marked_paths()

        expect.nil_value(mark_error, "read Netrw marks")
        if not marked then
            error(
                "failed to read Netrw marks: "
                    .. tostring(mark_error)
            )
        end
        expect.equal(#marked, 1, "mf action created exactly one mark")

        local marked_path = marked[1]
        if not marked_path then
            error(
                "mf action did not produce a marked path"
            )
        end
        local normalized_mark = core.normalize_path(marked_path)

        expect.equal(
            normalized_mark,
            expected,
            "marked directory path"
        )

        local compacted = core.compact_sources(marked)
        expect.equal(#compacted, 1, "one compacted Netrw mark")
        expect.equal(compacted[1].path, expected)
        expect.equal(compacted[1].kind, "directory")

        vim.cmd("silent enew")
    end),
}, {
    title = "Filemover",
})
