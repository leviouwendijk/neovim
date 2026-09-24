local uv = vim.loop

local use_gray_theme = false  -- Set to true to use grayscale instead of colored
local opacity = 0.75           -- Set opacity for colors (simulated by adjusting color intensity)
local ignore_extensions = { -- List of extensions to ignore
    ".resolved",
    ".tmp"
    }
local max_width = 50  -- Maximum width for the displayed file type percentages
local decimal_places = 0  -- Number of decimal places to round percentages to

-- Function to round a number to a specific number of decimal places
local function round(num, num_decimal_places)
    local mult = 10^(num_decimal_places or 0)
    return math.floor(num * mult + 0.5) / mult
end

-- Function to adjust opacity of a hex color (simulate opacity by reducing intensity)
local function adjust_opacity(color_hex, opacity_factor)
    local r = tonumber(color_hex:sub(2, 3), 16)
    local g = tonumber(color_hex:sub(4, 5), 16)
    local b = tonumber(color_hex:sub(6, 7), 16)

    -- Adjust each channel by the opacity factor
    r = math.floor(r * opacity_factor)
    g = math.floor(g * opacity_factor)
    b = math.floor(b * opacity_factor)

    -- Convert back to hex and return the modified color
    return string.format("#%02x%02x%02x", r, g, b)
end

-- Grayscale colors (used when use_gray_theme is true)
local gray_color_map = {
    [".lua"] = "#808080",
    [".py"] = "#888888",
    [".js"] = "#909090",
    [".html"] = "#989898",
    [".css"] = "#a0a0a0",
    [".json"] = "#a8a8a8",
    [".yaml"] = "#b0b0b0",
    [".c"] = "#b8b8b8",
    [".swift"] = "#c0c0c0",
    [".md"] = "#c8c8c8",
    [".pdf"] = "#b0b0b0",   -- Gray for PDF files
    [".sh"] = "#909090",    -- Gray for Shell scripts
    [".txt"] = "#a8a8a8",   -- Gray for Text files
}

-- Default color for unspecified extensions in gray theme
local default_gray_color = "#d0d0d0"

-- Dictionary to control appearance by file extension (RGB colors)
local ext_color_map = {
    [".lua"] = "#A3BE8C",   -- Green for Lua files
    [".py"] = "#88C0D0",    -- Blue for Python files
    [".js"] = "#EBCB8B",    -- Yellow for JavaScript files
    [".html"] = "#BF616A",  -- Red for HTML files
    [".css"] = "#8FBCBB",   -- Cyan for CSS files
    [".json"] = "#D08770",  -- Orange for JSON files
    [".yaml"] = "#B48EAD",  -- Purple for YAML files
    [".c"] = "#5E81AC",     -- Blue for C files
    [".swift"] = "#FFAC45", -- Swift files with a custom orange
    [".md"] = "#A3BE8C",    -- Markdown files green
    [".pdf"] = "#D08770",   -- Orange for PDF files
    [".sh"] = "#A3BE8C",    -- Green for Shell scripts
    [".txt"] = "#ECEFF4",   -- Light color for Text files
}

-- Default color for unspecified extensions
local default_color = "#ECEFF4"

-- Helper function to check if an extension is in the ignore list
local function is_ignored_extension(ext)
    for _, ignore_ext in ipairs(ignore_extensions) do
        if ext == ignore_ext then
            return true
        end
    end
    return false
end

-- Helper function to create a highlight group from a hex color
local function create_highlight_group(ext, color)
    local group_name = "FileTypeColor_" .. ext:gsub("%W", "") -- sanitize extension to use in group name
    vim.api.nvim_set_hl(0, group_name, { fg = color })
    return group_name
end

-- Function to count files by extension in a given directory using vim.loop
local function scan(directory)
    local file_counts = {}
    local total_files = 0
    local file_count = 0
    local directory_count = 0
    local entries = {}
    local handle, scan_error =
        uv.fs_scandir(directory)

    if not handle then
        return nil, scan_error
    end

    while true do
        local name, file_type =
            uv.fs_scandir_next(handle)
        if not name then break end

        local file_ext = nil

        if file_type == "file" then
            file_count = file_count + 1
            file_ext = name:match("^.+(%..+)$") -- extract file extension

            if
                file_ext
                and not is_ignored_extension(file_ext)
            then
                file_counts[file_ext] =
                    (file_counts[file_ext] or 0) + 1
                total_files = total_files + 1
            end
        elseif file_type == "directory" then
            directory_count =
                directory_count + 1
        end

        table.insert(entries, {
            name = name,
            kind = file_type or "unknown",
            extension = file_ext,
        })
    end

    table.sort(entries, function(lhs, rhs)
        return lhs.name < rhs.name
    end)

    return {
        directory = vim.fs.normalize(directory),
        files = file_count,
        directories = directory_count,
        counted_files = total_files,
        file_counts = file_counts,
        entries = entries,
    }
end

-- Function to calculate percentages
local function calculate_percentage(file_counts, total_files)
    local percentages = {}

    for ext, count in pairs(file_counts) do
        table.insert(percentages, {
            ext = ext,
            count = count,
            percentage = (count / total_files) * 100,
        })
    end

    table.sort(percentages, function(lhs, rhs)
        if lhs.percentage == rhs.percentage then
            return lhs.ext < rhs.ext
        end

        return lhs.percentage > rhs.percentage
    end)

    return percentages
end

local function model(directory)
    local result, scan_error =
        scan(directory)

    if not result then
        return nil, scan_error
    end

    result.types =
        result.counted_files > 0
        and calculate_percentage(
            result.file_counts,
            result.counted_files
        )
        or {}

    result.file_counts = nil

    return result
end

-- Function to limit the width of the display string
local function trim_string_to_max_width(str, max_width)
    if #str > max_width then
        return str:sub(1, max_width - 3) .. "..." -- Truncate and add ellipsis if too long
    end
    return str
end

-- Function to get virtual text for file types
local function get_filetype_virtualtext(directory)
    local directory_model = model(directory)
    if
        not directory_model
        or directory_model.counted_files == 0
    then
        return nil
    end

    local virt_text = {}

    for _, item in ipairs(directory_model.types) do
        local ext = item.ext
        local perc = item.percentage
        -- Use grayscale theme if enabled, otherwise use color theme
        local color = use_gray_theme and gray_color_map[ext] or ext_color_map[ext] or (use_gray_theme and default_gray_color or default_color)

        -- Adjust color opacity
        color = adjust_opacity(color, opacity)

        -- Create or retrieve the highlight group for this extension
        local hl_group = create_highlight_group(ext, color)

        -- Round the percentage to the specified number of decimal places
        local rounded_perc = round(perc, decimal_places)

        -- Dynamically format the percentage string based on decimal_places
        local format_string = string.format("%%s: %%.%df%%%% ", decimal_places)
        local percentage_str = string.format(format_string, ext, rounded_perc)

        -- Trim the string to max width
        percentage_str = trim_string_to_max_width(percentage_str, max_width)

        -- Add it to the virtual text array
        table.insert(virt_text, { percentage_str, hl_group })
    end

    return virt_text
end

return {
    adjust_opacity = adjust_opacity,
    use_gray_theme = use_gray_theme,
    opacity = opacity,
    gray_color_map = gray_color_map,
    default_gray_color = default_gray_color,
    ext_color_map = ext_color_map,
    default_color = default_color,
    scan = model,
    get_filetype_virtualtext = get_filetype_virtualtext,
}
