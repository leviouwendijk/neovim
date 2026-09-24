local testing = require("testing")
local expect = testing.expect

local imports = require("boot.imports")
local selections = require("boot.selections")

local function import_index()
    local result = {}

    for category, entries in pairs(imports) do
        result[category] = {}

        for _, entry in ipairs(entries) do
            result[category][entry[1]] = true
        end
    end

    return result
end

return testing.suite("boot", {
    testing.test(
        "selection_profiles_match_import_inventory",
        function()
            local index = import_index()

            for profile_name, profile in pairs(selections) do
                for category, enabled in pairs(profile) do
                    expect.not_nil(
                        index[category],
                        profile_name
                            .. " has unknown category "
                            .. tostring(category)
                    )

                    for id in pairs(enabled) do
                        expect.truthy(
                            index[category][id],
                            profile_name
                                .. " selects unknown import "
                                .. category
                                .. "/"
                                .. tostring(id)
                        )
                    end
                end

                for category, ids in pairs(index) do
                    expect.not_nil(
                        profile[category],
                        profile_name
                            .. " is missing category "
                            .. category
                    )

                    for id in pairs(ids) do
                        expect.not_nil(
                            profile[category][id],
                            profile_name
                                .. " does not declare "
                                .. category
                                .. "/"
                                .. id
                        )
                    end
                end
            end
        end
    ),

    testing.test(
        "derived_profiles_do_not_mutate_base",
        function()
            expect.truthy(
                selections.base.extensions.filemover,
                "base keeps filemover enabled"
            )
            expect.falsy(
                selections.minimal.extensions.filemover,
                "minimal overrides filemover"
            )

            expect.truthy(
                selections.base.packages.packer,
                "base keeps packer enabled"
            )
            expect.falsy(
                selections.secure.packages.packer,
                "secure overrides packer"
            )

            expect.not_equal(
                selections.base,
                selections.minimal,
                "minimal has independent root table"
            )
            expect.not_equal(
                selections.base.extensions,
                selections.minimal.extensions,
                "minimal has independent nested extension table"
            )
            expect.not_equal(
                selections.base.packages,
                selections.secure.packages,
                "secure has independent nested package table"
            )
        end
    ),

    testing.test(
        "secure_profile_disables_sensitive_extensions",
        function()
            local disabled = {
                "highlight_yank",
                "uuid",
                "ssh_clipboard",
                "stf",
                "file_rename",
                "filemover",
                "copier_api",
                "mess",
            }

            for _, id in ipairs(disabled) do
                expect.falsy(
                    selections.secure.extensions[id],
                    "secure disables extensions/" .. id
                )
            end

            expect.falsy(
                selections.secure.packages.packer,
                "secure disables package loading"
            )
        end
    ),
}, {
    title = "Boot",
})
