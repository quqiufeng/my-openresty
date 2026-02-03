local _M = {}

local Crypto = require('app.lib.crypto')

local function generate_random_string(length)
    local chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
    local result = {}

    local rand_bytes = Crypto.random_bytes(length)
    for i = 1, length do
        local idx = (string.byte(rand_bytes, i) or i) % #chars + 1
        table.insert(result, chars:sub(idx, idx))
    end

    return table.concat(result)
end

local function get_cookie_options()
    return {
        path = '/',
        expires = 300,
        httponly = true,
        samesite = 'Lax'
    }
end

function _M.generate(length, key)
    length = tonumber(length) or 5

    local captcha_code = generate_random_string(length)
    local encrypted = Crypto.encrypt_captcha(captcha_code)

    return {
        code = captcha_code,
        encrypted = encrypted,
        cookie_name = 'captcha_token',
        expires = 300
    }
end

function _M.get_cookie_name()
    return 'captcha_token'
end

function _M.write_to_cookie(ngx, encrypted, key)
    local cookie_name = _M.get_cookie_name()
    local options = get_cookie_options()
    local cookie_value = encrypted or ''

    local cookie_str = cookie_name .. '=' .. cookie_value
    cookie_str = cookie_str .. '; Path=' .. options.path
    if options.expires then
        local expires_time = ngx.time() + options.expires
        cookie_str = cookie_str .. '; Expires=' .. ngx.cookie_time(expires_time)
    end
    if options.httponly then
        cookie_str = cookie_str .. '; HttpOnly'
    end
    if options.samesite then
        cookie_str = cookie_str .. '; SameSite=' .. options.samesite
    end

    ngx.header['Set-Cookie'] = cookie_str
end

function _M.get_cookie_value(ngx)
    local cookie_name = _M.get_cookie_name()
    return ngx.var['cookie_' .. cookie_name] or ''
end

function _M.validate(input_code, ngx)
    local encrypted = _M.get_cookie_value(ngx)
    if not encrypted or encrypted == '' then
        return false, 'No captcha cookie'
    end

    local decrypted = Crypto.decrypt_captcha(encrypted)
    if not decrypted then
        return false, 'Invalid captcha cookie'
    end

    if input_code ~= decrypted then
        return false, 'Invalid captcha code'
    end

    return true, 'Captcha validated'
end

function _M.refresh(ngx, key)
    local config = ngx.config and ngx.config.config or nil
    local captcha_config = config and config.captcha or {}

    local length = captcha_config.length or 5
    local new_captcha = _M.generate(length, key)

    _M.write_to_cookie(ngx, new_captcha.encrypted, key)

    return new_captcha.code
end

function _M.get_captcha_image(code, width, height, config)
    local GdCaptcha = require('app.utils.captcha')

    width = width or 120
    height = height or 40

    local png_data, err = GdCaptcha.get_captcha_image(code, width, height)
    if not png_data then
        return nil, err or 'Failed to generate captcha image'
    end

    return png_data
end

function _M.get_captcha_png_base64(code, width, height, config)
    local image_data, err = _M.get_captcha_image(code, width, height, config)
    if not image_data then
        return nil, err
    end

    local base64_data = Crypto.base64_encode(image_data)
    return base64_data
end

function _M.get_config()
    local Loader = require('app.core.Loader')
    local loader = Loader:new()
    return loader:config()
end

return _M
