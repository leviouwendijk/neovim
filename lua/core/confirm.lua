local Confirmation = {}

function Confirmation.confirm_action(prompt)
    print(prompt .. " (y/n)")
    local response = vim.fn.nr2char(vim.fn.getchar())
    return response == 'y' or response == 'Y'
end

-- from after/plugin/deletos.lua:
function Confirmation.deleteThisFileButAskMe()
    local choice = vim.fn.confirm("Deleting this file. Are you sure?", "&Yes\n&No", 2)
    if choice == 1 then
        vim.fn.delete(vim.fn.expand('%'))
        vim.api.nvim_command('bdelete!')
    end
end

return Confirmation
