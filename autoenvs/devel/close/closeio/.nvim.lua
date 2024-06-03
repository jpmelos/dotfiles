vim.g.disable_autoformat = false

local conform = require("conform")
conform.formatters_by_ft = {
	python = { "black", "ruff_fix", "ruff_organize_imports" },
}
