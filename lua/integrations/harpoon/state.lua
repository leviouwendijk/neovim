return function(harpoon)
    -- v2-compatible 'mark' shim
    local mark = {}

    local function _harpoon_menu_is_open()
        for _, win in ipairs(vim.api.nvim_list_wins()) do
            local buf = vim.api.nvim_win_get_buf(win)
            local ft = vim.api.nvim_get_option_value("filetype", { buf = buf })
            if ft == "harpoon" then return true end
        end
        return false
    end

    local function _harpoon_menu_refresh()
        local list = harpoon:list()
        harpoon.ui:toggle_quick_menu(list)
        harpoon.ui:toggle_quick_menu(list)
    end

    -- v2 add with notify + live refresh; works for current buffer or explicit path
    function mark.add_file(path)
        local list = harpoon:list()
        local p = path or vim.api.nvim_buf_get_name(0)
        if p == "" then
            vim.notify("Harpoon: no file to add (empty buffer)", vim.log.levels.WARN, { title = "Harpoon" })
            return
        end

        -- already in list? tell slot & refresh if menu is open
        for i, it in ipairs(list.items) do
            if it.value == p then
                vim.notify(("Harpoon: already in list (slot %d)"):format(i), vim.log.levels.INFO, { title = "Harpoon" })
                if _harpoon_menu_is_open() then _harpoon_menu_refresh() end
                return
            end
        end

        if path then
            list:add({ value = p })    -- explicit path must be wrapped
        else
            list:add()                 -- current buffer
        end

        -- find slot + notify
        local idx
        for i, it in ipairs(list.items) do
            if it.value == p then idx = i; break end
        end
        local pretty = vim.fn.fnamemodify(p, ":.")
        vim.notify(("Harpoon: added → %s%s"):format(idx and (idx .. ". ") or "", pretty),
            vim.log.levels.INFO, { title = "Harpoon" })

        if _harpoon_menu_is_open() then _harpoon_menu_refresh() end
    end

    function mark.rm_file(path)
        local list = harpoon:list()
        if path and #path > 0 then
            -- remove by path (find index first)
            for i, it in ipairs(list.items) do
                if it.value == path then
                    list:remove_at(i)
                    return
                end
            end
        else
            -- remove current buffer
            list:remove()
        end
    end

    function mark.clear_all()
        harpoon:list():clear()
    end

    function mark.set_current_at(i)
        harpoon:list():replace_at(i)
    end

    function mark.get_marked_file_list()
        local items = harpoon:list().items
        local out = {}
        for i, it in ipairs(items) do out[i] = it.value end
        return out
    end

    function mark.get_current_index()
        local curr = vim.api.nvim_buf_get_name(0)
        if curr == "" then return nil end
        for i, it in ipairs(harpoon:list().items) do
            if it.value == curr then return i end
        end
        return nil
    end

    -- v2-compatible 'ui' shim
    local ui = {}

    function ui.toggle_quick_menu()
        harpoon.ui:toggle_quick_menu(harpoon:list())
    end

    function ui.nav_file(i)
        harpoon:list():select(i)
    end

    function ui.nav_next()
        harpoon:list():next()
    end

    function ui.nav_prev()
        harpoon:list():prev()
    end

    return {
        mark = mark,
        ui = ui,
    }
end
