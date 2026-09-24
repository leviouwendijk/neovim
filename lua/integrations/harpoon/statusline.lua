return function(mark)
    -----------------------------------------------------------------------
    -- Statusline helper to show Harpoon position for the current buffer:
    -- Returns "H:idx/len" if current buffer is marked, else "".
    -- Use in lualine as: { function() return _G.HarpoonV1Status() end }
    -----------------------------------------------------------------------
    function _G.HarpoonStatus()
        local curr = vim.api.nvim_buf_get_name(0)
        if curr == "" then return "" end

        -- Prefer Harpoon v1's helper if available; fall back to manual scan.
        local ok_idx, idx = pcall(mark.get_current_index)
        if ok_idx and type(idx) == "number" then
            local list = mark.get_marked_file_list() or {}
            if idx >= 1 and idx <= #list then
                return ("H:%d/%d"):format(idx, #list)
            end
        else
            local list = mark.get_marked_file_list() or {}
            for i, p in ipairs(list) do
                if p == curr then
                    return ("H:%d/%d"):format(i, #list)
                end
            end
        end
        return ""
    end

    -----------------------------------------------------------------------
    -- Extra niceties inside the Harpoon quick menu buffer:
    --  • 'q' closes the menu buffer quickly.
    --  • (keeps your existing 'dd' to delete-under-cursor behavior)
    -----------------------------------------------------------------------
    vim.api.nvim_create_autocmd("FileType", {
        pattern = "harpoon",
        callback = function(ev)
            vim.keymap.set("n", "q", "<cmd>bd!<CR>", { buffer = ev.buf, silent = true, desc = "Close Harpoon menu" })
        end,
    })
end
