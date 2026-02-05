local config = {
    base_url = '',
    index_page = 'index.php',
    uri_protocol = 'PATH_INFO',
    url_suffix = '',
    url_protocol = 'http',
    host = 'localhost',
    port = 8080,
    charset = 'UTF-8',
    app_path = '/var/www/web/my-openresty',
    cache_path = '/var/www/web/my-openresty/logs/cache',
    log_path = '/var/www/web/my-openresty/logs',
    log_threshold = 4,
    table_prefix = '',
    autoload = {
        'helper',
        'url',
        'request'
    },
    mysql = {
        host = '127.0.0.1',
        port = 3306,
        user = 'root',
        password = '123456',
        database = 'project',
        charset = 'utf8mb4',
        pool_size = 100,
        idle_timeout = 10000
    },
    redis = {
        host = '127.0.0.1',
        port = 6379,
        password = '',
        db = 0,
        pool_size = 100,
        idle_timeout = 10000
    },
    upload = {
        path = '/var/www/web/my-openresty/uploads',
        max_size = 10,
        allowed_types = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'pdf', 'doc', 'docx', 'xls', 'xlsx', 'zip'},
        allowed_mimes = {
            'image/jpeg', 'image/png', 'image/gif', 'image/webp',
            'application/pdf',
            'application/msword',
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
            'application/vnd.ms-excel',
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            'application/zip', 'application/x-zip-compressed'
        },
        images_only = false,
        preserve_extension = true,
        sanitize_filename = true,
        create_subdirs = true
    },
    image = {
        quality = 85,
        thumbnail_size = 150,
        avatar_size = 200,
        medium_size = 800,
        large_size = 1920,
        webp_quality = 80,
        preserve_format = true
    },
    -- ============================================================
    -- 验证码配置
    -- ============================================================
    -- 安全说明:
    --   验证码使用与 Session 相同的密钥配置（session.secret_key）
    --   无需单独配置 captcha.key
    --   密钥通过环境变量 SESSION_SECRET 或 config.session.secret_key 获取
    --
    -- 配置优先级:
    --   1. 环境变量 SESSION_SECRET (最高)
    --   2. 环境变量 MYRESTY_SESSION_SECRET
    --   3. config.session.secret_key
    -- ============================================================
    captcha = {
        -- 验证码长度
        length = 5,
        -- 验证码有效期（秒）
        expires = 300,
        -- 图片宽度
        width = 120,
        -- 图片高度
        height = 80
    },
    -- ============================================================
    -- Session 配置
    -- ============================================================
    -- 安全说明:
    --   1. secret_key 必须保持机密，泄露后攻击者可伪造任意 session
    --   2. Session 与 Captcha 使用相同的密钥配置
    --   3. 修改密钥会导致所有现有 session 失效
    --
    -- 生成新密钥命令:
    --   openssl rand -hex 16
    -- ============================================================
    session = {
        cookie_name = 'myresty_session',
        -- AES-128 安全密钥（32字符十六进制）
        -- 足够安全且配置简洁
        secret_key = 'd07495d9623312cae328d13ca573e788',
        -- 会话过期时间（秒）
        expires = 86400,
        cookie_path = '/',
        cookie_domain = '',
        cookie_secure = true,
        cookie_httponly = true,
        cookie_samesite = 'Strict'
    },
    logger = {
        level = 2,
        handlers = {
            console = true,
            file = true
        },
        log_dir = '/var/www/web/my-openresty/logs',
        max_size = 10485760,
        max_files = 5,
        async = true
    },
    limit = {
        dict_name = "limit_dict",
        strategy = "sliding_window",
        default_limit = 100,
        default_window = 60,
        default_burst = 0,
        action = "deny",
        redirect_url = "/rate-limited",
        response_status = 429,
        response_message = "Too Many Requests",
        log_blocked = true,
        zones = {
            api = {
                limit = 60,
                window = 60,
                burst = 10
            },
            login = {
                limit = 5,
                window = 300,
                burst = 0
            },
            upload = {
                limit = 10,
                window = 60,
                burst = 2
            },
            default = {
                limit = 100,
                window = 60,
                burst = 20
            }
        }
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
            unique = 'The :field has already been taken.'
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
            quantity = 'Quantity'
        }
    },
    middleware = {
        {
            name = 'logger',
            phase = 'log',
            options = {
                level = 'info',
                format = 'combined',
                request_id = true,
                timing = true,
                exclude_paths = {'/health', '/favicon.ico'}
            }
        },
        {
            name = 'cors',
            phase = 'header_filter',
            options = {
                origin = '*',
                methods = {'GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'},
                credentials = true,
                max_age = 86400
            }
        },
        {
            name = 'rate_limit',
            phase = 'access',
            options = {
                zone = 'default',
                headers = true,
                log_blocked = true
            },
            routes = {'/api/*', '/upload/*'}
        },
        {
            name = 'auth',
            phase = 'access',
            options = {
                mode = 'session',
                allow_guest = true
            },
            exclude = {'/health', '/captcha', '/static/*', '/middleware/*'}
        }
    }
}

return config
