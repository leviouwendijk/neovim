local function merge(base, updates)
    local result = {}

    -- Copy everything from base first
    for k, v in pairs(base) do
        if type(v) == "table" then
            result[k] = merge(v, updates[k] or {}) -- Ensure base is fully copied
        else
            result[k] = v
        end
    end

    -- Apply updates on top
    for k, v in pairs(updates) do
        if type(v) == "table" and type(result[k]) == "table" then
            result[k] = merge(result[k], v)
        else
            result[k] = v
        end
    end

    return result
end

local Selections = {
    base = {
        config = {
            funcs = true,
            set = true,
            remap = true,
            defaults = true,
            path = true,
        },

        core = {
            trash = true,
            log = true,
            confirm = true,
            filetype = true,
            treesitter = true,
        },

        customizations = {
            writing = true,
            statusline = true,
        },

        extensions = {
            highlight_yank = true,
            uuid = true,
            ssh_clipboard = true,
            stf = true,
            file_rename = true,
            filemover = true,
            copier_api = false,
            -- copier_api = true,
            mess = false, -- true causes issues in POSIX shells (diskmapper)
            ec_id = true,
            ec_template = true,
            reusable_library = false,
            last_file = false,
            weasyprint = true,
            indentation = true,
            output = true,
            nicetstamp = true,
            niceheader = true,
            shell = true,
            bedrocks = true,
            bedrocks_depth = true,
        },

        packages = {
            packer = true
        },

        utils = {
            json = true,
            branch = true,
            format = true,
            chmod = true,
            shebang = true,
            vat = true,
            word_count = true,
            copy_messages = true,
            swift_init = true,
            appearance = true,
            notify = true,
            enter = true,
            align = true,
            timestamp = true,
            project_progress = true,
            casecon = true,
            dependencies = true,
        }
    },
}

Selections.full = merge(Selections.base, {
    extensions = {
        -- copier_api = true,
    },
})

Selections.minimal = merge(Selections.base, {
    extensions = {
        highlight_yank = false,
        uuid = false,
        ssh_clipboard = false,
        stf = false,
        file_rename = false,
        filemover = false,
        copier_api = false,
        mess = false,
        reusable_library = false,
        last_file = false,
    },
})

Selections.light = merge(Selections.base, {
    extensions = {
        highlight_yank = true,
        uuid = true,
        ssh_clipboard = true,
        stf = true,
        file_rename = true,
        filemover = true,
        copier_api = false,
        mess = false,
    },
})

Selections.secure = merge(Selections.base, {
    extensions = {
        highlight_yank = false,
        uuid = false,
        ssh_clipboard = false,
        stf = false,
        file_rename = false,
        filemover = false,
        copier_api = false,
        mess = false,
    },

    packages = {
        packer = false
    }
})

return Selections
