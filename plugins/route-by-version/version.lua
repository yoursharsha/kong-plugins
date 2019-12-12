local version_delimiter_regex = "[^%.]+"

function comp_versions(a, b)
    -- a ,b  = 2.4.5
    local aArr = split(a, version_delimiter_regex)
    local bArr = split(b, version_delimiter_regex)
    local mx = math.max(#aArr, #bArr)
    local i = 1
    while i <= mx do
        if aArr[i] == nil then aArr[i] = 0 end
        if bArr[i] == nil then bArr[i] = 0 end
        if aArr[i] == bArr[i] then
            i = i + 1
        else
            return aArr[i] < bArr[i], false
        end
    end
    if i == mx + 1 then
        -- equals
        return true, true
    end
    return true, false
end

function comp_rules(a, b)
    -- a, b = {upstream: {...}, version: "2.4.5"}
    return comp_versions(a.version, b.version)
end

function split(s, ch)
    local t = {}
    for i in string.gmatch(s, ch) do
        if i ~= ch then table.insert(t, tonumber(i)) end
    end
    return t
end

function near(val, t)
    local ret = 0

    local s = 1
    local e = #t
    local i = math.floor((e + s) / 2)
    while s <= e and i <= #t and i >= 1 do
        if select(2, comp_versions(val, t[i].version)) then return i end

        -- if val <= t[i] and val <= t[i-1] then
        if comp_versions(val, t[i].version) and i - 1 >= 1 and
            comp_versions(val, t[i - 1].version) then
            e = i - 1
        elseif comp_versions(t[i].version, val) and i + 1 <= #t and
            comp_versions(t[i + 1].version, val) then
            s = i + 1
        elseif comp_versions(val, t[i].version) then
            return i - 1
        else
            return i
        end

        i = math.floor((e + s) / 2)
    end
    return -1
end

return {
    near = near,
    compare_rules = comp_rules,
    compare_versions = comp_versions
}
