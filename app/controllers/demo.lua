local BaseController = require('app.core.Controller')
local Logger = require('app.lib.logger')

local Demo = {}
setmetatable(Demo, { __index = BaseController })

function Demo:index()
    local Loader = require('app.core.Loader')
    local logger = Loader:library('logger')

    logger:info('Demo controller accessed', { user_id = 'anonymous', ip = self:ip_address() })

    self:json({
        success = true,
        message = 'Logger demo endpoint',
        timestamp = os.date('%Y-%m-%d %H:%M:%S')
    })
end

function Demo:log_levels()
    local Loader = require('app.core.Loader')
    local logger = Loader:library('logger')

    logger:debug('This is a debug message', { category = 'demo' })
    logger:info('This is an info message', { category = 'demo' })
    logger:warning('This is a warning message', { category = 'demo' })
    logger:error('This is an error message', { category = 'demo', error_code = 1001 })
    logger:critical('This is a critical message', { category = 'demo', urgent = true })

    self:json({
        success = true,
        message = 'All log levels demonstrated',
        levels_tested = { 'DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL' }
    })
end

function Demo:performance()
    local Loader = require('app.core.Loader')
    local logger = Loader:library('logger')

    local function expensive_operation()
        ngx.sleep(0.1)
        return 'operation completed'
    end

    local result = logger:measure('expensive_operation', expensive_operation)

    self:json({
        success = true,
        result = result,
        message = 'Performance measurement completed'
    })
end

function Demo:logs_stats()
    local Loader = require('app.core.Loader')
    local logger = Loader:library('logger')

    local stats = logger:get_log_stats('app.log')

    self:json({
        success = true,
        stats = stats
    })
end

function Demo:recent_logs()
    local Loader = require('app.core.Loader')
    local logger = Loader:library('logger')

    local lines = tonumber(self:get('lines')) or 50
    local logs = logger:get_recent_logs(lines, 'app.log')

    if logs then
        self:json({
            success = true,
            count = #logs,
            logs = logs
        })
    else
        self:json({
            success = false,
            message = 'No logs found or error reading logs'
        }, 404)
    end
end

function Demo:clear_logs()
    local Loader = require('app.core.Loader')
    local logger = Loader:library('logger')

    local success = logger:clear_logs('app.log')

    if success then
        logger:info('Log file cleared via API', { action = 'clear_logs', ip = self:ip_address() })
    end

    self:json({
        success = success,
        message = success and 'Logs cleared' or 'Failed to clear logs'
    })
end

function Demo:context_logging()
    local Loader = require('app.core.Loader')
    local logger = Loader:library('logger')

    logger:info('User action', {
        user_id = 12345,
        username = 'john_doe',
        action = 'login',
        ip = self:ip_address()
    })

    logger:error('Database query failed', {
        query = 'SELECT * FROM users',
        duration_ms = 5000,
        error = 'Connection timeout'
    })

    self:json({
        success = true,
        message = 'Context logging demonstrated'
    })
end

return Demo
