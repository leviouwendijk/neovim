local testing = require("testing")
local expect = testing.expect
local core = require("core.confirm")
local interface = require("interface.confirm")

local function with_presenter(
    presenter,
    body
)
    local previous =
        core.set_presenter(
            presenter
        )

    local ok, result =
        pcall(body)

    core.set_presenter(previous)

    if not ok then
        error(result, 0)
    end

    return result
end

return testing.suite(
    "confirm",
    {
        testing.test(
            "core_delegates_to_registered_presenter",
            function()
                local captured = nil

                with_presenter(
                    function(prompt, options)
                        captured = {
                            prompt = prompt,
                            title = options.title,
                        }
                        return true
                    end,
                    function()
                        expect.truthy(
                            core.confirm_action(
                                "Proceed?",
                                {
                                    title = "Action",
                                }
                            ),
                            "registered presenter result"
                        )
                    end
                )

                expect.not_nil(
                    captured,
                    "presenter was called"
                )
                assert(captured ~= nil)
                expect.equal(
                    captured.prompt,
                    "Proceed?"
                )
                expect.equal(
                    captured.title,
                    "Action"
                )
            end
        ),

        testing.test(
            "native_layout_exposes_prompt_and_actions",
            function()
                local layout =
                    interface.layout(
                        "Deleting this file. Are you sure?",
                        {
                            title = "Delete file",
                            kind = "danger",
                            accept_label = "Delete",
                            cancel_label = "Cancel",
                        },
                        80,
                        24
                    )

                local rendered =
                    table.concat(
                        layout.lines,
                        "\n"
                    )

                expect.equal(
                    layout.title,
                    "Delete file"
                )
                expect.equal(
                    layout.kind,
                    "danger"
                )
                expect.truthy(
                    layout.width < 80,
                    "confirmation float is bounded"
                )
                expect.truthy(
                    rendered:find(
                        "Deleting this file.",
                        1,
                        true
                    ) ~= nil,
                    "prompt is rendered"
                )
                expect.truthy(
                    rendered:find(
                        "y  Delete",
                        1,
                        true
                    ) ~= nil,
                    "accept action is rendered"
                )
                expect.truthy(
                    rendered:find(
                        "n / Esc  Cancel",
                        1,
                        true
                    ) ~= nil,
                    "cancel action is rendered"
                )
            end
        ),
    },
    {
        title = "Confirm",
    }
)
