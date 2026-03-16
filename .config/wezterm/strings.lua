local m = {}

function m.dump(o)
    if type(o) ~= "table" then
        return tostring(o)
    end
    local s = "{ "
    for k, v in pairs(o) do
        s = s .. k .. " = " .. m.dump(v) .. ", "
    end
    return s .. "}"
end

return m
