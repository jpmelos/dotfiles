return {
    "mistweaverco/kulala.nvim",
    lazy = false,
    init = function()
        local K = vim.keymap.set

        vim.filetype.add({ extension = { ["http"] = "http" } })

        require("kulala").setup()

        K(
            "n",
            "<leader>r[",
            ":lua require('kulala').jump_prev()<CR>",
            { desc = "Previous request" }
        )
        K(
            "n",
            "<leader>r]",
            ":lua require('kulala').jump_next()<CR>",
            { desc = "Next request" }
        )
        K(
            "n",
            "<leader>rr",
            ":lua require('kulala').run()<CR>",
            { desc = "Run request" }
        )
        K(
            "n",
            "<leader>rc",
            ":lua require('kulala').copy()<CR>",
            { desc = "Copy request" }
        )
    end,
}
