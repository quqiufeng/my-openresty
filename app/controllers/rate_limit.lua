local BaseController = require('app.core.Controller')
local Limit = require('app.lib.limit')

local RateLimit = {}
setmetatable(RateLimit, { __index = BaseController })

function RateLimit:index()
    local Loader = require('app.core.Loader')
    local limit = Loader:library('limit')

    self:json({
        success = true,
        message = 'Rate Limit API',
        endpoints = {
            'GET /rate-limit - This info',
            'GET /rate-limit/test - Test rate limiting',
            'GET /rate-limit/status - Check current limits',
            'POST /rate-limit/check - Check specific limit',
            'POST /rate-limit/zone - Check zone limit',
            'GET /rate-limit/keys - List all keys',
            'POST /rate-limit/reset - Reset counters',
            'GET /rate-limit/login - Login rate limit demo',
            'GET /rate-limit/api - API rate limit demo'
        }
    })
end

function RateLimit:test()
    local Loader = require('app.core.Loader')
    local limit = Loader:library('limit')

    local route = "/rate-limit/test"
    local success, info = limit:check(nil, route, 5, 60, 2)

    limit:set_headers(info)

    self:json({
        success = success,
        message = success and 'Request allowed' or 'Rate limit exceeded',
        limit_info = info
    }, success and 200 or 429)
end

function RateLimit:status()
    local Loader = require('app.core.Loader')
    local limit = Loader:library('limit')

    local ip = self:ip_address()
    local success, info = limit:check(ip, "/status", 10, 60, 0)

    limit:set_headers(info)

    self:json({
        success = true,
        your_ip = ip,
        limit_info = info
    })
end

function RateLimit:check()
    local Loader = require('app.core.Loader')
    local limit = Loader:library('limit')

    local limit_count = tonumber(self:post('limit')) or 10
    local window_sec = tonumber(self:post('window')) or 60
    local burst = tonumber(self:post('burst')) or 0
    local identifier = self:post('identifier') or self:ip_address()
    local route = self:post('route') or "/custom"

    local success, info = limit:check(identifier, route, limit_count, window_sec, burst)

    limit:set_headers(info)

    self:json({
        success = success,
        message = success and 'Request allowed' or 'Rate limit exceeded',
        request_params = {
            identifier = identifier,
            route = route,
            limit = limit_count,
            window = window_sec,
            burst = burst
        },
        limit_info = info
    }, success and 200 or 429)
end

function RateLimit:zone()
    local Loader = require('app.core.Loader')
    local limit = Loader:library('limit')

    local zone_name = self:get('zone') or 'default'

    local zone = limit.zones and limit.zones[zone_name]
    if not zone then
        self:json({
            success = false,
            message = 'Zone not found',
            available_zones = { 'api', 'login', 'upload', 'default' }
        }, 400)
        return
    end

    limit:create_zone(zone_name, zone.limit, zone.window, zone.burst)

    local success, info = limit:check_zone(zone_name, self:ip_address())

    limit:set_headers(info)

    self:json({
        success = success,
        message = success and 'Request allowed' or 'Rate limit exceeded',
        zone = zone_name,
        zone_config = zone,
        limit_info = info
    }, success and 200 or 429)
end

function RateLimit:keys()
    local Loader = require('app.core.Loader')
    local limit = Loader:library('limit')

    local keys = limit:get_all_keys()

    local stats = {}
    for _, key in ipairs(keys) do
        stats[key] = limit:get_stats(key)
    end

    self:json({
        success = true,
        keys = keys,
        stats = stats
    })
end

function RateLimit:reset()
    local Loader = require('app.core.Loader')
    local limit = Loader:library('limit')

    local key = self:post('key')

    if key then
        limit:reset(key)
        self:json({
            success = true,
            message = 'Key reset: ' .. key
        })
    else
        limit:reset_all()
        self:json({
            success = true,
            message = 'All rate limits reset'
        })
    end
end

function RateLimit:login()
    local Loader = require('app.core.Loader')
    local limit = Loader:library('limit')

    limit:create_zone('login', 5, 300, 0)

    local success, info = limit:check_zone('login', self:ip_address())

    limit:set_headers(info)

    if success then
        self:json({
            success = true,
            message = 'Login attempt allowed',
            remaining_attempts = info.remaining,
            reset_time = info.reset
        })
    else
        self:json({
            success = false,
            error = 'Too many login attempts',
            message = 'Please wait ' .. info.reset .. ' seconds before trying again',
            retry_after = info.reset
        }, 429)
    end
end

function RateLimit:api()
    local Loader = require('app.core.Loader')
    local limit = Loader:library('limit')

    limit:create_zone('api', 60, 60, 10)

    local success, info = limit:check_zone('api', self:ip_address())

    limit:set_headers(info)

    self:json({
        success = true,
        message = 'API request successful',
        limit_info = info
    })
end

function RateLimit:strict()
    local Loader = require('app.core.Loader')
    local limit = Loader:library('limit')

    local success, info = limit:check(nil, "/strict", 3, 60, 0)

    limit:set_headers(info)

    if not success then
        self:json({
            success = false,
            error = 'Rate limit exceeded',
            message = 'Maximum 3 requests per minute',
            limit_info = info
        }, 429)
    else
        self:json({
            success = true,
            message = 'Strict rate limit test passed',
            limit_info = info
        })
    end
end

function RateLimit:combined()
    local Loader = require('app.core.Loader')
    local limit = Loader:library('limit')

    local success, info = limit:check_combined("/combined", 10, 60)

    limit:set_headers(info)

    self:json({
        success = success,
        message = success and 'Combined limit check passed' or 'Combined limit exceeded',
        ip = self:ip_address(),
        limit_info = info
    }, success and 200 or 429)
end

function RateLimit:user()
    local Loader = require('app.core.Loader')
    local limit = Loader:library('limit')

    local user_id = self:get('user_id') or 'user_123'

    local success, info = limit:check_user(user_id, "/user-endpoint", 20, 60)

    limit:set_headers(info)

    self:json({
        success = success,
        user_id = user_id,
        limit_info = info
    }, success and 200 or 429)
end

return RateLimit
