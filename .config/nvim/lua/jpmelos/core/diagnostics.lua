local original_diagnostic_open_float = vim.diagnostic.open_float
local function show_deduped_diagnostics_in_float(_)
    local seen = {}

    local function dedupe_diagnostic(diag)
        local message = Trim(
            DropFromSubstringToEnd(diag.message, "Suggested replacement:")
        )
        local key = ("%d:%s"):format(diag.lnum, message)
        if not seen[key] then
            seen[key] = true
            return ("[%s] %s"):format(diag.source or "unknown", message)
        end

        return nil
    end

    original_diagnostic_open_float({
        format = dedupe_diagnostic,
        border = "rounded",
    })
end
vim.diagnostic.open_float = show_deduped_diagnostics_in_float

local original_diagnostic_handler_signs_show =
    vim.diagnostic.handlers.signs.show
local function show_deduped_diagnostics_in_signs(
    namespace,
    bufnr,
    diagnostics,
    opts
)
    local seen = {}
    local deduped_diagnostics = {}
    for _, diag in ipairs(diagnostics) do
        local message = Trim(
            DropFromSubstringToEnd(diag.message, "Suggested replacement:")
        )
        local key = ("%d:%s"):format(diag.lnum, message)
        if not seen[key] then
            seen[key] = true
            table.insert(deduped_diagnostics, diag)
        end
    end

    if #deduped_diagnostics > 0 then
        original_diagnostic_handler_signs_show(
            namespace,
            bufnr,
            deduped_diagnostics,
            opts
        )
    end
end
vim.diagnostic.handlers.signs.show = show_deduped_diagnostics_in_signs

vim.diagnostic.config({
    severity_sort = true,
    signs = {
        -- Other priority defined for Git signs, being prioritized as 5.
        priority = 1,
        text = {
            [vim.diagnostic.severity.ERROR] = " ",
            [vim.diagnostic.severity.WARN] = " ",
            [vim.diagnostic.severity.INFO] = " ",
            [vim.diagnostic.severity.HINT] = "󰠠 ",
        },
    },
})
