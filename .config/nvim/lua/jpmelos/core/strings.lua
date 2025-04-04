function string.startswith(str, prefix)
    return str:sub(1, str.len(prefix)) == prefix
end

function string.endswith(str, suffix)
    return str:sub(-#suffix) == suffix
end

function string.trim(str)
    return str:match("^%s*(.-)%s*$")
end

function string.split(str, delimiter)
    local parts = {}
    for part in str:gmatch("([^" .. delimiter .. "]*)?") do
        if part ~= "" then
            table.insert(parts, part)
        end
    end
    return parts
end

function string.join(delimiter, seq)
    return table.concat(seq, delimiter)
end

function string.matchglob(str, glob)
    for _, pattern in ipairs(GenerateVimGlobs(glob)) do
        if vim.fn.matchstr(str, vim.fn.glob2regpat(pattern)) ~= "" then
            return true
        end
    end
    return false
end
