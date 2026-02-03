-- HttpClient Library for MyResty
-- Asynchronous HTTP client using OpenResty cosocket

local HttpClient = {}
HttpClient.__index = HttpClient

local ok, new_tab = pcall(require, "table.new")
if not ok then
    new_tab = function(narr, nrec) return {} end
end

function HttpClient:new(options)
    local self = setmetatable({}, HttpClient)

    self.options = options or {}
    self.default_timeout = options and options.timeout or 30000
    self.default_pool_size = options and options.pool_size or 10
    self.sockets = {}

    return self
end

function HttpClient:_parse_url(url)
    local protocol, host, port, path

    if url:match("^https://") then
        protocol = "https"
        port = 443
        url = url:gsub("^https://", "")
    elseif url:match("^http://") then
        protocol = "http"
        port = 80
        url = url:gsub("^http://", "")
    else
        protocol = "http"
        port = 80
    end

    local host_path = url:match("^([^/]+)(.*)$")
    if host_path then
        host = host_path:match("^([^:]+)")
        local port_match = host_path:match(":(%d+)")
        if port_match then
            port = tonumber(port_match)
        end
        path = url:match("^[^/]+(.*)$")
        if path == "" then path = "/" end
    else
        host = url
        path = "/"
    end

    return protocol, host, port, path
end

function HttpClient:_build_query(params)
    if not params or type(params) ~= "table" then
        return nil
    end

    local query_parts = {}
    for key, value in pairs(params) do
        table.insert(query_parts, ngx.escape_uri(key) .. "=" .. ngx.escape_uri(tostring(value)))
    end

    if #query_parts > 0 then
        return table.concat(query_parts, "&")
    end
    return nil
end

function HttpClient:request(method, url, options)
    options = options or {}

    local timeout = options.timeout or self.default_timeout
    local body = options.body or options.data
    local headers = options.headers or {}
    local query = options.query

    local protocol, host, port, path = self:_parse_url(url)

    local query_str = self:_build_query(query)
    if query_str then
        if path:find("?") then
            path = path .. "&" .. query_str
        else
            path = path .. "?" .. query_str
        end
    end

    local sock = ngx.socket.tcp()
    sock:settimeout(timeout)

    local ok, err = sock:connect(host, port)
    if not ok then
        return nil, "Connection failed: " .. err
    end

    if protocol == "https" then
        local ok, err = sock:sslhandshake(nil, host, false)
        if not ok then
            sock:close()
            return nil, "SSL handshake failed: " .. err
        end
    end

    local request_line = method .. " " .. path .. " HTTP/1.1\r\n"
    local request_headers = "Host: " .. host .. ":" .. port .. "\r\n"

    for key, value in pairs(headers) do
        request_headers = request_headers .. key .. ": " .. tostring(value) .. "\r\n"
    end

    if not headers["Content-Type"] and body then
        request_headers = request_headers .. "Content-Type: application/json\r\n"
    end

    if body then
        request_headers = request_headers .. "Content-Length: " .. #body .. "\r\n"
    end

    request_headers = request_headers .. "Connection: close\r\n\r\n"

    local bytes, err = sock:send(request_line .. request_headers)
    if not bytes then
        sock:close()
        return nil, "Send request failed: " .. err
    end

    if body then
        bytes, err = sock:send(body)
        if not bytes then
            sock:close()
            return nil, "Send body failed: " .. err
        end
    end

    local reader = sock:receiveuntil("\r\n\r\n")
    local headers_line, err = reader()
    if not headers_line then
        sock:close()
        return nil, "Receive headers failed: " .. err
    end

    local status_code = tonumber(headers_line:match("HTTP/%d%.%d (%d+)"))
    local response_headers = {}
    local content_length = 0
    local chunked = false

    local line, err = reader()
    while line and line ~= "" do
        local key, value = line:match("^([^:]+):%s*(.+)$")
        if key and value then
            key = key:lower()
            response_headers[key] = value
            if key == "content-length" then
                content_length = tonumber(value) or 0
            elseif key == "transfer-encoding" and value:lower() == "chunked" then
                chunked = true
            end
        end
        line, err = reader()
    end

    local response_body
    if chunked then
        local reader = sock:receiveuntil("0\r\n\r\n")
        response_body = ""
        while true do
            local chunk_size_line = sock:receiveuntil("\r\n")
            local chunk_size, err = chunk_size_line()
            if not chunk_size then
                break
            end
            local size = tonumber(chunk_size, 16)
            if not size or size == 0 then
                break
            end
            local chunk = sock:receive(size + 2)
            if chunk then
                response_body = response_body .. chunk:sub(1, -3)
            end
        end
    elseif content_length > 0 then
        response_body, err = sock:receive(content_length)
        if not response_body then
            response_body = ""
        end
    else
        response_body, err = sock:receive("*a")
        if not response_body then
            response_body = ""
        end
    end

    sock:close()

    local result = {
        status = status_code or 500,
        body = response_body,
        headers = response_headers,
        success = (status_code or 500) >= 200 and (status_code or 500) < 300
    }

    return result, nil
end

function HttpClient:get(url, options)
    return self:request("GET", url, options)
end

function HttpClient:post(url, options)
    return self:request("POST", url, options)
end

function HttpClient:put(url, options)
    return self:request("PUT", url, options)
end

function HttpClient:patch(url, options)
    return self:request("PATCH", url, options)
end

function HttpClient:delete(url, options)
    return self:request("DELETE", url, options)
end

function HttpClient:head(url, options)
    return self:request("HEAD", url, options)
end

function HttpClient:options(url, options)
    return self:request("OPTIONS", url, options)
end

function HttpClient:json(url, data, method)
    method = method or "POST"

    local headers = {
        ["Content-Type"] = "application/json",
        ["Accept"] = "application/json"
    }

    local cjson = require("cjson")
    local body = cjson.encode(data)

    return self:request(method, url, {
        body = body,
        headers = headers
    })
end

function HttpClient:form(url, data, method)
    method = method or "POST"

    local headers = {
        ["Content-Type"] = "application/x-www-form-urlencoded",
        ["Accept"] = "application/json"
    }

    local body_parts = {}
    for key, value in pairs(data) do
        table.insert(body_parts, ngx.escape_uri(key) .. "=" .. ngx.escape_uri(tostring(value)))
    end
    local body = table.concat(body_parts, "&")

    return self:request(method, url, {
        body = body,
        headers = headers
    })
end

function HttpClient:download(url, filepath)
    local res, err = self:get(url)

    if not res then
        return false, err
    end

    if not res.success then
        return false, "Download failed with status: " .. res.status
    end

    local FileUtil = require("app.utils.file")

    local dir = filepath:match("^(.+)/[^/]+$")
    if dir then
        FileUtil.mkdir(dir, 493)
    end

    local file = io.open(filepath, "wb")
    if not file then
        return false, "Failed to open file for writing: " .. filepath
    end

    file:write(res.body)
    file:close()

    return true, filepath
end

function HttpClient:set_timeout(timeout)
    self.default_timeout = timeout
    return self
end

HttpClient.new = HttpClient.new
HttpClient.request = HttpClient.request
HttpClient.get = HttpClient.get
HttpClient.post = HttpClient.post
HttpClient.put = HttpClient.put
HttpClient.patch = HttpClient.patch
HttpClient.delete = HttpClient.delete
HttpClient.head = HttpClient.head
HttpClient.options = HttpClient.options
HttpClient.json = HttpClient.json
HttpClient.form = HttpClient.form
HttpClient.download = HttpClient.download
HttpClient.set_timeout = HttpClient.set_timeout

return HttpClient
