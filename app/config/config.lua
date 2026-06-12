-- MyResty Configuration
-- Reads from .env file with fallback defaults

local io_open = io.open
local tonumber = tonumber

local function trim(s)
    return s:match('^%s*(.-)%s*$')
end

-- Read .env file
local env = {}
local env_paths = {
    '/tmp/.nginx/.env',
    '/var/www/web/my-openresty/.env',
}
local env_path = nil
local f, err
for _, p in ipairs(env_paths) do
    f, err = io_open(p, 'r')
    if f then
        env_path = p
        break
    end
end
if f then
for line in f:lines() do
        line = trim(line)
        if line ~= '' and line:sub(1, 1) ~= '#' then
            local eq = line:find('=')
            if eq then
                local key = trim(line:sub(1, eq - 1))
                local val = trim(line:sub(eq + 1))
                if key ~= '' then
                    env[key] = val
                end
            end
        end
    end
    f:close()
end

-- Environment variable override (highest priority)
local function e(key, default)
    return os.getenv(key) or env[key] or default
end

local function e_num(key, default)
    local v = os.getenv(key) or env[key]
    if v and v ~= '' then return tonumber(v) or default end
    return default
end

local function split_csv(val, default)
    if val and val ~= '' then
        local parts = {}
        for part in val:gmatch('[^,]+') do
            parts[#parts + 1] = trim(part)
        end
        return #parts > 0 and parts or default
    end
    return default
end

local config = {
    base_url = e('APP_BASE_URL', ''),
    index_page = 'index.php',
    uri_protocol = 'PATH_INFO',
    url_suffix = '',
    url_protocol = 'http',
    host = e('APP_HOST', 'localhost'),
    port = e_num('APP_PORT', 8080),
    charset = e('APP_CHARSET', 'UTF-8'),
    app_path = '/var/www/web/my-openresty',
    cache_path = '/var/www/web/my-openresty/logs/cache',
    log_path = e('LOG_DIR', '/var/www/web/my-openresty/logs'),
    log_threshold = e_num('LOG_LEVEL', 4),
    table_prefix = '',
    autoload = {'helper', 'url', 'request'},

    mysql = {
        host = e('MYSQL_HOST', '127.0.0.1'),
        port = e_num('MYSQL_PORT', 3306),
        user = e('MYSQL_USER', 'root'),
        password = e('MYSQL_PASSWORD', ''),
        database = e('MYSQL_DATABASE', 'myresty'),
        charset = e('MYSQL_CHARSET', 'utf8mb4'),
        pool_size = e_num('MYSQL_POOL_SIZE', 100),
        idle_timeout = e_num('MYSQL_IDLE_TIMEOUT', 10000),
    },

    redis = {
        host = e('REDIS_HOST', '127.0.0.1'),
        port = e_num('REDIS_PORT', 6379),
        password = e('REDIS_PASSWORD', ''),
        db = e_num('REDIS_DB', 0),
        pool_size = e_num('REDIS_POOL_SIZE', 100),
        idle_timeout = e_num('REDIS_IDLE_TIMEOUT', 10000),
    },

    upload = {
        path = e('UPLOAD_PATH', '/var/www/web/my-openresty/uploads'),
        max_size = e_num('UPLOAD_MAX_SIZE', 10),
        allowed_types = split_csv(e('UPLOAD_ALLOWED_TYPES', ''), {'jpg', 'jpeg', 'png', 'gif', 'webp', 'pdf', 'doc', 'docx', 'xls', 'xlsx', 'zip'}),
        allowed_mimes = {
            'image/jpeg', 'image/png', 'image/gif', 'image/webp',
            'application/pdf',
            'application/msword',
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
            'application/vnd.ms-excel',
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            'application/zip', 'application/x-zip-compressed',
        },
        images_only = false,
        preserve_extension = true,
        sanitize_filename = true,
        create_subdirs = true,
    },

    image = {
        quality = e_num('IMAGE_QUALITY', 85),
        thumbnail_size = e_num('IMAGE_THUMBNAIL_SIZE', 150),
        avatar_size = 200,
        medium_size = 800,
        large_size = 1920,
        webp_quality = e_num('IMAGE_WEBP_QUALITY', 80),
        preserve_format = true,
    },

    captcha = {
        length = e_num('CAPTCHA_LENGTH', 5),
        expires = e_num('CAPTCHA_EXPIRES', 300),
        width = e_num('CAPTCHA_WIDTH', 120),
        height = e_num('CAPTCHA_HEIGHT', 80),
    },

    session = {
        cookie_name = e('SESSION_COOKIE_NAME', 'myresty_session'),
        secret_key = nil,  -- crypto.lua reads SESSION_SECRET env var directly
        expires = e_num('SESSION_EXPIRES', 86400),
        cookie_path = '/',
        cookie_domain = '',
        cookie_secure = e('SESSION_COOKIE_SECURE', 'true') == 'true',
        cookie_httponly = e('SESSION_COOKIE_HTTPONLY', 'true') == 'true',
        cookie_samesite = e('SESSION_COOKIE_SAMESITE', 'Strict'),
    },

    logger = {
        level = e_num('LOG_LEVEL', 2),
        handlers = {
            console = true,
            file = true,
        },
        log_dir = e('LOG_DIR', '/var/www/web/my-openresty/logs'),
        max_size = e_num('LOG_MAX_SIZE', 10485760),
        max_files = e_num('LOG_MAX_FILES', 5),
        async = true,
    },

    limit = {
        dict_name = 'limit_dict',
        strategy = 'sliding_window',
        default_limit = e_num('LIMIT_DEFAULT_RATE', 100),
        default_window = e_num('LIMIT_DEFAULT_WINDOW', 60),
        default_burst = e_num('LIMIT_DEFAULT_BURST', 20),
        action = 'deny',
        redirect_url = '/rate-limited',
        response_status = 429,
        response_message = 'Too Many Requests',
        log_blocked = true,
        zones = {
            api = { limit = 60, window = 60, burst = 10 },
            login = { limit = 5, window = 300, burst = 0 },
            upload = { limit = 10, window = 60, burst = 2 },
            default = { limit = 100, window = 60, burst = 20 },
        },
    },

    validation = {
        bail = true,
        throw_exception = false,
        default_messages = {
            required = 'The :field field is required.',
            email = 'The :field must be a valid email address.',
            min = 'The :field must be at least :param.',
            max = 'The :field must not exceed :param.',
            length_min = 'The :field must be at least :param characters.',
            length_max = 'The :field must not exceed :param characters.',
            numeric = 'The :field must be a numeric value.',
            integer = 'The :field must be an integer.',
            alpha = 'The :field may only contain letters.',
            alpha_num = 'The :field may only contain letters and numbers.',
            alpha_dash = 'The :field may only contain letters, numbers, and dashes.',
            ["in"] = 'The :field must be one of: :param.',
            match = 'The :field must match :param.',
            date = 'The :field must be a valid date.',
            url = 'The :field must be a valid URL.',
            regex = 'The :field format is invalid.',
            unique = 'The :field has already been taken.',
        },
        default_labels = {
            username = 'Username',
            email = 'Email Address',
            password = 'Password',
            password_confirmation = 'Password Confirmation',
            name = 'Name',
            title = 'Title',
            description = 'Description',
            phone = 'Phone Number',
            age = 'Age',
            price = 'Price',
            quantity = 'Quantity',
        },
    },

    error_codes = {
        success = 200,
        created = 201,
        bad_request = 400,
        unauthorized = 401,
        forbidden = 403,
        not_found = 404,
        timeout = 408,
        rate_limited = 429,
        server_error = 500,
        bad_gateway = 502,
        unavailable = 503,
    },

    middleware = {
        {
            name = 'request_id',
            phase = 'access',
            options = {
                header_name = 'X-Request-Id',
                set_response_header = true,
            },
        },
        {
            name = 'timeout',
            phase = 'access',
            options = {
                max_execution_time = 30,
                degradation_mode = true,
            },
        },
        {
            name = 'logger',
            phase = 'log',
            options = {
                level = 'info',
                format = 'combined',
                request_id = true,
                timing = true,
                exclude_paths = {'/health', '/favicon.ico'},
            },
        },
        {
            name = 'cors',
            phase = 'header_filter',
            options = {
                origin = '*',
                methods = {'GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'},
                credentials = true,
                max_age = 86400,
            },
        },
        {
            name = 'rate_limit',
            phase = 'access',
            options = {
                zone = 'default',
                headers = true,
                log_blocked = true,
            },
            routes = {'/api/*', '/upload/*'},
        },
        {
            name = 'auth',
            phase = 'access',
            options = {
                mode = 'session',
                allow_guest = true,
            },
            exclude = {'/health', '/captcha', '/static/*', '/middleware/*'},
        },
    },
}

return config
