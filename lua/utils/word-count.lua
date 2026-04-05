-- -- Global function to get word count excluding metadata for Neorg
-- _G.word_count_excluding_metadata = function()
--     -- Get the current buffer lines
--     local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
--     local in_metadata = false
--     local word_count = 0

--     -- Iterate over each line
--     for _, line in ipairs(lines) do
--         -- Check for metadata start and end in Neorg
--         if line:match("^@document%.meta") then
--             in_metadata = true
--         elseif line:match("^@end") and in_metadata then
--             in_metadata = false
--         elseif not in_metadata then
--             -- Count words in lines outside the metadata
--             for word in line:gmatch("%S+") do
--                 word_count = word_count + 1
--             end
--         end
--     end

--     -- Return the word count as a string
--     return tostring(word_count)
-- end

-- -- Function to update statusline with word count
-- vim.o.statusline = "%f %m %r %h %= %l:%c | %p%% %< %L lines | %{v:lua.word_count_excluding_metadata()} words"

-- Explanation of the components
-- %f: Shows the file name.
-- %m %r %h: Shows modified, readonly, and help flags.
-- %=: Pushes the following content to the far right.
-- %l:%c: Shows the current line and column.
-- %p%%: Displays the percentage through the file (like 83%).
-- %<: Truncates the line if it’s too long for the window width, ensuring it doesn’t overflow.
-- %L: Displays the total number of lines in the file.
-- Word Count: %{v:lua.word_count_excluding_metadata()}: Shows the custom word count on the far right.

-- ============================================================================================

-- REFACTOR --
-- Return necessary data only
-- Let customization.statusline.lua create the statusline in one place
local M = {}

-- Returns integer count (number), excluding Neorg @document.meta … @end blocks
function M.count_current_buf()
    local bufnr = 0
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local in_metadata = false
    local word_count = 0

    for _, line in ipairs(lines) do
        if line:match("^@document%.meta") then
            in_metadata = true
        elseif in_metadata and line:match("^@end") then
            in_metadata = false
        elseif not in_metadata then
            for _ in line:gmatch("%S+") do
                word_count = word_count + 1
            end
        end
    end

    return word_count
end

function M.count_str()
    return tostring(M.count_current_buf())
end

return M
