local testing = require("testing")
local expect = testing.expect
local indentation = require("extensions.indentation")

local function with_buffer(lines, body)
    local previous_buf = vim.api.nvim_get_current_buf()
    local buf = vim.api.nvim_create_buf(false, true)

    local ok, err = pcall(function()
        vim.api.nvim_set_current_buf(buf)
        vim.api.nvim_buf_set_lines(
            buf,
            0,
            -1,
            false,
            lines
        )

        vim.bo[buf].shiftwidth = 4
        vim.bo[buf].tabstop = 4

        vim.fn.winrestview({
            topline = 1,
            leftcol = 0,
        })

        body(buf)
    end)

    pcall(indentation.set, "none")

    if vim.api.nvim_buf_is_valid(previous_buf) then
        pcall(
            vim.api.nvim_set_current_buf,
            previous_buf
        )
    end

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
        error(err, 0)
    end
end

local function marks(buf)
    local ns = vim.api.nvim_get_namespaces().indentation

    return vim.api.nvim_buf_get_extmarks(
        buf,
        ns,
        0,
        -1,
        {
            details = true,
        }
    )
end

local function rendered(mark)
    return mark[4].virt_text[1][1]
end

return testing.suite("indentation", {
    testing.test(
        "renders_expected_patterns_without_accumulating_marks",
        function()
            with_buffer({
                "root",
                "    one",
                "        two",
            }, function(buf)
                indentation.set("countdotsend")

                local counted = marks(buf)

                expect.equal(#counted, 2)
                expect.equal(counted[1][2], 1)
                expect.equal(
                    rendered(counted[1]),
                    "0..;"
                )
                expect.equal(counted[2][2], 2)
                expect.equal(
                    rendered(counted[2]),
                    "0..;1..;"
                )

                indentation.set("dotted")

                local dotted = marks(buf)

                expect.equal(
                    #dotted,
                    2,
                    "mode replacement clears old extmarks"
                )
                expect.equal(
                    rendered(dotted[1]),
                    "····"
                )
                expect.equal(
                    rendered(dotted[2]),
                    "········"
                )

                indentation.set("none")

                expect.equal(
                    #marks(buf),
                    0,
                    "none clears indentation overlays"
                )
            end)
        end
    ),

    testing.test(
        "uses_tabstop_when_shiftwidth_is_zero",
        function()
            with_buffer({
                "root",
                "  one",
            }, function(buf)
                vim.bo[buf].shiftwidth = 0
                vim.bo[buf].tabstop = 2

                indentation.set("countdots")

                local current = marks(buf)

                expect.equal(#current, 1)
                expect.equal(
                    rendered(current[1]),
                    "0."
                )
            end)
        end
    ),
}, {
    title = "Indentation",
})
