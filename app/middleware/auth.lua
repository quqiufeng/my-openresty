local Auth = {}

Auth.options = {
    mode = 'session',  -- session, token, both
    token_header = 'Authorization',
    token_prefix = 'Bearer',
    session_name = 'myresty_session',
    login_url = '/auth/login',
    unauthorized_msg = 'Unauthorized',
    forbidden_msg = 'Forbidden',
    redirect_on_auth = false,
    api_key_enabled = false,
    api_key_header = 'X-API-Key'
}

function Auth:setup(options)
    self.options = vim.tbl_deep_extend('force', self.options, options or {})
    return self
end

function Auth:handle(options)
    options = vim.tbl_deep_extend('force', self.options, options or {})

    local user_id, user_data, auth_type

    -- 1. 尝试 API Token 认证
    if options.mode == 'token' or options.mode == 'both' then
        user_id, user_data, auth_type = self:check_token(options)
    end

    -- 2. 尝试 Session 认证
    if not user_id and (options.mode == 'session' or options.mode == 'both') then
        user_id, user_data, auth_type = self:check_session(options)
    end

    -- 3. 游客模式 (允许未登录)
    if options.allow_guest then
        ngx.ctx.auth_user = user_id
        ngx.ctx.auth_data = user_data
        ngx.ctx.auth_type = auth_type or 'guest'
        return true
    end

    -- 4. 未登录
    if not user_id then
        if options.redirect_on_auth and options.login_url then
            return ngx.redirect(options.login_url .. '?redirect=' .. ngx.var.uri)
        end

        ngx.status = 401
        ngx.header['Content-Type'] = 'application/json'
        ngx.say('{"success":false,"error":"' .. options.unauthorized_msg .. '","code":401}')
        ngx.exit(401)
        return false
    end

    -- 5. 角色检查
    if options.roles and #options.roles > 0 then
        local has_role = false
        local user_role = user_data and user_data.role or 'user'

        for _, role in ipairs(options.roles) do
            if user_role == role or user_role == 'admin' then
                has_role = true
                break
            end
        end

        if not has_role then
            ngx.status = 403
            ngx.header['Content-Type'] = 'application/json'
            ngx.say('{"success":false,"error":"' .. options.forbidden_msg .. '","code":403}')
            ngx.exit(403)
            return false
        end
    end

    -- 注入用户信息到请求上下文
    ngx.ctx.auth_user = user_id
    ngx.ctx.auth_data = user_data
    ngx.ctx.auth_type = auth_type or 'session'

    return true
end

function Auth:check_session(options)
    local Session = require('app.lib.session')
    local session = Session:new()

    local user_id = session:get('user_id')
    if not user_id then
        return nil
    end

    local user_data = {
        user_id = user_id,
        username = session:get('username'),
        email = session:get('email'),
        role = session:get('role') or 'user'
    }

    return user_id, user_data, 'session'
end

function Auth:check_token(options)
    local token = self:get_token_from_header(options)
    if not token then
        token = self:get_token_from_query()
    end

    if not token then
        return nil
    end

    -- 解析 token (简化版，实际应该用 JWT 或加密)
    local user_id, user_data = self:decode_token(token)
    if not user_id then
        return nil
    end

    return user_id, user_data, 'token'
end

function Auth:get_token_from_header(options)
    local header = ngx.var.http_authorization or ngx.var.http_x_api_key
    if not header then
        return nil
    end

    if options.api_key_enabled and ngx.var.http_x_api_key then
        return ngx.var.http_x_api_key
    end

    if options.token_prefix then
        local token = string.match(header, options.token_prefix .. ' (.+)')
        return token or header
    end

    return header
end

function Auth:get_token_from_query()
    return ngx.var.arg_token or ngx.var.arg_access_token
end

function Auth:decode_token(token)
    -- 简化: token 格式为 user_id.timestamp.signature
    local parts = {}
    for part in string.gmatch(token, '[^.]+') do
        table.insert(parts, part)
    end

    if #parts < 2 then
        return nil
    end

    local user_id = tonumber(parts[1])
    if not user_id then
        return nil
    end

    -- 实际项目中应该验证签名和过期时间
    local user_data = {
        user_id = user_id,
        username = 'api_user',
        role = 'user'
    }

    return user_id, user_data
end

function Auth:login(options)
    options = options or {}

    local Session = require('app.lib.session')
    local session = Session:new()

    local user_id = options.user_id
    local user_data = options.user_data or {}

    session:set('user_id', user_id)
    session:set('username', user_data.username)
    session:set('email', user_data.email)
    session:set('role', user_data.role or 'user')
    session:save()

    return session
end

function Auth:logout()
    local Session = require('app.lib.session')
    local session = Session:new()
    session:destroy()

    return true
end

function Auth:get_user()
    return ngx.ctx.auth_user, ngx.ctx.auth_data, ngx.ctx.auth_type
end

function Auth:is_guest()
    return ngx.ctx.auth_user == nil
end

function Auth:has_role(role)
    local _, user_data = self:get_user()
    if not user_data then
        return false
    end
    return user_data.role == role or user_data.role == 'admin'
end

return Auth
