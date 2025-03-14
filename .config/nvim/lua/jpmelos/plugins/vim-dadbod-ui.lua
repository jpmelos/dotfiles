return {
    "kristijanhusak/vim-dadbod-ui",
    dependencies = {
        "tpope/vim-dadbod",
        "kristijanhusak/vim-dadbod-completion",
    },
    init = function()
        local K = vim.keymap.set

        local g = vim.g
        local api = vim.api

        g.db_ui_disable_mappings = 1
        g.db_ui_show_help = 0
        g.db_ui_use_nerd_fonts = 1
        g.db_ui_execute_on_save = 0
        g.db_ui_auto_execute_table_helpers = 1

        K("n", "<leader>vo", "<cmd>DBUIToggle<cr>", { desc = "Toggle DBUI" })

        api.nvim_create_autocmd("FileType", {
            pattern = "dbui",
            callback = function()
                K(
                    "n",
                    "<C-n>",
                    "<Plug>(DBUI_Redraw)",
                    { desc = "Redraw", buffer = true }
                )
                K(
                    "n",
                    "a",
                    "<Plug>(DBUI_AddConnection)",
                    { desc = "Add connection", buffer = true }
                )
                K(
                    "n",
                    "<CR>",
                    "<Plug>(DBUI_SelectLine)",
                    { desc = "Toggle item", buffer = true }
                )
                K(
                    "n",
                    "r",
                    "<Plug>(DBUI_RenameLine)",
                    { desc = "Rename item", buffer = true }
                )
                K(
                    "n",
                    "d",
                    "<Plug>(DBUI_DeleteLine)",
                    { desc = "Delete item", buffer = true }
                )
                K(
                    "n",
                    "q",
                    "<Plug>(DBUI_Quit)",
                    { desc = "Delete item", buffer = true }
                )
            end,
        })

        api.nvim_create_autocmd("FileType", {
            pattern = "dbout",
            callback = function()
                K(
                    "n",
                    "yic",
                    "<Plug>(DBUI_YankCellValue)y",
                    { desc = "Select cell value", buffer = true }
                )
                K(
                    "n",
                    "<leader>vr",
                    "<Plug>(DBUI_ToggleResultLayout)",
                    { desc = "Toggle result layout", buffer = true }
                )
            end,
        })

        api.nvim_create_autocmd("FileType", {
            pattern = "sql",
            callback = function()
                K(
                    { "n", "v" },
                    "<leader>vr",
                    "<Plug>(DBUI_ExecuteQuery)",
                    { desc = "Execute query", buffer = true }
                )
                K(
                    "n",
                    "<leader>vs",
                    "<Plug>(DBUI_SaveQuery)",
                    { desc = "Save query", buffer = true }
                )
            end,
        })
    end,
}
