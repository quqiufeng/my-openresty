local Controller = require('app.core.Controller')
local Session = require('app.lib.session')

local _M = {}

function _M:__construct()
    Controller.__construct(self)
end

local function escape_str(str)
    if not str then return "''" end
    return "'" .. string.gsub(tostring(str), "'", "''") .. "'"
end

function _M:account()
    local post_data = self.request.post or {}
    local json_data = self.request.json or {}
    local all_input = self.request.all_input or {}

    local username = json_data.username or post_data.username or all_input.username
    local password = json_data.password or post_data.password or all_input.password

    if not username or not password then
        self:json({
            success = false,
            status = 'error',
            message = '用户名和密码必填'
        }, 400)
        return
    end

    local mysql = require('app.lib.mysql')
    local db = mysql.new()
    mysql.connect(db)

    if not db then
        ngx.log(ngx.ERR, "LOGIN: database connect failed")
        self:json({
            success = false,
            status = 'error',
            message = '数据库连接失败'
        }, 500)
        return
    end

    local sql = "SELECT id, username, password, phone, role_id, salt FROM admin WHERE username = " .. escape_str(username)
    local res, err = mysql.query(db, sql)
    mysql.set_keepalive(db)

    if err then
        ngx.log(ngx.ERR, "LOGIN: query failed: ", err)
        self:json({
            success = false,
            status = 'error',
            message = '查询失败'
        }, 500)
        return
    end

    if not res or #res == 0 then
        self:json({
            success = false,
            status = 'error',
            message = '用户不存在'
        }, 401)
        return
    end

    local user = res[1]
    local resty_sha256 = require "resty.sha256"
    local sha256 = resty_sha256:new()
    sha256:update(password .. (user.salt or ''))
    local input_hash_bin = sha256:final()
    local input_hash = ''
    for i = 1, #input_hash_bin do
        input_hash = input_hash .. string.format('%02x', string.byte(input_hash_bin, i))
    end

    if input_hash == user.password then
        local login_time = os.time()
        local token = 'token-' .. tostring(user.id) .. '-' .. tostring(login_time) .. '-' .. ngx.md5(username .. tostring(login_time))

        db = mysql.new()
        mysql.connect(db)
        mysql.query(db, "UPDATE admin SET last_login_time = " .. login_time .. " WHERE id = " .. tonumber(user.id))
        mysql.set_keepalive(db)

        self:json({
            success = true,
            status = 'ok',
            message = '登录成功',
            data = {
                token = token,
                currentAuthority = 'admin',
                id = tonumber(user.id),
                username = user.username,
                phone = user.phone,
                role_id = tonumber(user.role_id),
                loginTime = login_time
            }
        })
    else
        self:json({
            success = false,
            status = 'error',
            message = '用户名或密码错误'
        }, 401)
    end
end

function _M:outLogin()
    local token = self.request.headers and self.request.headers['Authorization']
    if token and token:find(' ') then
        token = token:sub(token:find(' ') + 1)
    end
    if token then
        local Session = require('app.lib.session')
        local session = Session:new()
        session:set_prefix('session:')
        session:set('user_token', nil)
        session:save()
    end
    self:json({ success = true, status = 'ok', message = '退出成功' })
end

function _M:currentUser()
    local token = self.request.headers and self.request.headers['Authorization']
    if token and token:find(' ') then
        token = token:sub(token:find(' ') + 1)
    end

    if not token then
        self:json({ success = false, status = 'error', message = '未登录' }, 401)
        return
    end

    local mysql = require('app.lib.mysql')
    local db = mysql.new()
    mysql.connect(db)

    if not db then
        self:json({ success = false, status = 'error', message = '数据库连接失败' }, 500)
        return
    end

    local sql = "SELECT id, username, phone, role_id FROM admin WHERE id = " .. tonumber(string.match(token, 'token%-(%d+)%-'))
    local res, err = mysql.query(db, sql)
    mysql.set_keepalive(db)

    if res and res[1] then
        local user = res[1]
        self:json({
            success = true,
            status = 'ok',
            data = {
                username = user.username,
                id = tonumber(user.id),
                name = user.username,
                phone = user.phone,
                role_id = tonumber(user.role_id),
                currentAuthority = 'admin'
            }
        })
    else
        self:json({ success = false, status = 'error', message = '用户不存在' }, 404)
    end
end

function _M:register()
    self:json({ success = true, status = 'ok', message = '注册成功' })
end

return _M
