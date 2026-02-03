local BaseController = require('app.core.Controller')
local Middleware = require('app.middleware')

local MiddlewareDemo = {}
setmetatable(MiddlewareDemo, { __index = BaseController })

function MiddlewareDemo:index()
    local list = Middleware:list()

    self:json({
        success = true,
        message = 'Middleware System',
        description = 'Lightweight middleware based on OpenResty phases',
        phases = {
            'init', 'init_worker', 'set', 'rewrite', 'access',
            'content', 'header_filter', 'body_filter', 'log'
        },
        available_middleware = {
            'auth', 'cors', 'logger', 'rate_limit'
        },
        loaded_middleware = list,
        usage = {
            nginx_config = 'Phases handled via nginx.conf',
            config_location = 'app/config/config.lua middleware section',
            middleware_files = 'app/middleware/*.lua'
        }
    })
end

function MiddlewareDemo:list()
    local list = Middleware:list()

    self:json({
        success = true,
        message = 'Loaded middleware list',
        count = #list,
        middleware = list
    })
end

function MiddlewareDemo:info()
    local request_id = ngx.var.request_id or 'N/A'

    self:json({
        success = true,
        message = 'Middleware info',
        request = {
            id = request_id,
            method = ngx.var.request_method,
            uri = ngx.var.uri,
            ip = ngx.var.remote_addr,
            user_agent = ngx.var.http_user_agent
        },
        auth = {
            user_id = ngx.ctx.auth_user,
            user_role = ngx.ctx.auth_data and ngx.ctx.auth_data.role,
            auth_type = ngx.ctx.auth_type
        },
        timing = {
            start_time = ngx.ctx.request_start
        }
    })
end

function MiddlewareDemo:auth_test()
    local Session = require('app.lib.session')
    local session = Session:new()

    local user_id = session:get('user_id')
    if not user_id then
        return self:json({
            success = false,
            error = 'Not logged in',
            message = 'Please login first'
        }, 401)
    end

    self:json({
        success = true,
        message = 'Authenticated request',
        user = {
            id = user_id,
            username = session:get('username'),
            email = session:get('email'),
            role = session:get('role')
        }
    })
end

function MiddlewareDemo:login()
    local email = self:post('email')
    local password = self:post('password')

    if not email or not password then
        return self:json({
            success = false,
            error = 'Missing credentials',
            message = 'Email and password required'
        }, 400)
    end

    -- 模拟登录验证
    if email == 'admin@example.com' and password == 'password123' then
        local Session = require('app.lib.session')
        local session = Session:new()

        session:set('user_id', 1)
        session:set('username', 'admin')
        session:set('email', email)
        session:set('role', 'admin')
        session:save()

        return self:json({
            success = true,
            message = 'Login successful',
            user = {
                id = 1,
                username = 'admin',
                email = email,
                role = 'admin'
            },
            request_id = ngx.var.request_id
        })
    end

    return self:json({
        success = false,
        error = 'Invalid credentials'
    }, 401)
end

function MiddlewareDemo:logout()
    local Session = require('app.lib.session')
    local session = Session:new()
    session:destroy()

    self:json({
        success = true,
        message = 'Logged out successfully'
    })
end

function MiddlewareDemo:cors_test()
    local CORS = require('app.middleware.cors')
    CORS:setup():handle()

    self:json({
        success = true,
        message = 'CORS headers set',
        headers = {
            ['Access-Control-Allow-Origin'] = ngx.header['Access-Control-Allow-Origin'],
            ['Access-Control-Allow-Methods'] = ngx.header['Access-Control-Allow-Methods'],
            ['Access-Control-Allow-Headers'] = ngx.header['Access-Control-Allow-Headers']
        }
    })
end

function MiddlewareDemo:rate_limit_test()
    local RateLimit = require('app.middleware.rate_limit')
    RateLimit:setup():handle({
        zone = 'api',
        headers = true,
        log_blocked = true
    })

    self:json({
        success = true,
        message = 'Rate limit check passed',
        rate_limit = {
            limit = ngx.header['X-RateLimit-Limit'],
            remaining = ngx.header['X-RateLimit-Remaining'],
            reset = ngx.header['X-RateLimit-Reset']
        }
    })
end

function MiddlewareDemo:headers()
    self:json({
        success = true,
        message = 'Response headers',
        request_headers = {
            ['X-Request-ID'] = ngx.var.http_x_request_id,
            ['X-Forwarded-For'] = ngx.var.http_x_forwarded_for,
            ['User-Agent'] = ngx.var.http_user_agent,
            ['Referer'] = ngx.var.http_referer
        },
        response_headers = {
            ['X-Request-ID'] = ngx.header['X-Request-ID']
        }
    })
end

return MiddlewareDemo
