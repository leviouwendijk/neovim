local testing = require("testing")
local expect = testing.expect
local nicetstamp =
    require("extensions.nicetstamp")

local function with_buffer(body)
    local buf =
        vim.api.nvim_create_buf(
            false,
            true
        )

    local old_style =
        nicetstamp.config.style
    local old_blank =
        nicetstamp.config.blank_after_header

    nicetstamp.config.style =
        "minimal"
    nicetstamp.config.blank_after_header =
        true

    local ok, result =
        pcall(body, buf)

    nicetstamp.detach_autorefresh(buf)
    nicetstamp.config.style =
        old_style
    nicetstamp.config.blank_after_header =
        old_blank

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

local function expect_lines(
    actual,
    expected,
    label
)
    expect.equal(
        table.concat(actual, "\n"),
        table.concat(expected, "\n"),
        label
    )
end

return testing.suite(
    "nicetstamp",
    {
        testing.test(
            "prepend_unknown_time_adds_blank_separator",
            function()
                with_buffer(
                    function(buf)
                        expect_lines(
                            nicetstamp.prepend_header(
                                {
                                    "body",
                                },
                                nil,
                                {
                                    buf = buf,
                                }
                            ),
                            {
                                "output (time unknown)",
                                "",
                                "body",
                            },
                            "unknown timestamp header"
                        )

                        expect.equal(
                            vim.b[buf].nicetstamp_hdr_n,
                            1
                        )
                    end
                )
            end
        ),

        testing.test(
            "set_get_and_refresh_track_buffer_timestamp",
            function()
                with_buffer(
                    function(buf)
                        local ts = os.time()

                        nicetstamp.set(
                            buf,
                            ts
                        )

                        expect.equal(
                            nicetstamp.get(buf),
                            ts
                        )
                        expect.equal(
                            vim.b[buf].nicetstamp_hdr_n,
                            1
                        )

                        local first =
                            vim.api.nvim_buf_get_lines(
                                buf,
                                0,
                                1,
                                false
                            )[1]

                        expect.truthy(
                            first:find(
                                "output from ",
                                1,
                                true
                            ) == 1,
                            "refresh writes the timestamp header"
                        )
                    end
                )
            end
        ),

        testing.test(
            "autorefresh_timer_attaches_and_detaches",
            function()
                with_buffer(
                    function(buf)
                        nicetstamp.attach_autorefresh(
                            buf,
                            3600
                        )

                        expect.truthy(
                            nicetstamp._timers[buf]
                                ~= nil,
                            "timer is tracked"
                        )

                        nicetstamp.detach_autorefresh(
                            buf
                        )

                        expect.nil_value(
                            nicetstamp._timers[buf]
                        )
                    end
                )
            end
        ),
    },
    {
        title = "Nicetstamp",
    }
)
