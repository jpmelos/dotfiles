function GetFunctionLocation(func)
    local info = debug.getinfo(func, "S")
    if not info then
        return "[no function info]"
    end
    if info.what == "C" then
        return "[C function]"
    end

    return string.format(
        "%s-%s:%d-%d",
        info.what,
        info.source,
        info.linedefined,
        info.lastlinedefined
    )
end
