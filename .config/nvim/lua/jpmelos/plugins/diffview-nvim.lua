return {
    "sindrets/diffview.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    keys = {
        { "<leader>xd", ":DiffviewOpen ", mode = "n", desc = "Open diff" },
        {
            "<leader>xm",
            function()
                local main_branch, err = RunForOutput("git main-branch")
                if main_branch == nil then
                    vim.notify("Error getting git main branch: " .. err)
                    return
                end
                return ":DiffviewOpen " .. main_branch .. "...HEAD<CR>"
            end,
            mode = "n",
            desc = "Open diff against main",
            expr = true,
        },
        {
            "<leader>xh",
            ":DiffviewFileHistory ",
            mode = "n",
            desc = "Open file history",
        },
        {
            "<leader>xf",
            ":DiffviewFileHistory %<CR>",
            mode = "n",
            desc = "Open current file history",
        },
    },
}
