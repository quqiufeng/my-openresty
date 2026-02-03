local _M = {}

local function get_shared_dict()
    return ngx.shared.my_resty_cache
end

function _M.new(options)
    options = options or {}

    local self = {
        dict_name = options.dict_name or 'my_resty_cache',
        default_ttl = options.default_ttl or 3600,
        prefix = options.prefix or 'cache:'
    }

    setmetatable(self, {__index = _M})

    return self
end

function _M.get(self, key)
    local dict = get_shared_dict()
    if not dict then return nil, 'Shared dict not available' end

    local prefixed_key = self.prefix .. key
    local value = dict:get(prefixed_key)

    return value
end

function _M.get_multi(self, ...)
    local dict = get_shared_dict()
    if not dict then return nil, 'Shared dict not available' end

    local keys = {...}
    local result = {}

    for _, key in ipairs(keys) do
        local prefixed_key = self.prefix .. key
        local value = dict:get(prefixed_key)
        result[key] = value
    end

    return result
end

function _M.set(self, key, value, ttl)
    local dict = get_shared_dict()
    if not dict then return nil, 'Shared dict not available' end

    local prefixed_key = self.prefix .. key
    local expire = ttl or self.default_ttl

    local ok, err = dict:set(prefixed_key, value, expire)
    if not ok then
        return nil, err
    end

    return true
end

function _M.add(self, key, value, ttl)
    local dict = get_shared_dict()
    if not dict then return nil, 'Shared dict not available' end

    local prefixed_key = self.prefix .. key
    local expire = ttl or self.default_ttl

    local ok, err = dict:add(prefixed_key, value, expire)
    if not ok then
        return nil, err
    end

    return true
end

function _M.replace(self, key, value, ttl)
    local dict = get_shared_dict()
    if not dict then return nil, 'Shared dict not available' end

    local prefixed_key = self.prefix .. key
    local expire = ttl or self.default_ttl

    local ok, err = dict:replace(prefixed_key, value, expire)
    if not ok then
        return nil, err
    end

    return true
end

function _M.delete(self, key)
    local dict = get_shared_dict()
    if not dict then return nil, 'Shared dict not available' end

    local prefixed_key = self.prefix .. key
    dict:delete(prefixed_key)

    return true
end

function _M.delete_multi(self, ...)
    local dict = get_shared_dict()
    if not dict then return nil, 'Shared dict not available' end

    local keys = {...}
    for _, key in ipairs(keys) do
        local prefixed_key = self.prefix .. key
        dict:delete(prefixed_key)
    end

    return true
end

function _M.delete_all(self)
    local dict = get_shared_dict()
    if not dict then return nil, 'Shared dict not available' end

    dict:flush_all()

    return true
end

function _M.delete_expired(self)
    local dict = get_shared_dict()
    if not dict then return nil, 'Shared dict not available' end

    dict:flush_expired()

    return true
end

function _M.exists(self, key)
    local dict = get_shared_dict()
    if not dict then return false end

    local prefixed_key = self.prefix .. key
    local value = dict:get(prefixed_key)

    return value ~= nil
end

function _M.get_ttl(self, key)
    local dict = get_shared_dict()
    if not dict then return nil, 'Shared dict not available' end

    local prefixed_key = self.prefix .. key
    local ttl = dict:ttl(prefixed_key)

    return ttl
end

function _M.expire(self, key, ttl)
    local dict = get_shared_dict()
    if not dict then return nil, 'Shared dict not available' end

    local prefixed_key = self.prefix .. key
    local value = dict:get(prefixed_key)

    if value then
        dict:delete(prefixed_key)
        dict:set(prefixed_key, value, ttl)
        return true
    end

    return nil, 'Key not found'
end

function _M.incr(self, key, step)
    local dict = get_shared_dict()
    if not dict then return nil, 'Shared dict not available' end

    local prefixed_key = self.prefix .. key
    local ok, err = dict:incr(prefixed_key, step or 1)

    if not ok then
        return nil, err
    end

    return ok
end

function _M.decr(self, key, step)
    local dict = get_shared_dict()
    if not dict then return nil, 'Shared dict not available' end

    local prefixed_key = self.prefix .. key
    local current = dict:get(prefixed_key)

    if not current then
        return nil, 'Key not found'
    end

    local new_value = current - (step or 1)
    dict:set(prefixed_key, new_value)

    return new_value
end

local function get_lock(self, key)
    local dict = get_shared_dict()
    if not dict then return nil end

    local lock_key = 'lock:' .. self.prefix .. key
    local Lock = require('resty.lock')
    local lock = Lock:new(dict, {
        exptime = 30,
        timeout = 5
    })

    return lock, lock_key
end

function _M.get_or_set(self, key, callback, ttl)
    local dict = get_shared_dict()
    if not dict then return nil, 'Shared dict not available' end

    local prefixed_key = self.prefix .. key
    local value = dict:get(prefixed_key)

    if value ~= nil then
        return value
    end

    local lock, lock_key = get_lock(self, key)
    if not lock then
        local success, new_value = pcall(callback)
        if success and new_value ~= nil then
            self:set(key, new_value, ttl)
        end
        return new_value
    end

    local elapsed, err = lock:lock(lock_key)

    if not elapsed then
        local success, new_value = pcall(callback)
        if success and new_value ~= nil then
            self:set(key, new_value, ttl)
        end
        return new_value
    end

    value = dict:get(prefixed_key)
    if value ~= nil then
        lock:unlock()
        return value
    end

    local success, new_value = pcall(callback)

    if success and new_value ~= nil then
        local expire = ttl or self.default_ttl
        dict:set(prefixed_key, new_value, expire)
    end

    lock:unlock()

    if success then
        return new_value
    else
        return nil, new_value
    end
end

function _M.get_or_set_multi(self, keys, callback, ttl)
    local dict = get_shared_dict()
    if not dict then return nil, 'Shared dict not available' end

    local result = {}

    for _, key in ipairs(keys) do
        local prefixed_key = self.prefix .. key
        local value = dict:get(prefixed_key)
        result[key] = value
    end

    local missing_keys = {}
    for _, key in ipairs(keys) do
        if result[key] == nil then
            table.insert(missing_keys, key)
        end
    end

    if #missing_keys == 0 then
        return result
    end

    local acquired_locks = {}
    local all_acquired = true

    for _, key in ipairs(missing_keys) do
        local lock, lock_key = get_lock(self, key)
        if not lock then
            all_acquired = false
            break
        end

        local elapsed, err = lock:lock(lock_key)
        if elapsed then
            table.insert(acquired_locks, {lock = lock, key = lock_key})
        else
            all_acquired = false
            break
        end
    end

    if not all_acquired then
        for _, item in ipairs(acquired_locks) do
            item.lock:unlock()
        end

        for _, key in ipairs(missing_keys) do
            local prefixed_key = self.prefix .. key
            local value = dict:get(prefixed_key)
            result[key] = value
        end

        return result
    end

    local callback_result = callback(missing_keys)

    for i, key in ipairs(missing_keys) do
        local value = callback_result and callback_result[key]
        if value ~= nil then
            local expire = ttl or self.default_ttl
            dict:set(self.prefix .. key, value, expire)
        end
        result[key] = value
    end

    for _, item in ipairs(acquired_locks) do
        item.lock:unlock()
    end

    return result
end

function _M.clear_prefix(self, prefix)
    local dict = get_shared_dict()
    if not dict then return nil, 'Shared dict not available' end

    local keys = self:keys()
    for _, key in ipairs(keys) do
        if key:sub(1, #prefix) == prefix then
            self:delete(key)
        end
    end

    return true
end

function _M.keys(self)
    local dict = get_shared_dict()
    if not dict then return nil, 'Shared dict not available' end

    local keys = {}
    local prefix_len = #self.prefix

    for key, _ in dict:get_keys(0) do
        if key:sub(1, prefix_len) == self.prefix then
            local pure_key = key:sub(prefix_len + 1)
            if key:sub(1, 4) ~= 'lock' then
                table.insert(keys, pure_key)
            end
        end
    end

    return keys
end

function _M.values(self)
    local dict = get_shared_dict()
    if not dict then return nil, 'Shared dict not available' end

    local values = {}
    local prefix_len = #self.prefix

    for key, value in dict:get_keys(0) do
        if key:sub(1, prefix_len) == self.prefix then
            if key:sub(1, 4) ~= 'lock' then
                table.insert(values, value)
            end
        end
    end

    return values
end

function _M.count(self)
    local dict = get_shared_dict()
    if not dict then return 0 end

    local count = 0
    local prefix_len = #self.prefix

    for _, _ in dict:get_keys(0) do
        count = count + 1
    end

    return count
end

function _M.stats(self)
    local dict = get_shared_dict()
    if not dict then return nil end

    local info = {
        dict_name = self.dict_name,
        -- capacity 和 free_space 不是标准 API，使用可用信息
        items_count = self:count()
    }

    return info
end

function _M.remember(self, key, ttl, callback)
    local dict = get_shared_dict()
    if not dict then return nil, 'Shared dict not available' end

    local prefixed_key = self.prefix .. key
    local value = dict:get(prefixed_key)

    if value ~= nil then
        return value, false
    end

    local lock, lock_key = get_lock(self, key)
    if not lock then
        local success, new_value = pcall(callback)
        if success and new_value ~= nil then
            self:set(key, new_value, ttl)
        end
        return new_value, true
    end

    local elapsed, err = lock:lock(lock_key)

    if elapsed then
        value = dict:get(prefixed_key)
        if value ~= nil then
            lock:unlock()
            return value, false
        end

        local success, new_value = pcall(callback)

        if success and new_value ~= nil then
            local expire = ttl or self.default_ttl
            dict:set(prefixed_key, new_value, expire)
        end

        lock:unlock()

        if success then
            return new_value, true
        else
            return nil, new_value
        end
    end

    ngx.sleep(0.05)
    value = dict:get(prefixed_key)
    return value, false
end

function _M.memoize(self, fn, ttl)
    return function(...)
        local args = {...}
        local key = self:_serialize_args(args)

        local value = self:get(key)
        if value ~= nil then
            return unpack(value)
        end

        local lock, lock_key = get_lock(self, key)
        if not lock then
            local results = {fn(...)}
            self:set(key, results, ttl)
            return unpack(results)
        end

        local elapsed = lock:lock(lock_key)
        if not elapsed then
            local results = {fn(...)}
            self:set(key, results, ttl)
            return unpack(results)
        end

        value = self:get(key)
        if value == nil then
            local results = {fn(...)}
            self:set(key, results, ttl)
            lock:unlock()
            return unpack(results)
        end

        lock:unlock()
        return unpack(value)
    end
end

function _M._serialize_args(self, args)
    local parts = {}
    for i, arg in ipairs(args) do
        if type(arg) == 'table' then
            local ok, json_str = pcall(require('cjson').encode, arg)
            table.insert(parts, ok and json_str or tostring(arg))
        else
            table.insert(parts, tostring(arg))
        end
    end

    return table.concat(parts, ':')
end

function _M.tags(self, ...)
    local tags = {...}
    local self_prefix = self.prefix

    local tagged_cache = {
        tags = tags,
        prefix = self_prefix .. 'tag:',
        set = function(self, key, value, ttl)
            local Cache = require('app.lib.cache')
            local cache = Cache:new()

            for _, tag in ipairs(self.tags) do
                local tag_key = self.prefix .. tag .. ':' .. key
                cache:set(tag_key, os.time(), ttl or 86400)
            end

            local full_key = self_prefix .. key
            cache:set(full_key, value, ttl or 3600)
        end,
        get = function(self, key)
            local Cache = require('app.lib.cache')
            local cache = Cache:new()
            return cache:get(self_prefix .. key)
        end,
        invalidate = function(self, tag)
            local Cache = require('app.lib.cache')
            local cache = Cache:new()

            local tag_prefix = self.prefix .. tag .. ':'
            local get_keys_func = cache.get_keys
            local keys = {}
            if get_keys_func then
                local result = get_keys_func(cache, 0)
                if type(result) == "table" then
                    keys = result
                end
            end
            for key, _ in pairs(keys) do
                if key:sub(1, #tag_prefix) == tag_prefix then
                    cache:delete(key)
                end
            end
        end,
        invalidate_all = function(self)
            for _, tag in ipairs(self.tags) do
                self:invalidate(tag)
            end
        end
    }

    return tagged_cache
end

return _M
