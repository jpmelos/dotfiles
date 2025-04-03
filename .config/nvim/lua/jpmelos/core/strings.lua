function string.startswith(str, start)
    return str.sub(str, 1, str.len(start)) == start
end

function string.trim(str)
    return str:match("^%s*(.-)%s*$")
end
