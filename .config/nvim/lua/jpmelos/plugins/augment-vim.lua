-- This plugin is enabled only if `vim.g.enable_augment_code == true`. at the
-- time Neovim starts. We don't want to unexpectedly share proprietary code
-- with AI models. Use a project-local `.nvim.lua` file to set that variable.
--
-- The workspace is set to the current working directory by default. To
-- configure a different workspace (for example, because you want to add code
-- that is outside of the current working directory), set this in the project's
-- `.nvim.lua` file (make sure to include `vim.fn.getcwd()` explicitly if you
-- what that to be included):
-- ```
-- vim.g.augment_workspace_folders = { vim.fn.getcwd(), "/Users/..." }
-- ```
local CHAT_HISTORY_BUFFER_NAME = "AugmentChatHistory"
local CHAT_PROMPT_BUFFER_NAME = "/tmp/augment-code-prompt.md"

local function open_augment_prompt_buffer(preserve_old_prompt)
    local current_buf_state = {
        winnr = vim.api.nvim_get_current_win(),
        visual_selection = GetVisualSelection(),
    }

    -- Find the Augment chat window in the current tab.
    local chat_winnr = nil
    for _, winnr in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        local bufnr = vim.api.nvim_win_get_buf(winnr)
        local buf_name = vim.api.nvim_buf_get_name(bufnr)
        if buf_name:find(CHAT_HISTORY_BUFFER_NAME) then
            chat_winnr = winnr
            break
        end
    end

    local base_cmd
    if chat_winnr then
        vim.api.nvim_set_current_win(chat_winnr)
        base_cmd = "split"
    else
        base_cmd = "vsplit"
    end
    local cmd_parts = {
        base_cmd .. CHAT_PROMPT_BUFFER_NAME,
        "setlocal bufhidden=delete nobuflisted",
    }
    if not preserve_old_prompt then
        table.insert(cmd_parts, "%delete _")
        table.insert(cmd_parts, "startinsert")
    end
    local cmd = table.concat(cmd_parts, " | ")
    vim.cmd(cmd)

    vim.api.nvim_create_autocmd("BufWinLeave", {
        pattern = CHAT_PROMPT_BUFFER_NAME,
        callback = function()
            local text = GetBufferContents()

            vim.schedule(function()
                vim.api.nvim_set_current_win(current_buf_state.winnr)

                if current_buf_state.visual_selection then
                    RestoreVisualSelection(
                        current_buf_state.visual_selection.mode,
                        current_buf_state.visual_selection.start_pos,
                        current_buf_state.visual_selection.end_pos
                    )
                end

                -- If no prompt was provided, restore selection but don't
                -- send anything to Augment.
                if text ~= "" then
                    -- The function expects the number of lines included in a
                    -- selected range. However, the function will still check
                    -- the current mode and, if it's visual, will get the
                    -- selected text anyway. So we can pass any numeric value
                    -- here and rely on the mode check.
                    -- https://github.com/augmentcode/augment.vim/blob/97418c9dfc1918fa9bdd23863ea3d2e49130727f/autoload/augment.vim#L249-L278
                    -- https://github.com/augmentcode/augment.vim/blob/97418c9dfc1918fa9bdd23863ea3d2e49130727f/autoload/augment.vim#L166-L226
                    vim.fn["augment#Command"](1, "chat " .. text)

                    -- When opening a new chat window, visual selection is
                    -- lost. We need to restore it to have a consistent
                    -- behavior with the case when the chat window is already
                    -- open.
                    if chat_winnr == nil then
                        RestoreVisualSelection(
                            current_buf_state.visual_selection.mode,
                            current_buf_state.visual_selection.start_pos,
                            current_buf_state.visual_selection.end_pos
                        )
                    end
                end
            end)
        end,
        once = true,
    })
end

return {
    dir = vim.fn.expand("~/devel/augment.vim"),
    cond = function()
        return vim.g.enable_augment_code == true
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

        if g.augment_workspace_folders == nil then
            g.augment_workspace_folders = { vim.fn.getcwd() }
        end

        api.nvim_create_autocmd("BufNew", {
            pattern = CHAT_HISTORY_BUFFER_NAME,
            callback = function()
                opt_local.scrolloff = 1000
                opt_local.winfixwidth = true
            end,
        })

        -- <Enter> in normal mode saves and closes the buffer. In insert mode
        -- and normal mode, <S-Enter> saves and closes the buffer.
        api.nvim_create_autocmd("BufEnter", {
            pattern = CHAT_PROMPT_BUFFER_NAME,
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
    end,
}
