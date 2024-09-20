return {
    "jackMort/ChatGPT.nvim",
    lazy = false,
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
            openai_params = {
                model = "gpt-4o",
                frequency_penalty = 0,
                presence_penalty = 0,
                temperature = 0,
                top_p = 1,
                n = 1,
            },
            openai_edit_params = {
                model = "gpt-4o",
                frequency_penalty = 0,
                presence_penalty = 0,
                temperature = 0,
                top_p = 1,
                n = 1,
            },
            use_openai_functions_for_edits = false,
            actions_paths = {},
            predefined_chat_gpt_prompts = "https://raw.githubusercontent.com/f/awesome-chatgpt-prompts/main/prompts.csv",
        })
    end,
}
