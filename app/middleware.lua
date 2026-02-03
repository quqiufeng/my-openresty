local Middleware = {}

Middleware.PHASES = {
    INIT = 'init',
    INIT_WORKER = 'init_worker',
    SET = 'set',
    REWRITE = 'rewrite',
    ACCESS = 'access',
    CONTENT = 'content',
    HEADER_FILTER = 'header_filter',
    BODY_FILTER = 'body_filter',
    LOG = 'log'
}

local loaded_middleware = {}
local middleware_config = {}

local function load_middleware(name)
    if loaded_middleware[name] then
        return loaded_middleware[name]
    end

    local ok, mod = pcall(require, 'app.middleware.' .. name)
    if not ok then
        ngx.log(ngx.WARN, 'Middleware [' .. name .. '] not found: ' .. tostring(mod))
        return nil
    end

    loaded_middleware[name] = mod
    return mod
end

function Middleware:setup(config)
    middleware_config = config or {}

    for _, cfg in ipairs(middleware_config) do
        if cfg.enabled ~= false then
            local mod = load_middleware(cfg.name)
            if mod then
                ngx.log(ngx.INFO, 'Middleware [' .. cfg.name .. '] loaded, phase: ' .. (cfg.phase or 'access'))
            end
        end
    end
end

function Middleware:run(name, options)
    local mod = load_middleware(name)
    if not mod then
        return true
    end

    local handler = mod.handle or mod.run or mod.execute
    if not handler then
        return true
    end

    local ok, result = pcall(handler, mod, options or {})

    if not ok then
        ngx.log(ngx.ERR, 'Middleware [' .. name .. '] error: ' .. tostring(result))
        return false
    end

    if result == false then
        return false
    end

    return true
end

function Middleware:run_phase(phase, options)
    options = options or {}

    for _, cfg in ipairs(middleware_config) do
        if cfg.phase == phase then
            local should_run = true

            -- 检查路由匹配
            if cfg.routes and #cfg.routes > 0 then
                should_run = self:match_routes(cfg.routes)
            end

            -- 检查排除路由
            if cfg.exclude and #cfg.exclude > 0 then
                if self:match_routes(cfg.exclude) then
                    should_run = false
                end
            end

            if should_run then
                local result = self:run(cfg.name, cfg.options or options)
                if result == false then
                    return false
                end
            end
        end
    end

    return true
end

function Middleware:match_routes(routes)
    local uri = ngx.var.uri

    for _, route in ipairs(routes) do
        local pattern = string.gsub(route, '%*', '.*')
        if string.find(uri, '^' .. pattern .. '$') then
            return true
        end
    end

    return false
end

function Middleware:register(name, phase, handler, options)
    options = options or {}

    table.insert(middleware_config, {
        name = name,
        phase = phase,
        handler = handler,
        options = options,
        enabled = true
    })

    return self
end

function Middleware:disable(name)
    for _, cfg in ipairs(middleware_config) do
        if cfg.name == name then
            cfg.enabled = false
        end
    end
    return self
end

function Middleware:enable(name)
    for _, cfg in ipairs(middleware_config) do
        if cfg.name == name then
            cfg.enabled = true
        end
    end
    return self
end

function Middleware:get_config()
    return middleware_config
end

function Middleware:list()
    local list = {}
    for _, cfg in ipairs(middleware_config) do
        table.insert(list, {
            name = cfg.name,
            phase = cfg.phase,
            enabled = cfg.enabled,
            routes = cfg.routes or {},
            exclude = cfg.exclude or {}
        })
    end
    return list
end

function Middleware:clear()
    middleware_config = {}
    return self
end

function Middleware:require_middleware(name)
    return load_middleware(name)
end

function Middleware:create_handler(name, phase)
    return function()
        return self:run_phase(phase)
    end
end

return Middleware
