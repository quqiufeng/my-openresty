local BaseController = require('app.core.Controller')
local Cache = require('app.lib.cache')

local CacheController = {}

function CacheController:index()
    local cache = Cache:new()
    local stats = cache:stats()

    return self:json({
        success = true,
        message = 'Cache API',
        endpoints = {
            ['GET /cache'] = 'Cache info and stats',
            ['POST /cache/set'] = 'Set cache value',
            ['GET /cache/get'] = 'Get cache value',
            ['POST /cache/delete'] = 'Delete cache key',
            ['POST /cache/clear'] = 'Clear all cache',
            ['POST /cache/incr'] = 'Increment value',
            ['POST /cache/decr'] = 'Decrement value',
            ['GET /cache/keys'] = 'List all keys',
            ['POST /cache/remember'] = 'Get or set with callback',
        },
        stats = stats
    })
end

function CacheController:set()
    local key = self.request.post and self.request.post.key
    local value = self.request.post and self.request.post.value
    local ttl = tonumber(self.request.post and self.request.post.ttl) or 3600

    if not key then
        return self:json({success = false, error = 'Key is required'}, 400)
    end

    local cache = Cache:new()
    local ok, err = cache:set(key, value, ttl)

    if ok then
        return self:json({
            success = true,
            message = 'Cache set successfully',
            key = key,
            value = value,
            ttl = ttl
        })
    else
        return self:json({success = false, error = err}, 500)
    end
end

function CacheController:get()
    local key = self.request.post and self.request.post.key
    if not key then
        key = self.request.get and self.request.get.key
    end

    if not key then
        return self:json({success = false, error = 'Key is required'}, 400)
    end

    local cache = Cache:new()
    local value = cache:get(key)

    if value == nil then
        return self:json({
            success = false,
            error = 'Key not found',
            key = key
        }, 404)
    end

    local ttl = cache:get_ttl(key)

    return self:json({
        success = true,
        key = key,
        value = value,
        ttl = ttl
    })
end

function CacheController:delete()
    local key = self.request.post and self.request.post.key

    if not key then
        return self:json({success = false, error = 'Key is required'}, 400)
    end

    local cache = Cache:new()
    local existed = cache:exists(key)
    cache:delete(key)

    return self:json({
        success = true,
        message = existed and 'Key deleted' or 'Key did not exist',
        key = key
    })
end

function CacheController:clear()
    local cache = Cache:new()
    cache:delete_all()

    return self:json({
        success = true,
        message = 'Cache cleared'
    })
end

function CacheController:incr()
    local key = self.request.post and self.request.post.key
    local step = tonumber(self.request.post and self.request.post.step) or 1

    if not key then
        return self:json({success = false, error = 'Key is required'}, 400)
    end

    local cache = Cache:new()
    local value, err = cache:incr(key, step)

    if not value then
        return self:json({success = false, error = err or 'Key not found or not numeric'}, 400)
    end

    return self:json({
        success = true,
        key = key,
        value = value
    })
end

function CacheController:decr()
    local key = self.request.post and self.request.post.key
    local step = tonumber(self.request.post and self.request.post.step) or 1

    if not key then
        return self:json({success = false, error = 'Key is required'}, 400)
    end

    local cache = Cache:new()
    local value = cache:decr(key, step)

    if not value then
        return self:json({success = false, error = 'Key not found'}, 400)
    end

    return self:json({
        success = true,
        key = key,
        value = value
    })
end

function CacheController:keys()
    local cache = Cache:new()
    local keys = cache:keys()

    return self:json({
        success = true,
        count = #keys,
        keys = keys
    })
end

function CacheController:remember()
    local key = self.request.post and self.request.post.key
    local ttl = tonumber(self.request.post and self.request.post.ttl) or 3600

    if not key then
        return self:json({success = false, error = 'Key is required'}, 400)
    end

    local cache = Cache:new()

    local value, created = cache:remember(key, ttl, function()
        return 'cached_value_' .. os.time()
    end)

    return self:json({
        success = true,
        key = key,
        value = value,
        created = created
    })
end

function CacheController:stats()
    local cache = Cache:new()
    local stats = cache:stats()

    return self:json({
        success = true,
        stats = stats
    })
end

function CacheController:userData()
    local user_id = tonumber(self.request.get and self.request.get.user_id) or 1

    local cache = Cache:new()
    local user_key = 'user:' .. user_id

    local user_data = cache:get_or_set(user_key, function()
        ngx.log(ngx.INFO, 'Cache miss, fetching from DB for user: ', user_id)

        return {
            id = user_id,
            name = 'User ' .. user_id,
            email = 'user' .. user_id .. '@example.com',
            created_at = os.date('%Y-%m-%d %H:%M:%S')
        }
    end, 60)

    return self:json({
        success = true,
        source = 'cache',
        data = user_data
    })
end

function CacheController:invalidateUser()
    local user_id = tonumber(self.request.post and self.request.post.user_id)

    if not user_id then
        return self:json({success = false, error = 'user_id required'}, 400)
    end

    local cache = Cache:new()
    cache:delete('user:' .. user_id)

    return self:json({
        success = true,
        message = 'User cache invalidated',
        user_id = user_id
    })
end

function CacheController:pageView()
    local cache = Cache:new()
    local views_key = 'page_views:daily:' .. os.date('%Y%m%d')

    local views = cache:incr(views_key, 1)
    if views == 1 then
        cache:expire(views_key, 86400)
    end

    local ttl = cache:get_ttl(views_key)

    return self:json({
        success = true,
        date = os.date('%Y-%m-%d'),
        page_views = views,
        expires_in = ttl
    })
end

return CacheController
