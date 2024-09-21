local openai_params = {
    model = "gpt-4o",
    frequency_penalty = 0,
    presence_penalty = 0,
    temperature = 0,
    top_p = 1,
    n = 1,
}

return {
    "jackMort/ChatGPT.nvim",
    cmd = { "ChatGPT", "ChatGPTEditWithInstructions" },
    keys = {
        {
            "<leader>ao",
            "<cmd>ChatGPT<CR>",
            mode = { "n" },
            desc = "Open chat",
        },
        {
            "<leader>ae",
            "<cmd>ChatGPTEditWithInstructions<CR>",
            mode = { "v" },
            desc = "Edit code",
        },
    },
    dependencies = {
        "MunifTanjim/nui.nvim",
        "nvim-lua/plenary.nvim",
        "folke/trouble.nvim",
        "nvim-telescope/telescope.nvim",
    },
    config = function()
        require("chatgpt").setup({
            api_key_cmd = "op item get vtzbgc3ybgalzoamj7hietafpe --vault afpmshswzblkzmziqhtqfu2sji --fields notesPlain",
            show_line_numbers = true,
            openai_params = openai_params,
            openai_edit_params = openai_params,
        })
    end,
}
