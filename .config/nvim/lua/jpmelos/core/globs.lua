local bit = require("bit")

function GenerateVimGlobs(glob)
    -- Given a glob that may contain one or more `**/` patterns, generate all
    -- variations of the glob with and without each `**/`.
    -- For example, if the input is `abc/**/def/**/*.lua`, give me:
    -- {
    --     "abc/def/*.lua",
    --     "abc/**/def/*.lua",
    --     "abc/def/**/*.lua",
    --     "abc/**/def/**/*.lua",
    -- }

    local alternatives = {}

    -- Find all positions of "**/".
    local positions = {}
    local start = 1
    while true do
        start, _ = glob:find("%*%*/", start)
        if not start then
            break
        end
        table.insert(positions, start)
        start = start + 3
    end

    -- Generate all possible combinations (2^n where n is number of "**/").
    local n_positions = #positions
    for i = 0, (2 ^ n_positions - 1) do
        local pattern = glob
        local n_removals = 0
        for j = 1, n_positions do
            -- If bit j is 0, remove the j-th "**/".
            if bit.band(i, bit.lshift(1, j - 1)) == 0 then
                local start = positions[j]
                pattern = pattern:sub(1, start - 1 - (n_removals * 3))
                    .. pattern:sub(start + 3 - (n_removals * 3))
                n_removals = n_removals + 1
            end
        end
        table.insert(alternatives, pattern)
    end

    return alternatives
end

-- vim.notify(
--     vim.inspect(vim.deep_equal(generate_vim_globs("*.lua"), { "*.lua" }))
-- )
-- vim.notify(vim.inspect(generate_vim_globs("*.lua")))
-- vim.notify(
--     vim.inspect(
--         vim.deep_equal(generate_vim_globs("**/*.lua"), { "*.lua", "**/*.lua" })
--     )
-- )
-- vim.notify(vim.inspect(generate_vim_globs("**/*.lua")))
-- vim.notify(
--     vim.inspect(
--         vim.deep_equal(
--             generate_vim_globs("abc/**/*.lua"),
--             { "abc/*.lua", "abc/**/*.lua" }
--         )
--     )
-- )
-- vim.notify(vim.inspect(generate_vim_globs("abc/**/*.lua")))
-- vim.notify(
--     vim.inspect(
--         vim.deep_equal(
--             generate_vim_globs("**/abc/*.lua"),
--             { "abc/*.lua", "**/abc/*.lua" }
--         )
--     )
-- )
-- vim.notify(vim.inspect(generate_vim_globs("**/abc/*.lua")))
-- vim.notify(
--     vim.inspect(vim.deep_equal(generate_vim_globs("abc/**/def/**/*.lua"), {
--         "abc/def/*.lua",
--         "abc/**/def/*.lua",
--         "abc/def/**/*.lua",
--         "abc/**/def/**/*.lua",
--     }))
-- )
-- vim.notify(vim.inspect(generate_vim_globs("abc/**/def/**/*.lua")))
-- vim.notify(
--     vim.inspect(
--         vim.deep_equal(generate_vim_globs("abc/**/def/**/ghi/**/*.lua"), {
--             "abc/def/ghi/*.lua",
--             "abc/**/def/ghi/*.lua",
--             "abc/def/**/ghi/*.lua",
--             "abc/**/def/**/ghi/*.lua",
--             "abc/def/ghi/**/*.lua",
--             "abc/**/def/ghi/**/*.lua",
--             "abc/def/**/ghi/**/*.lua",
--             "abc/**/def/**/ghi/**/*.lua",
--         })
--     )
-- )
-- vim.notify(vim.inspect(generate_vim_globs("abc/**/def/**/ghi/**/*.lua")))
