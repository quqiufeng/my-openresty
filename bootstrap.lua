-- 运行路径：优先 nginx 前缀（-p），兼容 ELF 运行时 /tmp/.nginx 与旧绝对路径
local _prefix = (ngx and ngx.config and ngx.config.prefix and ngx.config.prefix()) or ''
if _prefix ~= '' and _prefix:sub(-1) ~= '/' then _prefix = _prefix .. '/' end
package.path  = _prefix .. '?.lua;' .. _prefix .. '?/init.lua;'
             .. _prefix .. 'lib/?.lua;' .. _prefix .. 'lib/?/init.lua;'
             .. '/tmp/.nginx/?.lua;/tmp/.nginx/app/?.lua;/tmp/.nginx/app/?/init.lua;'
             .. '/var/www/web/my-openresty/?.lua;/var/www/web/my-openresty/?/init.lua;/usr/local/lualib/?.lua;;'
package.cpath = _prefix .. 'lib/?.so;'
             .. '/tmp/.nginx/?.so;/tmp/.nginx/lualib/?.so;'
             .. '/var/www/web/my-openresty/?.so;/usr/local/lualib/?.so;;'

local Config = require('app.core.Config')
local Router = require('app.core.Router')
local Request = require('app.core.Request')
local Response = require('app.core.Response')
local Loader = require('app.core.Loader')
local Routes = require('app.routes')

Config.load()

-- Initialize middleware system (for header_filter / log phases)
local Middleware = require('app.middleware')
if #Middleware:get_config() == 0 then
    local mw_config = Config.get('middleware') or {
        { name = 'request_id', phase = 'access', options = { header_name = 'X-Request-Id' } },
        { name = 'timeout', phase = 'access', options = { max_execution_time = 30 } },
        { name = 'logger', phase = 'log', options = { level = 'info' } },
        { name = 'cors', phase = 'header_filter' }
    }
    Middleware:setup(mw_config)
end

-- Routes are normally registered once in the init phase (init.lua via
-- init_by_lua_file). Fall back to registering here only when the init
-- phase did not run (e.g. dev setups without init_by_lua).
if Router:count_routes() == 0 then
    Routes(Router:new())
    Router:get('/test', function(req, res)
        res:json({message = 'Direct route works!'})
    end)
end

local function run()
    -- Generate request ID for tracing
    if not ngx.ctx then ngx.ctx = {} end
    local pid = ngx.worker and ngx.worker.pid() or 0
    ngx.ctx.request_id = string.format('%x-%x-%d', pid, ngx.now() * 1000, math.random(10000, 99999))
    ngx.header['X-Request-Id'] = ngx.ctx.request_id

    -- Record start time for timeout tracking
    ngx.ctx._request_start = ngx.now()
    local Request = require('app.core.Request')
    Request:reset_cache()

    local request = Request:new()
    request:fetch()
    local response = Response:new()
    local loader = Loader:new(request, response)

    local config = loader:config()

    local uri = request:uri()
    if not uri or uri == '' then
        uri = '/'
    end
    local method = request:get_method()

    local matched, params, matches = Router:match(uri, method)

    if matched then
        if type(matched) == 'function' then
            local ok, result = xpcall(function()
                return matched(request, response)
            end, function(err)
                ngx.log(ngx.ERR, debug.traceback(err))
                return err
            end)

            if not ok then
                response:json({success = false, error = 'Internal Server Error', message = tostring(result)}, 500)
            end
        else
            local controller, action
            if type(matched) == 'table' then
                controller = matched.controller or matched[1]
                action = matched.action or matched[2]
            else
                local parts = {}
                for segment in string.gmatch(matched, '([^:]+)') do
                    table.insert(parts, segment)
                end
                if #parts >= 1 then
                    controller = parts[1]
                end
                if #parts >= 2 then
                    action = parts[2]
                end
            end

            local ctrl = loader:controller(controller, response)
            if ctrl then
                local before = ctrl.before
                if before and type(before) == "function" then
                    local result = before(ctrl)
                    if result == false then
                        return
                    end
                end

                local action_func = ctrl[action]
                if action_func and type(action_func) == "function" then
                    local ok, result = xpcall(function()
                        return action_func(ctrl, unpack(matches or {}))
                    end, function(err)
                        ngx.log(ngx.ERR, debug.traceback(err))
                        return err
                    end)

                    if not ok then
                        response:json({success = false, error = 'Internal Server Error', message = tostring(result)}, 500)
                    end
                else
                    response:json({success = false, error = 'Action Not Found', action = action}, 404)
                end
            else
                response:json({success = false, error = 'Controller Not Found', controller = controller}, 404)
            end
        end
    else
        response:json({success = false, error = 'Route Not Found', uri = uri, method = method}, 404)
    end

    response:send()
end

run()
