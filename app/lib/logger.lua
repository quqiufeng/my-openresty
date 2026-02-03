local ffi = require("ffi")
local C = ffi.C

ffi.cdef[[
    int access(const char *pathname, int mode);
    int mkdir(const char *pathname, mode_t mode);
    int rename(const char *oldpath, const char *newpath);
    int stat(const char *pathname, void *buf);
    typedef unsigned long ino_t;
    typedef unsigned long dev_t;
    typedef long off_t;
    typedef unsigned int mode_t;
    typedef unsigned int nlink_t;
    typedef unsigned int uid_t;
    typedef unsigned int gid_t;
    typedef long blksize_t;
    typedef long blkcnt_t;
    typedef struct timespec { long tv_sec; long tv_nsec; } timespec;
    typedef struct stat {
        dev_t st_dev;
        ino_t st_ino;
        mode_t st_mode;
        nlink_t st_nlink;
        uid_t st_uid;
        gid_t st_gid;
        dev_t st_rdev;
        off_t st_size;
        blksize_t st_blksize;
        blkcnt_t st_blocks;
        timespec st_atim;
        timespec st_mtim;
        timespec st_ctim;
    } struct_stat;
]]

local F_OK = 0
local R_OK = 4
local W_OK = 2
local X_OK = 1

local function file_exists(path)
    return C.access(path, F_OK) == 0
end

local function get_file_size(path)
    local stat_buf = ffi.new("struct_stat")
    local result = C.stat(path, stat_buf)
    if result ~= 0 then
        return 0
    end
    return tonumber(stat_buf.st_size)
end

local Logger = {}

Logger.LEVELS = {
    DEBUG = 1,
    INFO = 2,
    WARNING = 3,
    ERROR = 4,
    CRITICAL = 5,
    OFF = 100
}

Logger.LEVEL_NAMES = {
    [1] = "DEBUG",
    [2] = "INFO",
    [3] = "WARNING",
    [4] = "ERROR",
    [5] = "CRITICAL"
}

local function get_level_name(level)
    return Logger.LEVEL_NAMES[level] or "UNKNOWN"
end

local function format_message(level, message, context)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local level_name = get_level_name(level)
    local formatted = string.format("[%s] [%s] %s", timestamp, level_name, message)

    if context and type(context) == "table" then
        local context_str = {}
        for k, v in pairs(context) do
            table.insert(context_str, string.format("%s=%s", k, tostring(v)))
        end
        if #context_str > 0 then
            formatted = formatted .. " | " .. table.concat(context_str, " ")
        end
    end

    return formatted
end

function Logger:new(config)
    config = config or {}
    local instance = {
        level = config.level or Logger.LEVELS.INFO,
        handlers = config.handlers or {},
        log_dir = config.log_dir or "logs",
        max_size = config.max_size or 10485760,
        max_files = config.max_files or 5,
        async = config.async ~= false
    }

    if not instance.handlers.file and instance.log_dir then
        instance.handlers.file = true
    end

    if not instance.handlers.console then
        instance.handlers.console = true
    end

    setmetatable(instance, { __index = Logger })
    instance:init()

    return instance
end

function Logger:init()
    if self.handlers.file then
        if not file_exists(self.log_dir) then
            local ok = C.mkdir(self.log_dir, 493) 
            if ok ~= 0 then
                ngx.log(ngx.WARN, "Logger: failed to create log directory: " .. self.log_dir)
                self.handlers.file = false
            end
        end
    end
end

function Logger:should_log(level)
    return level >= self.level
end

function Logger:write_to_console(message, level)
    local ngx_level = ngx.INFO
    if level == Logger.LEVELS.DEBUG then
        ngx_level = ngx.DEBUG
    elseif level == Logger.LEVELS.WARNING then
        ngx_level = ngx.WARN
    elseif level == Logger.LEVELS.ERROR or level == Logger.LEVELS.CRITICAL then
        ngx_level = ngx.ERR
    end
    ngx.log(ngx_level, message)
end

function Logger:get_log_file_path(filename)
    return self.log_dir .. "/" .. filename
end

function Logger:rotate_log(filename)
    local base_path = self:get_log_file_path(filename)
    local ext = ".old"

    for i = self.max_files - 1, 1, -1 do
        local old_file = string.format("%s.%d%s", base_path, i, ext)
        local new_file = string.format("%s.%d%s", base_path, i + 1, ext)

        if file_exists(old_file) then
            C.rename(old_file, new_file)
        end
    end

    local current_file = base_path .. ext
    if file_exists(base_path) then
        C.rename(base_path, current_file)
    end
end

function Logger:write_to_file(message, filename)
    local filepath = self:get_log_file_path(filename)

    if file_exists(filepath) then
        local size = get_file_size(filepath)
        if size > self.max_size then
            self:rotate_log(filename)
        end
    end

    local file, err = io.open(filepath, "a")
    if not file then
        ngx.log(ngx.ERR, "Logger: failed to open log file: " .. tostring(err))
        return
    end

    file:write(message .. "\n")
    file:flush()
    file:close()
end

function Logger:log(level, message, context)
    if not self:should_log(level) then
        return
    end

    local formatted = format_message(level, message, context)

    if self.handlers.console then
        self:write_to_console(formatted, level)
    end

    if self.handlers.file then
        local filename = "app.log"
        if level >= Logger.LEVELS.ERROR then
            filename = "error.log"
        elseif level == Logger.LEVELS.WARNING then
            filename = "warning.log"
        end

        if self.async then
            ngx.timer.at(0, function()
                self:write_to_file(formatted, filename)
            end)
        else
            self:write_to_file(formatted, filename)
        end
    end
end

function Logger:debug(message, context)
    self:log(Logger.LEVELS.DEBUG, message, context)
end

function Logger:info(message, context)
    self:log(Logger.LEVELS.INFO, message, context)
end

function Logger:warning(message, context)
    self:log(Logger.LEVELS.WARNING, message, context)
end

function Logger:error(message, context)
    self:log(Logger.LEVELS.ERROR, message, context)
end

function Logger:critical(message, context)
    self:log(Logger.LEVELS.CRITICAL, message, context)
end

function Logger:measure(name, func, ...)
    local start_time = ngx.now()
    local result = { pcall(func, ...) }
    local end_time = ngx.now()
    local duration = end_time - start_time

    if result[1] then
        table.remove(result, 1)
        self:info(string.format("[%s] completed in %.4f seconds", name, duration))
        return unpack(result)
    else
        self:error(string.format("[%s] failed after %.4f seconds: %s", name, duration, tostring(result[2])))
        error(result[2])
    end
end

function Logger:measure_async(name, func, ...)
    local start_time = ngx.now()
    local results = { func(...) }
    local end_time = ngx.now()
    local duration = end_time - start_time

    self:info(string.format("[%s] async completed in %.4f seconds", name, duration))
    return unpack(results)
end

function Logger:get_recent_logs(lines, filename)
    lines = lines or 100
    filename = filename or "app.log"
    local filepath = self:get_log_file_path(filename)

    local file, err = io.open(filepath, "r")
    if not file then
        return nil, "Failed to open log file: " .. tostring(err)
    end

    local all_lines = {}
    for line in file:lines() do
        table.insert(all_lines, line)
    end
    file:close()

    local start = math.max(1, #all_lines - lines + 1)
    local result = {}
    for i = start, #all_lines do
        table.insert(result, all_lines[i])
    end

    return result
end

function Logger:clear_logs(filename)
    filename = filename or "app.log"
    local filepath = self:get_log_file_path(filename)

    local file, err = io.open(filepath, "w")
    if not file then
        return false, "Failed to clear log file: " .. tostring(err)
    end
    file:close()

    return true
end

function Logger:get_log_stats(filename)
    filename = filename or "app.log"
    local filepath = self:get_log_file_path(filename)

    local stats = {
        size = 0,
        lines = 0,
        levels = {
            DEBUG = 0,
            INFO = 0,
            WARNING = 0,
            ERROR = 0,
            CRITICAL = 0
        }
    }

    if not file_exists(filepath) then
        return stats
    end

    local file = io.open(filepath, "r")
    if not file then
        return stats
    end

    stats.size = get_file_size(filepath)

    for line in file:lines() do
        stats.lines = stats.lines + 1
        if string.find(line, "%[DEBUG%]") then
            stats.levels.DEBUG = stats.levels.DEBUG + 1
        elseif string.find(line, "%[INFO%]") then
            stats.levels.INFO = stats.levels.INFO + 1
        elseif string.find(line, "%[WARNING%]") then
            stats.levels.WARNING = stats.levels.WARNING + 1
        elseif string.find(line, "%[ERROR%]") then
            stats.levels.ERROR = stats.levels.ERROR + 1
        elseif string.find(line, "%[CRITICAL%]") then
            stats.levels.CRITICAL = stats.levels.CRITICAL + 1
        end
    end

    file:close()
    return stats
end

return Logger
