-- someOptimizer
-- someoptimizer

local testing = require("testing")
local expect = testing.expect
local parsing = require("utils.casecon-substitute-parse")
local preview_factory = require("utils.casecon-substitute-preview")

local function check(spec, needle, replacement, global, label)
    local parsed, err = parsing.parse(spec)
    expect.nil_value(err, label .. " parse")
    assert(parsed, label .. " result")
    expect.equal(parsed.needle, needle, label .. " needle")
    expect.equal(parsed.replacement, replacement, label .. " replacement")
    expect.equal(parsed.global, global, label .. " global")
end

return testing.suite("casecon_substitute", {
    testing.test("optional_trailing_delimiter", function()
        check("/optimizer/analyzer", "optimizer", "analyzer", false, "unterminated")
        check("/optimizer/analyzer/", "optimizer", "analyzer", false, "terminated")
        check("/optimizer/analyzer/g", "optimizer", "analyzer", true, "all")
        check("/optimizer/", "optimizer", "", false, "deletion")
        check("#optimizer#analyzer#g", "optimizer", "analyzer", true, "alternate")
    end),
    testing.test("literal_delimiters_and_backslashes", function()
        check("/a\\/b/x\\/y/g", "a/b", "x/y", true, "escaped slash")
        check("#a\\#b#x\\#y#", "a#b", "x#y", false, "escaped hash")
        check("/a.b/x.y/g", "a.b", "x.y", true, "literal dot")
        check("/a\\\\b/x/g", "a\\b", "x", true, "literal backslash")
    end),
    testing.test("rejects_malformed_expressions", function()
        expect.nil_value(parsing.parse("/optimizer"), "missing separator")
        expect.nil_value(parsing.parse("/optimizer/analyzer/c"), "unsupported flag")
        expect.nil_value(parsing.parse("/optimizer/analyzer/gg"), "duplicate g")
        expect.nil_value(parsing.parse("//analyzer/g"), "empty needle")
    end),
    testing.test("search_stage_and_global_matching", function()
        local partial = assert(parsing.parse("/opt", true), "partial search must parse")
        expect.equal(partial.stage, "search", "partial stage")
        expect.equal(partial.needle, "opt", "partial search")
        expect.equal(#parsing.matches("Optimizer optimizer", "optimizer", true), 2, "all")
        expect.equal(#parsing.matches("Optimizer optimizer", "optimizer", false), 1, "first")
        expect.equal(#parsing.matches("a.b aXb", "a.b", true), 1, "literal match")
    end),
    testing.test("bare_delimiter_opens_empty_preview", function()
        local projected = vim.api.nvim_create_buf(false, true)
        local preview = preview_factory({ bin = vim.v.progpath })
        local namespace = vim.api.nvim_create_namespace("casecon_empty_preview_test")

        local ok, err = pcall(function()
            for _, delimiter in ipairs({ "/", "#" }) do
                local result = preview({
                    args = delimiter, line1 = 1, line2 = 1,
                }, namespace, projected)

                expect.equal(result, 2, "split opens for bare delimiter")
                local lines = vim.api.nvim_buf_get_lines(projected, 0, -1, false)
                expect.equal(lines[1], "", "initial preview is blank")
            end
        end)

        vim.api.nvim_buf_delete(projected, { force = true })
        if not ok then error(err, 0) end
    end),
    testing.test("search_preview_opens_split_without_swift", function()
        local source = vim.api.nvim_create_buf(false, true)
        local projected = vim.api.nvim_create_buf(false, true)
        local previous = vim.api.nvim_get_current_buf()
        local original_system = vim.system

        local ok, err = pcall(function()
            vim.api.nvim_set_current_buf(source)
            vim.api.nvim_buf_set_lines(source, 0, -1, false, {
                "myOptimizer", "unrelated", "MY_OPTIMIZER",
            })

            rawset(vim, "system", function()
                error("Search preview must not invoke Swift")
            end)

            local preview = preview_factory({ bin = vim.v.progpath })
            local result = preview({
                args = "/optimizer", line1 = 1, line2 = 3,
            }, vim.api.nvim_create_namespace("casecon_search_preview_test"), projected)

            expect.equal(result, 2, "search preview opens split")

            local lines = vim.api.nvim_buf_get_lines(projected, 0, -1, false)
            expect.equal(lines[1], "1 | myOptimizer", "first search match")
            expect.equal(lines[2], "3 | MY_OPTIMIZER", "second search match")

            local unchanged = vim.api.nvim_buf_get_lines(source, 0, 1, false)
            expect.equal(unchanged[1], "myOptimizer", "search does not mutate source")
        end)

        rawset(vim, "system", original_system)
        vim.api.nvim_set_current_buf(previous)
        vim.api.nvim_buf_delete(source, { force = true })
        vim.api.nvim_buf_delete(projected, { force = true })
        if not ok then error(err, 0) end
    end),
    testing.test("bounded_preview_projects_only_matching_lines", function()
        local source = vim.api.nvim_create_buf(false, true)
        local projected = vim.api.nvim_create_buf(false, true)
        local previous = vim.api.nvim_get_current_buf()
        local system = vim.system
        local argv_seen
        local initial = { "myOptimizer", "unrelated", "MY_OPTIMIZER" }
        local ok, err = pcall(function()
            vim.api.nvim_set_current_buf(source)
            vim.api.nvim_buf_set_lines(source, 0, -1, false, initial)
            rawset(vim, "system", function(argv)
                argv_seen = argv
                return { wait = function()
                    return { code = 0, stdout = vim.json.encode({
                        ok = true, result = { "myTools", "MY_TOOLS" },
                    }) }
                end }
            end)
            local preview = preview_factory({ bin = vim.v.progpath })
            local outcome = preview({
                args = "/optimizer/tools/g", line1 = 1, line2 = 3,
            }, vim.api.nvim_create_namespace("casecon_preview_test"), projected)
            expect.equal(outcome, 2, "split preview enabled")
            expect.equal(argv_seen[#argv_seen - 2], "--", "passthrough separator")
            expect.equal(argv_seen[#argv_seen - 1], "myOptimizer", "first source")
            expect.equal(argv_seen[#argv_seen], "MY_OPTIMIZER", "second source")
            local active = vim.api.nvim_buf_get_lines(source, 0, -1, false)
            expect.equal(active[1], "myTools", "first line preview")
            expect.equal(active[2], "unrelated", "unmatched line preserved")
            expect.equal(active[3], "MY_TOOLS", "third line preview")
            local shown = vim.api.nvim_buf_get_lines(projected, 0, -1, false)
            expect.equal(shown[1], "1 | myTools", "first projected line")
            expect.equal(shown[2], "3 | MY_TOOLS", "third projected line")
        end)
        rawset(vim, "system", system)
        vim.api.nvim_set_current_buf(previous)
        vim.api.nvim_buf_delete(source, { force = true })
        vim.api.nvim_buf_delete(projected, { force = true })
        if not ok then error(err, 0) end
    end),
}, { title = "Casecon substitution" })
