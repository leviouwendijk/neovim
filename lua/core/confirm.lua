local Confirmation = {}

local presenter = nil

local function fallback_confirm(prompt, options)
    options = options or {}

    local accept_label =
        options.accept_label or "Yes"
    local cancel_label =
        options.cancel_label or "No"
    local default_choice =
        options.default == true and 1 or 2

    return vim.fn.confirm(
        prompt,
        "&" .. accept_label
            .. "\n&" .. cancel_label,
        default_choice
    ) == 1
end

function Confirmation.set_presenter(next_presenter)
    if
        next_presenter ~= nil
        and type(next_presenter) ~= "function"
    then
        error(
            "confirmation presenter must be a function or nil"
        )
    end

    local previous = presenter
    presenter = next_presenter
    return previous
end

function Confirmation.confirm_action(prompt, options)
    options = options or {}

    if presenter then
        local ok, result =
            pcall(
                presenter,
                prompt,
                options
            )

        if ok and type(result) == "boolean" then
            return result
        end
    end

    return fallback_confirm(
        prompt,
        options
    )
end

-- from after/plugin/deletos.lua:
function Confirmation.deleteThisFileButAskMe()
    local confirmed =
        Confirmation.confirm_action(
            "Deleting this file. Are you sure?",
            {
                title = "Delete file",
                kind = "danger",
                accept_label = "Delete",
                cancel_label = "Cancel",
                default = false,
            }
        )

    if confirmed then
        vim.fn.delete(vim.fn.expand('%'))
        vim.api.nvim_command('bdelete!')
    end
end

return Confirmation
