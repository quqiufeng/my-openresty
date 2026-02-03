-- Helper Utility Functions for MyResty
-- Provides common utility functions for formatting, validation, encoding, etc.

local Helper = {}

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

-- ========================================
-- Bitwise Helper Functions (must be defined first)
-- ========================================

local function bit_and(a, b)
    local result = 0
    local bit = 1
    while a > 0 or b > 0 do
        if a % 2 == 1 and b % 2 == 1 then
            result = result + bit
        end
        a = math.floor(a / 2)
        b = math.floor(b / 2)
        bit = bit * 2
    end
    return result
end

local function bit_or(a, b)
    local result = 0
    local bit = 1
    while a > 0 or b > 0 do
        if a % 2 == 1 or b % 2 == 1 then
            result = result + bit
        end
        a = math.floor(a / 2)
        b = math.floor(b / 2)
        bit = bit * 2
    end
    return result
end

local function bit_lshift(a, n)
    return a * (2 ^ n)
end

local function bit_rshift(a, n)
    return math.floor(a / (2 ^ n))
end

-- ========================================
-- Date and Time Functions
-- ========================================

function Helper.format_date(ts, format)
    ts = tonumber(ts) or os.time()
    format = format or '%Y-%m-%d %H:%M:%S'
    
    local time = os.date('*t', ts)
    if not time then return os.date(format, ts) end
    
    local replacements = {
        ['%Y'] = string.format('%04d', time.year),
        ['%m'] = string.format('%02d', time.month),
        ['%d'] = string.format('%02d', time.day),
        ['%H'] = string.format('%02d', time.hour),
        ['%M'] = string.format('%02d', time.min),
        ['%S'] = string.format('%02d', time.sec),
        ['%w'] = tostring(time.wday - 1),
        ['%j'] = string.format('%03d', time.yday),
        ['%U'] = string.format('%02d', math.floor((time.yday - time.wday + 7) / 7)),
    }
    
    local result = format
    for k, v in pairs(replacements) do
        result = result:gsub(k, v)
    end
    
    return result
end

function Helper.parse_date(date_str, format)
    format = format or '%Y-%m-%d %H:%M:%S'
    local patterns = {
        ['%Y-%m-%d'] = '^(%d%d%d%d)%-(%d%d)%-(%d%d)',
        ['%Y/%m/%d'] = '^(%d%d%d%d)/(%d%d)/(%d%d)',
        ['%m/%d/%Y'] = '^(%d%d)/(%d%d)/(%d%d%d%d)',
        ['%H:%M:%S'] = '^(%d%d):(%d%d):(%d%d)',
        ['%Y-%m-%d %H:%M:%S'] = '^(%d%d%d%d)%-(%d%d)%-(%d%d) (%d%d):(%d%d):(%d%d)',
    }
    
    local pattern = patterns[format] or patterns['%Y-%m-%d %H:%M:%S']
    local year, month, day, hour, min, sec = date_str:match(pattern)
    
    if year then
        return {
            year = tonumber(year),
            month = tonumber(month),
            day = tonumber(day),
            hour = tonumber(hour or 0),
            min = tonumber(min or 0),
            sec = tonumber(sec or 0),
            timestamp = os.time({
                year = tonumber(year),
                month = tonumber(month),
                day = tonumber(day),
                hour = tonumber(hour or 0),
                min = tonumber(min or 0),
                sec = tonumber(sec or 0)
            })
        }
    end
    
    return nil
end

function Helper.time_ago(ts)
    local now = os.time()
    local diff = now - tonumber(ts)
    
    if diff < 60 then
        return 'just now'
    elseif diff < 3600 then
        local mins = math.floor(diff / 60)
        return mins .. ' minute' .. (mins > 1 and 's' or '') .. ' ago'
    elseif diff < 86400 then
        local hours = math.floor(diff / 3600)
        return hours .. ' hour' .. (hours > 1 and 's' or '') .. ' ago'
    elseif diff < 604800 then
        local days = math.floor(diff / 86400)
        return days .. ' day' .. (days > 1 and 's' or '') .. ' ago'
    elseif diff < 2592000 then
        local weeks = math.floor(diff / 604800)
        return weeks .. ' week' .. (weeks > 1 and 's' or '') .. ' ago'
    elseif diff < 31536000 then
        local months = math.floor(diff / 2592000)
        return months .. ' month' .. (months > 1 and 's' or '') .. ' ago'
    else
        local years = math.floor(diff / 31536000)
        return years .. ' year' .. (years > 1 and 's' or '') .. ' ago'
    end
end

-- ========================================
-- String Functions
-- ========================================

function Helper.trim(s)
    if not s then return nil end
    return s:gsub('^%s+', ''):gsub('%s+$', '')
end

function Helper.ucfirst(s)
    if not s or s == '' then return s end
    return s:sub(1, 1):upper() .. s:sub(2):lower()
end

function Helper.lcfirst(s)
    if not s or s == '' then return s end
    return s:sub(1, 1):lower() .. s:sub(2)
end

function Helper.str_repeat(s, n)
    return string.rep(s, n)
end

function Helper.str_pad(s, length, char, direction)
    char = char or ' '
    direction = direction or 'both'
    length = tonumber(length) or 0
    
    local current = #s
    if current >= length then return s end
    
    local to_add = length - current
    local left = math.floor(to_add / 2)
    local right = to_add - left
    
    if direction == 'left' then
        return string.rep(char, left + to_add) .. s
    elseif direction == 'right' then
        return s .. string.rep(char, left + to_add)
    else
        return string.rep(char, left) .. s .. string.rep(char, right)
    end
end

function Helper.truncate(s, length, suffix)
    suffix = suffix or '...'
    if not s or #s <= length then return s end
    return s:sub(1, length - #suffix) .. suffix
end

function Helper.word_wrap(s, width, break_str)
    width = tonumber(width) or 80
    break_str = break_str or '\n'
    
    if not s then return '' end
    
    local result = {}
    local line = ''
    
    for word in s:gmatch('%S+') do
        if #line + #word + 1 > width then
            table.insert(result, line)
            line = word
        else
            if line ~= '' then line = line .. ' ' end
            line = line .. word
        end
    end
    
    if line ~= '' then
        table.insert(result, line)
    end
    
    return table.concat(result, break_str)
end

function Helper.slug(s)
    if not s then return '' end
    s = s:lower()
    s = s:gsub('%s+', '-')
    s = s:gsub('[^a-z0-9%-]', '')
    s = s:gsub('-+', '-')
    s = s:gsub('^-?(.-)-?$', '%1')
    return s
end

function Helper.camel_case(s)
    if not s then return '' end
    s = s:lower():gsub('[^a-z0-9]+', ' ')
    local words = {}
    for word in s:gmatch('%S+') do
        table.insert(words, Helper.ucfirst(word))
    end
    return table.concat(words)
end

function Helper.snake_case(s)
    if not s then return '' end
    s = s:gsub('(%u)', '_%1')
    s = s:lower()
    s = s:gsub('[^a-z0-9_]', '')
    s = s:gsub('_+', '_')
    return s:gsub('^_?(.-)_?$', '%1')
end

-- ========================================
-- Validation Functions
-- ========================================

function Helper.is_valid_email(email)
    if not email or type(email) ~= 'string' then
        return false
    end
    local at_pos = email:find('@')
    if not at_pos or at_pos <= 1 then
        return false
    end
    local domain = email:sub(at_pos + 1)
    if not domain or domain == '' then
        return false
    end
    if domain:find('^%.') then
        return false
    end
    if not domain:find('%.') then
        return false
    end
    local tld = domain:match('%.([^%.]+)$')
    if not tld or #tld < 2 then
        return false
    end
    return true
end

function Helper.is_valid_url(url)
    if not url or type(url) ~= 'string' then
        return false
    end
    return url:find('^https?://') == 1
end

function Helper.is_valid_phone(phone)
    if not phone or type(phone) ~= 'string' then
        return false
    end
    -- Chinese mobile phone number format
    local cleaned = phone:gsub('%s+', '')
    if cleaned:match('^1[3-9]%d%d%d%d%d%d%d%d$') then
        return true
    end
    -- Simple international format
    if cleaned:match('^%+?[1-9]%d{6,14}$') then
        return true
    end
    return false
end

function Helper.is_valid_ip(ip)
    if not ip or type(ip) ~= 'string' then
        return false
    end
    local parts = {}
    for part in ip:gmatch('%d+') do
        table.insert(parts, tonumber(part))
    end
    if #parts ~= 4 then return false end
    for _, part in ipairs(parts) do
        if part < 0 or part > 255 then return false end
    end
    return true
end

function Helper.is_valid_json(s)
    if not s or type(s) ~= 'string' then
        return false
    end
    local cjson = require('cjson')
    local success, _ = pcall(function()
        cjson.decode(s)
    end)
    return success
end

function Helper.is_numeric(s)
    if type(s) == 'number' then return true end
    if type(s) ~= 'string' then return false end
    local num = tonumber(s)
    return num ~= nil and tostring(num) == s:gsub('^%-', '')
end

function Helper.is_alpha(s)
    if not s or type(s) ~= 'string' then return false end
    return s:match('^[a-zA-Z]+$') ~= nil
end

function Helper.is_alphanumeric(s)
    if not s or type(s) ~= 'string' then return false end
    return s:match('^[a-zA-Z0-9]+$') ~= nil
end

-- ========================================
-- Sanitization Functions
-- ========================================

function Helper.sanitize(s, allow_html)
    if not s then return '' end
    s = tostring(s)
    if not allow_html then
        s = s:gsub('<[^>]+>', '')
    end
    s = s:gsub('%s+', ' ')
    return Helper.trim(s)
end

function Helper.escape_html(s)
    if not s then return '' end
    s = tostring(s)
    s = s:gsub('&', '&amp;')
    s = s:gsub('<', '&lt;')
    s = s:gsub('>', '&gt;')
    s = s:gsub('"', '&quot;')
    s = s:gsub("'", '&#39;')
    return s
end

function Helper.strip_tags(s)
    if not s then return '' end
    return tostring(s):gsub('<[^>]+>', '')
end

function Helper.xss_clean(s)
    s = tostring(s)
    -- Remove script tags and their content
    s = s:gsub('<script[^>]*>.-</script>', '')
    -- Remove event handlers
    s = s:gsub('on[a-zA-Z]+="[^"]*"', '')
    s = s:gsub("on[a-zA-Z]+='[^']*'", '')
    s = s:gsub('on[a-zA-Z]+=%S+', '')
    -- Remove javascript: URLs
    s = s:gsub('javascript:[^"\']+', '')
    -- Remove data: URLs (can contain scripts)
    s = s:gsub('data:[^"\']+', '')
    return s
end

-- ========================================
-- Encoding/Decoding Functions
-- ========================================

function Helper.base64_encode(s)
    if not s then return '' end
    s = tostring(s)
    
    local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    local result = _get_tab_from_pool()
    
    local i = 1
    while i <= #s do
        local byte1 = string.byte(s, i)
        local byte2 = i + 1 <= #s and string.byte(s, i + 1) or 0
        local byte3 = i + 2 <= #s and string.byte(s, i + 2) or 0
        
        local triplet = bit_lshift(byte1, 16) + bit_lshift(byte2, 8) + byte3
        
        table.insert(result, b64chars:sub(bit_rshift(bit_and(triplet, 0x3F0000), 18) + 1, bit_rshift(bit_and(triplet, 0x3F0000), 18) + 1))
        table.insert(result, b64chars:sub(bit_rshift(bit_and(triplet, 0xFC00), 12) + 1, bit_rshift(bit_and(triplet, 0xFC00), 12) + 1))
        
        if i + 1 <= #s then
            table.insert(result, b64chars:sub(bit_rshift(bit_and(triplet, 0xF0), 6) + 1, bit_rshift(bit_and(triplet, 0xF0), 6) + 1))
        else
            table.insert(result, '=')
        end
        
        if i + 2 <= #s then
            table.insert(result, b64chars:sub(bit_and(triplet, 0x3F) + 1, bit_and(triplet, 0x3F) + 1))
        else
            table.insert(result, '=')
        end
        
        i = i + 3
    end
    
    local encoded = table.concat(result)
    _put_tab_into_pool(result)
    return encoded
end

function Helper.base64_decode(s)
    if not s or s == '' then return '' end
    s = tostring(s):gsub('%s+', '')
    
    local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    local reverse_map = {}
    for i = 1, #b64chars do
        reverse_map[b64chars:sub(i, i)] = i - 1
    end
    
    local result = _get_tab_from_pool()
    local i = 1
    
    while i <= #s do
        local padding = 0
        local p1, p2, p3, p4 = s:sub(i, i), s:sub(i + 1, i + 1), s:sub(i + 2, i + 2), s:sub(i + 3, i + 3)
        
        if p3 == '=' then padding = 2 elseif p4 == '=' then padding = 1 end
        
        local c1 = reverse_map[p1] or 0
        local c2 = reverse_map[p2] or 0
        local c3 = reverse_map[p3] or 0
        local c4 = reverse_map[p4] or 0
        
        local triplet = bit_lshift(c1, 18) + bit_lshift(c2, 12) + bit_lshift(c3, 6) + c4
        
        table.insert(result, string.char(bit_rshift(triplet, 16)))
        if padding < 2 then
            table.insert(result, string.char(bit_and(bit_rshift(triplet, 8), 0xFF)))
        end
        if padding == 0 then
            table.insert(result, string.char(bit_and(triplet, 0xFF)))
        end
        
        i = i + 4
    end
    
    local decoded = table.concat(result)
    _put_tab_into_pool(result)
    return decoded
end

function Helper.url_encode(s)
    if not s then return '' end
    s = tostring(s)
    local result = {}
    for i = 1, #s do
        local c = s:sub(i, i)
        if c:match('[a-zA-Z0-9%-_.~]') then
            table.insert(result, c)
        elseif c == ' ' then
            table.insert(result, '+')
        else
            table.insert(result, string.format('%%%02X', string.byte(c)))
        end
    end
    return table.concat(result)
end

function Helper.url_decode(s)
    if not s then return '' end
    s = tostring(s)
    s = s:gsub('+', ' ')
    s = s:gsub('%%(%x%x)', function(h)
        return string.char(tonumber(h, 16))
    end)
    return s
end

function Helper.html_entities_encode(s)
    if not s then return '' end
    s = tostring(s)
    local entities = {
        ['&'] = '&amp;',
        ['<'] = '&lt;',
        ['>'] = '&gt;',
        ['"'] = '&quot;',
        ["'"] = '&#39;',
        ['/'] = '&#47;'
    }
    return s:gsub('[&<>"/\']', function(c) return entities[c] or c end)
end

function Helper.html_entities_decode(s)
    if not s then return '' end
    s = tostring(s)
    local entities = {
        ['&amp;'] = '&',
        ['&lt;'] = '<',
        ['&gt;'] = '>',
        ['&quot;'] = '"',
        ['&#39;'] = "'",
        ['&#47;'] = '/',
        ['&nbsp;'] = ' '
    }
    for k, v in pairs(entities) do
        s = s:gsub(k, v)
    end
    return s
end

-- ========================================
-- Hash Functions
-- ========================================

function Helper.md5(s)
    if not s then return '' end
    s = tostring(s)
    
    -- Try to use resty.md5 if available
    local ok, resty_md5 = pcall(require, 'resty.md5')
    if ok and resty_md5 then
        local md5 = resty_md5:new()
        if md5 then
            md5:update(s)
            local digest = md5:final()
            local hex = ''
            for i = 1, #digest do
                hex = hex .. string.format('%02x', string.byte(digest, i))
            end
            return hex
        end
    end
    
    -- Fallback: Simple hash function (not real MD5, but provides consistent output)
    local hash = 0
    for i = 1, #s do
        local char = string.byte(s, i)
        hash = ((hash * 32) - hash) + char
        hash = bit_and(hash, 0xFFFFFFFF)
    end
    return string.format('%08x', hash)
end

function Helper.sha1(s)
    if not s then return '' end
    local resty_sha1 = require('resty.sha1')
    local sha1 = resty_sha1:new()
    if not sha1 then return '' end
    
    local ok = sha1:update(tostring(s))
    if not ok then return '' end
    
    local digest = sha1:final()
    local hex = ''
    for i = 1, #digest do
        hex = hex .. string.format('%02x', string.byte(digest, i))
    end
    return hex
end

function Helper.sha256(s)
    if not s then return '' end
    local resty_sha256 = require('resty.sha256')
    local sha256 = resty_sha256:new()
    if not sha256 then return '' end
    
    local ok = sha256:update(tostring(s))
    if not ok then return '' end
    
    local digest = sha256:final()
    local hex = ''
    for i = 1, #digest do
        hex = hex .. string.format('%02x', string.byte(digest, i))
    end
    return hex
end

-- ========================================
-- Random Functions
-- ========================================

function Helper.random_string(length, chars)
    length = tonumber(length) or 16
    chars = chars or 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
    local result = {}
    for i = 1, length do
        table.insert(result, chars:sub(math.random(1, #chars), #chars))
    end
    return table.concat(result)
end

function Helper.random_number(min, max)
    min = tonumber(min) or 0
    max = tonumber(max) or 100
    return math.random(min, max)
end

function Helper.uuid()
    -- Generate UUID v4
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    local function replace(c)
        local v = 0
        if c == 'x' then
            v = math.random(0, 15)
        elseif c == 'y' then
            v = math.random(8, 11)
        end
        return string.format('%x', v)
    end
    return (template:gsub('[xy]', replace))
end

-- ========================================
-- Array/List Functions
-- ========================================

function Helper.array_pluck(arr, key)
    if not arr or type(arr) ~= 'table' then return {} end
    local result = {}
    for _, item in ipairs(arr) do
        table.insert(result, item[key])
    end
    return result
end

function Helper.array_column(arr, key)
    return Helper.array_pluck(arr, key)
end

function Helper.array_filter(arr, callback)
    if not arr or type(arr) ~= 'table' then return {} end
    local result = {}
    for i, item in ipairs(arr) do
        if callback(item, i) then
            table.insert(result, item)
        end
    end
    return result
end

function Helper.array_map(arr, callback)
    if not arr or type(arr) ~= 'table' then return {} end
    local result = {}
    for i, item in ipairs(arr) do
        table.insert(result, callback(item, i))
    end
    return result
end

function Helper.array_reduce(arr, callback, initial)
    if not arr or type(arr) ~= 'table' then return initial end
    local result = initial
    for i, item in ipairs(arr) do
        result = callback(result, item, i)
    end
    return result
end

function Helper.paginate(arr, page, per_page)
    if not arr or type(arr) ~= 'table' then return {} end
    
    page = tonumber(page) or 1
    per_page = tonumber(per_page) or 10
    
    local offset = (page - 1) * per_page
    local result = {}
    
    for i = offset + 1, math.min(offset + per_page, #arr) do
        table.insert(result, arr[i])
    end
    
    return {
        data = result,
        current_page = page,
        per_page = per_page,
        total = #arr,
        total_pages = math.ceil(#arr / per_page),
        has_next = page < math.ceil(#arr / per_page),
        has_prev = page > 1
    }
end

function Helper.array_chunk(arr, size)
    if not arr or type(arr) ~= 'table' then return {} end
    size = tonumber(size) or 2
    
    local result = {}
    local current = {}
    
    for i, item in ipairs(arr) do
        table.insert(current, item)
        if #current >= size then
            table.insert(result, current)
            current = {}
        end
    end
    
    if #current > 0 then
        table.insert(result, current)
    end
    
    return result
end

function Helper.array_flatten(arr)
    if not arr or type(arr) ~= 'table' then return {} end
    
    local result = {}
    local function flatten(item)
        if type(item) == 'table' then
            for _, v in ipairs(item) do
                flatten(v)
            end
        else
            table.insert(result, item)
        end
    end
    
    for _, item in ipairs(arr) do
        flatten(item)
    end
    
    return result
end

function Helper.array_unique(arr)
    if not arr or type(arr) ~= 'table' then return {} end
    
    local seen = {}
    local result = {}
    
    for _, item in ipairs(arr) do
        if not seen[item] then
            seen[item] = true
            table.insert(result, item)
        end
    end
    
    return result
end

-- ========================================
-- XSS Protection Functions
-- ========================================

function Helper.xss_clean(input)
    if not input or type(input) ~= 'string' then
        return input
    end
    
    local escaped = input
        :gsub('&', '&amp;')
        :gsub('<', '&lt;')
        :gsub('>', '&gt;')
        :gsub('"', '&quot;')
        :gsub("'", '&#x27;')
        :gsub('/', '&#x2F;')
        :gsub('`', '&#x60;')
        :gsub('=', '&#x3D;')
    
    return escaped
end

function Helper.xss_clean_table(t)
    if not t or type(t) ~= 'table' then
        return t
    end
    
    local result = {}
    for k, v in pairs(t) do
        if type(v) == 'string' then
            result[k] = Helper.xss_clean(v)
        elseif type(v) == 'table' then
            result[k] = Helper.xss_clean_table(v)
        else
            result[k] = v
        end
    end
    return result
end

function Helper.strip_tags(input)
    if not input or type(input) ~= 'string' then
        return input
    end
    return input:gsub('<[^>]*>', '')
end

-- ========================================
-- Bitwise Helper Functions
-- ========================================

return Helper
