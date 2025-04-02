-- This plugin is enabled only if the environment variable
-- `AUGMENT_CODE_AI_ENABLED` is set at the time Neovim starts. We don't want to
-- unexpectedly share proprietary code with them.
--
-- The workspace is set to the current working directory by default. To
-- configure a different workspace (for example, because you want to add code
-- that is outside of the current working directory), set this in the project's
-- `.nvim.lua` file (make sure to include `vim.fn.getcwd()` explicitly if you
-- what that to be included):
-- ```
-- vim.g.augment_workspace_folders = { vim.fn.getcwd(), "/Users/..." }
-- ```
local function open_augment_prompt_buffer(preserve_old_prompt)
    local visual_selection = GetVisualSelection()

    local cmd = "vs /tmp/augment-code-prompt.md"
        .. " | setlocal bufhidden=delete nobuflisted"
    if not preserve_old_prompt then
        cmd = cmd .. " | %delete _ | startinsert"
    end
    vim.cmd(cmd)

    if visual_selection then
        vim.b.original_visual_selection_mode = visual_selection[1]
        vim.b.original_visual_selection_start_pos = visual_selection[2]
        vim.b.original_visual_selection_end_pos = visual_selection[3]
    end
end

return {
    dir = vim.fn.expand("~/devel/augment.vim"),
    cond = function()
        return os.getenv("AUGMENT_CODE_AI_ENABLED") == "1"
    end,
    cmd = { "Augment" },
    keys = {
        {
            "<leader>aa",
            function()
                open_augment_prompt_buffer(false)
            end,
            mode = { "n", "v" },
            desc = "AI chat, new prompt",
        },
        {
            "<leader>as",
            function()
                open_augment_prompt_buffer(true)
            end,
            mode = { "n", "v" },
            desc = "AI chat, edit prompt",
        },
        {
            "<leader>ac",
            "<cmd>Augment chat-toggle<CR>",
            mode = { "n", "v" },
            desc = "Toggle AI chat window",
        },
    },
    init = function()
        local g = vim.g
        local api = vim.api
        local opt_local = vim.opt_local

        local K = vim.keymap.set

        -- Disable Augment Code suggestions.
        g.augment_disable_tab_mapping = true
        g.augment_disable_completions = true
        g.augment_suppress_version_warning = true

        g.augment_workspace_folders = { vim.fn.getcwd() }

        api.nvim_create_autocmd("BufNew", {
            pattern = "AugmentChatHistory",
            callback = function()
                opt_local.winfixwidth = true
            end,
        })

        -- <Enter> in normal mode saves and closes the buffer. In insert mode
        -- and normal mode, <S-Enter> saves and closes the buffer.
        api.nvim_create_autocmd("BufEnter", {
            pattern = "augment-code-prompt.md",
            callback = function()
                K("n", "<Enter>", function()
                    vim.cmd("wq")
                end, { buffer = true })
                K("n", "<S-Enter>", function()
                    vim.cmd("wq")
                end, { buffer = true })
                K("i", "<S-Enter>", function()
                    NormalMode()
                    vim.cmd("wq")
                end, { buffer = true })
            end,
        })
        api.nvim_create_autocmd("BufWinLeave", {
            pattern = "augment-code-prompt.md",
            callback = function()
                -- Recover visual selection positions if they were stored.
                local v_mode, v_start_pos, v_end_pos
                if vim.b.original_visual_selection_mode then
                    v_mode = vim.b.original_visual_selection_mode
                    v_start_pos = vim.b.original_visual_selection_start_pos
                    v_end_pos = vim.b.original_visual_selection_end_pos
                end

                local text = GetBufferContents()

                vim.schedule(function()
                    if v_mode then
                        RestoreVisualSelection(v_mode, v_start_pos, v_end_pos)
                    end

                    -- If no prompt was provided, restore selection but don't
                    -- send anything to Augment.
                    if text == "" then
                        return
                    end

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
