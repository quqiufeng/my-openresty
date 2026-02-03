local _M = {}

function _M.trim(s)
    return string.gsub(s, '^%s*(.-)%s*$', '%1')
end

function _M.ltrim(s)
    return string.gsub(s, '^%s*', '')
end

function _M.rtrim(s)
    return string.gsub(s, '%s*$', '')
end

function _M.random_string(length)
    local chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local result = {}
    for i = 1, length do
        table.insert(result, chars:sub(math.random(#chars), math.random(#chars)))
    end
    return table.concat(result)
end

function _M.ucfirst(s)
    return string.upper(string.sub(s, 1, 1)) .. string.sub(s, 2)
end

return _M
