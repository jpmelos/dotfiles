-- This plugin is enabled only if the environment variable
-- `AUGMENT_CODE_AI_ENABLED` is set at the time Neovim starts. We don't want to
-- unexpectedly share code with them.
--
-- To configure this plugin, set the following in the project's `nvim.lua`
-- file:
-- ```
-- vim.g.augment_workspace_folders = { vim.fn.getcwd() }
-- ```
return {
    "augmentcode/augment.vim",
    cond = function()
        return os.getenv("AUGMENT_CODE_AI_ENABLED") == "1"
    end,
    cmd = { "Augment" },
    keys = {
        {
            "<leader>aa",
            function()
                vim.cmd(
                    "vs /tmp/augment-code-prompt.md"
                        .. " | setlocal bufhidden=delete nobuflisted"
                        .. " | %delete _"
                        .. " | startinsert"
                )
            end,
            mode = { "n", "v" },
            desc = "AI chat, new prompt",
        },
        {
            "<leader>as",
            function()
                vim.cmd(
                    "vs /tmp/augment-code-prompt.md"
                        .. " | setlocal bufhidden=delete nobuflisted"
                )
            end,
            mode = { "n", "v" },
            desc = "AI chat, edit prompt",
        },
        {
            "<leader>at",
            "<cmd>Augment chat-toggle<CR>",
            mode = { "n", "v" },
            desc = "Open AI chat window",
        },
    },
    init = function()
        local g = vim.g
        local api = vim.api

        g.augment_disable_tab_mapping = true
        g.augment_disable_completions = true
        g.augment_suppress_version_warning = true

        api.nvim_create_autocmd("BufWinLeave", {
            pattern = "augment-code-prompt.md",
            callback = function()
                local lines = api.nvim_buf_get_lines(0, 0, -1, false)
                if #lines == 0 then
                    return
                end
                local text = table.concat(lines, "\n")

                vim.schedule(function()
                    -- The function expects the number of lines included in a
                    -- selected range. However, the function will still check
                    -- the current mode and, if it's visual, will get the
                    -- selected text anyway. So we can pass any numeric value
                    -- here and rely on the mode check.
                    -- https://github.com/augmentcode/augment.vim/blob/97418c9dfc1918fa9bdd23863ea3d2e49130727f/autoload/augment.vim#L249-L278
                    -- https://github.com/augmentcode/augment.vim/blob/97418c9dfc1918fa9bdd23863ea3d2e49130727f/autoload/augment.vim#L166-L226
                    vim.fn["augment#Command"](1, "chat " .. text)
                end)
            end,
        })
    end,
}
