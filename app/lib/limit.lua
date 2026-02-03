local ffi = require("ffi")
local C = ffi.C

ffi.cdef[[
    int access(const char *pathname, int mode);
    int mkdir(const char *pathname, mode_t mode);
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
    
    struct lua_resty_limit_req_rec {
        unsigned long        excess;
        uint64_t             last;
    };
]]

local F_OK = 0

local ffi_cast = ffi.cast
local ffi_typeof = ffi.typeof
local ffi_sizeof = ffi.sizeof

local const_rec_ptr_type = ffi_typeof("const struct lua_resty_limit_req_rec*")
local rec_size = ffi_sizeof("struct lua_resty_limit_req_rec")

local rec_cdata = ffi.new("struct lua_resty_limit_req_rec")

local Limit = {}

Limit.STRATEGIES = {
    SLIDING_WINDOW = "sliding_window",
    FIXED_WINDOW = "fixed_window",
    TOKEN_BUCKET = "token_bucket",
    LEAKY_BUCKET = "leaky_bucket"
}

Limit.ACTIONS = {
    DENY = "deny",
    DROP = "drop",
    REDIRECT = "redirect"
}

local ngx_shared = ngx.shared
local ngx_now = ngx.now
local tonumber = tonumber
local type = type
local setmetatable = setmetatable
local math_max = math.max
local math_floor = math.floor

local ok, new_tab = pcall(require, "table.new")
if not ok then
    new_tab = function(narr, nrec) return {} end
end

local ok, tb_clear = pcall(require, "table.clear")
if not ok then
    tb_clear = function(tab)
        for k, _ in pairs(tab) do tab[k] = nil end
    end
end

local tab_pool_len = 0
local tab_pool = new_tab(16, 0)

local function _get_tab_from_pool()
    if tab_pool_len > 0 then
        tab_pool_len = tab_pool_len - 1
        return tab_pool[tab_pool_len + 1]
    end
    return new_tab(8, 0)
end

local function _put_tab_into_pool(tab)
    if tab_pool_len >= 32 then return end
    tb_clear(tab)
    tab_pool_len = tab_pool_len + 1
    tab_pool[tab_pool_len] = tab
end

function Limit:new(config)
    config = config or {}
    local instance = {
        dict_name = config.dict_name or "limit_dict",
        dict = nil,
        strategy = config.strategy or Limit.STRATEGIES.SLIDING_WINDOW,
        default_limit = config.default_limit or 100,
        default_window = config.default_window or 60,
        default_burst = config.default_burst or 0,
        action = config.action or Limit.ACTIONS.DENY,
        redirect_url = config.redirect_url or "/rate-limited",
        response_status = config.response_status or 429,
        response_message = config.response_message or "Too Many Requests",
        log_blocked = config.log_blocked ~= false,
        counters = {}
    }

    setmetatable(instance, { __index = Limit })
    instance:init()

    return instance
end

function Limit:init()
    local shared_dict = ngx_shared[self.dict_name]
    if not shared_dict then
        ngx.log(ngx.WARN, "Rate limit: shared dict '" .. self.dict_name .. "' not found, using in-memory fallback")
        self.dict = {}
    else
        self.dict = shared_dict
    end

    self.counters = {}
end

function Limit:ffi_incoming(self, key, rate, burst, commit)
    local dict = self.dict
    local now = ngx_now() * 1000

    local excess

    local v = dict:get(key)
    if v then
        if type(v) ~= "string" or #v ~= rec_size then
            return nil, "shdict abused by other users"
        end
        local rec = ffi_cast(const_rec_ptr_type, v)
        local elapsed = now - tonumber(rec.last)
        excess = math_max(tonumber(rec.excess) - rate * elapsed / 1000 + 1000, 0)
    else
        excess = 0
    end

    local total_excess = excess + 1000

    if total_excess > burst * 1000 then
        return false, excess / 1000, rate
    end

    if commit then
        rec_cdata.excess = total_excess
        rec_cdata.last = now
        dict:set(key, rec_cdata, 0)
    end

    return true, excess / 1000, rate
end

function Limit:get_key(key_type, identifier, route)
    if key_type == "ip" then
        return "limit:" .. ngx.var.remote_addr or "unknown"
    elseif key_type == "user" then
        return "limit:user:" .. identifier
    elseif key_type == "route" then
        return "limit:route:" .. route
    elseif key_type == "combined" then
        return "limit:combined:" .. (ngx.var.remote_addr or "unknown") .. ":" .. route
    end
    return "limit:" .. identifier
end

function Limit:get_time()
    return ngx.now() * 1000
end

function Limit:get_sliding_window_count(key, window)
    local now = self:get_time()
    local window_ms = window * 1000
    local start_time = now - window_ms

    local data = self.dict[key]
    if not data then
        return 0
    end

    if type(data) ~= "table" then
        return tonumber(data) or 0
    end

    local count = 0
    for _, timestamp in ipairs(data) do
        if timestamp >= start_time then
            count = count + 1
        end
    end

    return count
end

function Limit:add_request(key, count)
    local now = self.get_time and self:get_time() or ngx.now() * 1000

    local data = self.dict[key]
    if not data or type(data) ~= "table" then
        data = {}
    end

    table.insert(data, now)

    local max_requests = count or self.default_limit
    while #data > max_requests + 100 do
        table.remove(data, 1)
    end

    self.dict[key] = data
    self.dict:set(key .. "_ts", now)

    return true
end

function Limit:sliding_window_check(key, limit, window)
    local count = self:get_sliding_window_count(key, window)
    local now = self:get_time()

    if count >= limit then
        return false, count, limit
    end

    self:add_request(key, limit)

    return true, count + 1, limit
end

function Limit:fixed_window_check(key, limit, window)
    local window_key = key .. ":" .. math.floor(self:get_time() / (window * 1000))
    local current = self.dict[window_key] or 0

    if current >= limit then
        return false, current, limit
    end

    local new_val = self.dict:incr(window_key, 1)
    if not new_val then
        self.dict:set(window_key, 1)
    end

    return true, current + 1, limit
end

function Limit:token_bucket_check(key, rate, capacity)
    local bucket_key = key .. ":bucket"
    local tokens_key = key .. ":tokens"

    local last_time = self.dict[bucket_key] or self:get_time()
    local tokens = self.dict[tokens_key] or capacity

    local now = self:get_time()
    local elapsed = (now - last_time) / 1000
    local new_tokens = math.min(capacity, tokens + elapsed * rate)

    if new_tokens < 1 then
        return false, new_tokens, capacity
    end

    self.dict:set(bucket_key, now)
    self.dict:set(tokens_key, new_tokens - 1)

    return true, new_tokens - 1, capacity
end

function Limit:check(identifier, route, limit, window, burst)
    limit = limit or self.default_limit
    window = window or self.default_window
    burst = burst or self.default_burst

    local key = self:get_key("ip", identifier, route)

    local success, current, max_limit
    local effective_limit = limit + burst

    if self.strategy == Limit.STRATEGIES.SLIDING_WINDOW then
        success, current, max_limit = self:sliding_window_check(key, effective_limit, window)
    elseif self.strategy == Limit.STRATEGIES.FIXED_WINDOW then
        success, current, max_limit = self:fixed_window_check(key, effective_limit, window)
    elseif self.strategy == Limit.STRATEGIES.TOKEN_BUCKET then
        success, current, max_limit = self:token_bucket_check(key, limit, effective_limit)
    else
        success, current, max_limit = self:sliding_window_check(key, effective_limit, window)
    end

    local remaining = math.max(0, max_limit - current)

    if not success then
        if self.log_blocked then
            ngx.log(ngx.WARN, "Rate limit exceeded for key: ", key, " (", current, "/", max_limit, ")")
        end
    end

    return success, {
        limit = limit,
        window = window,
        remaining = remaining,
        reset = math.floor((self:get_time() + window * 1000) / 1000),
        current = current,
        strategy = self.strategy
    }
end

function Limit:check_user(user_id, route, limit, window)
    local key = self:get_key("user", user_id, route)
    local success, info = self:sliding_window_check(key, limit, window)
    return success, info
end

function Limit:check_combined(route, limit, window)
    local key = self:get_key("combined", nil, route)
    local success, info = self:sliding_window_check(key, limit, window)
    return success, info
end

function Limit:limit_exceeded(identifier, route, limit, window, burst)
    local success, info = self:check(identifier, route, limit, window, burst)
    return not success, info
end

function Limit:is_allowed(...)
    return self:check(...)
end

function Limit:apply_limits(rules)
    local headers = {}
    local blocked = false
    local block_info = nil

    for _, rule in ipairs(rules) do
        local key_type = rule.key_type or "ip"
        local identifier = rule.identifier or ""
        local route = rule.route or ngx.var.uri
        local limit = rule.limit
        local window = rule.window or 60
        local burst = rule.burst or 0

        local success, info = self:check(identifier, route, limit, window, burst)

        if not success then
            blocked = true
            block_info = info
        end

        if headers[rule.name or "default"] == nil then
            headers[rule.name or "default"] = info
        end
    end

    return blocked, headers
end

function Limit:set_headers(info)
    if not info then return end

    ngx.header["X-RateLimit-Limit"] = info.limit
    ngx.header["X-RateLimit-Remaining"] = info.remaining
    ngx.header["X-RateLimit-Reset"] = info.reset
    ngx.header["X-RateLimit-Window"] = info.window
end

function Limit:reject()
    if self.action == Limit.ACTIONS.REDIRECT then
        return ngx.redirect(self.redirect_url, 302)
    elseif self.action == Limit.ACTIONS.DROP then
        ngx.exit(ngx.OK)
    else
        ngx.header["Content-Type"] = "application/json"
        ngx.status = self.response_status
        ngx.say('{"success":false,"error":"' .. self.response_message .. '","code":' .. self.response_status .. '}')
        ngx.exit(ngx.status)
    end
end

function Limit:check_and_reject(identifier, route, limit, window, burst)
    local success, info = self:check(identifier, route, limit, window, burst)
    self:set_headers(info)

    if not success then
        self:reject()
        return false
    end

    return true
end

function Limit:reset(key)
    local full_key = "limit:" .. key
    self.dict[full_key] = nil
    self.dict[full_key .. "_ts"] = nil
    self.dict[full_key .. ":bucket"] = nil
    self.dict[full_key .. ":tokens"] = nil
    return true
end

function Limit:reset_all()
    if self.dict and self.dict.flush_all then
        self.dict:flush_all()
    end
    self.counters = {}
    return true
end

function Limit:get_stats(key)
    local full_key = "limit:" .. key
    local data = self.dict[full_key]

    local stats = {
        key = key,
        count = 0,
        type = "unknown"
    }

    if type(data) == "table" then
        stats.count = #data
        stats.type = "sliding_window"
    elseif data then
        stats.count = tonumber(data) or 0
        stats.type = "fixed_window"
    end

    local ts = self.dict[full_key .. "_ts"]
    if ts then
        stats.last_update = tonumber(ts)
    end

    return stats
end

function Limit:get_all_keys()
    local keys = {}
    local prefix = "limit:"

    if self.dict.get_keys then
        local all_keys = self.dict:get_keys(1000)
        for _, k in ipairs(all_keys) do
            if string.sub(k, 1, #prefix) == prefix then
                local key = string.sub(k, #prefix + 1)
                local base_key = key:match("([^:]+)")
                if base_key and not keys[base_key] then
                    keys[base_key] = true
                end
            end
        end
    end

    local result = {}
    for k, _ in pairs(keys) do
        table.insert(result, k)
    end

    return result
end

function Limit:create_zone(name, limit, window, burst)
    self.zones = self.zones or {}
    self.zones[name] = {
        limit = limit,
        window = window,
        burst = burst
    }
    return self.zones[name]
end

function Limit:check_zone(zone_name, identifier)
    local zone = self.zones and self.zones[zone_name]
    if not zone then
        return true, { error = "Zone not found" }
    end

    local key = self:get_key("zone", identifier, zone_name)
    local success, info = self:check(identifier, zone_name, zone.limit, zone.window, zone.burst)

    return success, info
end

return Limit
