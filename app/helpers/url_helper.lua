local _M = {}

function _M.base_url()
    local Config = require('app.core.Config')
    local base_url = Config.item('base_url')

    if not base_url or base_url == '' then
        local ok, new_tab = pcall(require, "table.new")
        if not ok then
            new_tab = function(narr, nrec) return {} end
        end

        local protocol = Config.item('url_protocol') or 'http'
        local host = Config.item('host') or 'localhost'
        local port = Config.item('port')

        local parts = new_tab(4, 0)
        parts[1] = protocol
        parts[2] = '://'
        parts[3] = host

        if port and port ~= 80 then
            parts[4] = ':' .. tostring(port)
            return table.concat(parts, '')
        end

        return table.concat(parts, '')
    end

    return base_url
end

function _M.site_url(uri)
    local base = _M.base_url()
    if uri then
        return base .. '/' .. uri
    end
    return base
end

return _M
