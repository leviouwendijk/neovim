local testing = require("testing")
local expect = testing.expect
local output = require("extensions.output")

local function close_split()
    local status = output.status().split

    if
        status.win
        and vim.api.nvim_win_is_valid(
            status.win
        )
    then
        pcall(
            vim.api.nvim_win_close,
            status.win,
            true
        )
    end

    if
        status.buf
        and vim.api.nvim_buf_is_valid(
            status.buf
        )
    then
        pcall(
            vim.api.nvim_buf_delete,
            status.buf,
            {
                force = true,
            }
        )
    end
end

local function with_split(body)
    local previous_mode =
        output.status().default_mode

    close_split()
    output.setup({
        default_mode = "split",
    })

    local ok, result =
        pcall(body)

    close_split()
    output.setup({
        default_mode = previous_mode,
    })

    if not ok then
        error(result, 0)
    end

    return result
end

local function contains(lines, expected)
    for _, line in ipairs(lines) do
        if line == expected then
            return true
        end
    end

    return false
end

return testing.suite(
    "output",
    {
        testing.test(
            "split_toggle_reuses_output_buffer",
            function()
                with_split(
                    function()
                        output.toggle("split")

                        local opened =
                            output.status()

                        expect.truthy(
                            opened.split.buf_valid,
                            "split buffer is valid"
                        )
                        expect.truthy(
                            opened.split.win ~= nil,
                            "split window is open"
                        )

                        local buf =
                            opened.split.buf

                        output.toggle("split")

                        local hidden =
                            output.status()

                        expect.truthy(
                            hidden.split.buf_valid,
                            "hidden split keeps its buffer"
                        )
                        expect.nil_value(
                            hidden.split.win
                        )

                        output.toggle("split")

                        local reopened =
                            output.status()

                        expect.equal(
                            reopened.split.buf,
                            buf
                        )
                        expect.truthy(
                            reopened.split.win ~= nil,
                            "split window reopens"
                        )
                    end
                )
            end
        ),

        testing.test(
            "split_runner_writes_command_output",
            function()
                with_split(
                    function()
                        output.run_file_in_split(
                            "/bin/echo",
                            "output-regression",
                            0
                        )

                        local status =
                            output.status()

                        expect.truthy(
                            status.split.buf_valid
                        )

                        local lines =
                            vim.api.nvim_buf_get_lines(
                                status.split.buf,
                                0,
                                -1,
                                false
                            )

                        expect.truthy(
                            contains(
                                lines,
                                "output-regression"
                            ),
                            "captured command output is written after the timestamp header"
                        )
                    end
                )
            end
        ),
    },
    {
        title = "Output",
    }
)
