-- Small table utilities (OpenResty-friendly, no external dependencies).

local _M = {}

-- Recursive merge of tables. `behavior` is accepted for API compatibility
-- with Neovim's vim.tbl_deep_extend ('force' or 'keep'); 'force' (later
-- sources win) is the default.
function _M.deep_extend(behavior, ...)
    local out = {}
    for _, src in ipairs({ ... }) do
        if type(src) == 'table' then
            for k, v in pairs(src) do
                if type(v) == 'table' and type(out[k]) == 'table' then
                    out[k] = _M.deep_extend(behavior, out[k], v)
                else
                    out[k] = v
                end
            end
        end
    end
    return out
end

-- Shallow copy.
function _M.copy(t)
    local out = {}
    if type(t) == 'table' then
        for k, v in pairs(t) do out[k] = v end
    end
    return out
end

return _M
