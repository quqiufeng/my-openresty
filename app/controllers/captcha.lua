local BaseController = require('app.core.Controller')
local CaptchaHelper = require('app.helpers.captcha_helper')

local CaptchaController = {}

function CaptchaController:__construct()
    local Controller = require('app.core.Controller')
    Controller.__construct(self)
end

function CaptchaController:index()
    local captcha_config = self.config.captcha or {}
    local gd_available = CaptchaHelper.is_available()

    if not gd_available then
        return self:json({
            success = false,
            message = 'Captcha API',
            error = 'GD library not installed',
            install_instruction = 'apt-get install libgd-dev',
            endpoints = {
                ['GET /captcha'] = 'Generate PNG captcha image',
                ['GET /captcha/code'] = 'Generate captcha and return code',
                ['POST /captcha/verify'] = 'Verify captcha code',
                ['POST /captcha/refresh'] = 'Refresh captcha',
            },
            default_dimensions = {
                width = captcha_config.width or 120,
                height = captcha_config.height or 80
            }
        })
    end

    return self:json({
        success = true,
        message = 'Captcha API',
        endpoints = {
            ['GET /captcha'] = 'Generate PNG captcha image',
            ['GET /captcha/code'] = 'Generate captcha and return code',
            ['POST /captcha/verify'] = 'Verify captcha code',
            ['POST /captcha/refresh'] = 'Refresh captcha',
        },
        default_dimensions = {
            width = captcha_config.width or 120,
            height = captcha_config.height or 80
        },
        parameters = {
            ['?width=150'] = 'Custom width in pixels (default: 120)',
            ['?height=60'] = 'Custom height in pixels (default: 80)'
        },
        format = 'PNG'
    })
end

function CaptchaController:generate()
    local captcha_config = self.config.captcha or {}

    local captcha = CaptchaHelper.generate()
    CaptchaHelper.write_to_cookie(ngx, captcha.encrypted)

    local width = tonumber(self.request.get and self.request.get.width) or captcha_config.width or 120
    local height = tonumber(self.request.get and self.request.get.height) or captcha_config.height or 80

    local image = CaptchaHelper.get_captcha_image(captcha.code, width, height, captcha_config)

    if not image then
        return self:json({
            success = false,
            error = 'Failed to generate captcha image'
        }, 500)
    end

    self:header('Content-Type', 'image/png')
    self:header('Cache-Control', 'no-store, no-cache, must-revalidate')
    self:header('Pragma', 'no-cache')
    self:header('Expires', '0')

    return image.data
end

function CaptchaController:getCode()
    local captcha_config = self.config.captcha or {}

    local captcha = CaptchaHelper.generate()
    CaptchaHelper.write_to_cookie(ngx, captcha.encrypted)

    local width = tonumber(self.request.get and self.request.get.width) or captcha_config.width or 120
    local height = tonumber(self.request.get and self.request.get.height) or captcha_config.height or 80

    return self:json({
        success = true,
        message = 'Captcha code generated',
        expires_in = captcha_config.expires or 300,
        format = 'PNG',
        dimensions = {
            width = width,
            height = height
        },
        captcha = {
            code = captcha.code,
            cookie_name = CaptchaHelper.get_cookie_name()
        }
    })
end

function CaptchaController:verify()
    local input = self.request.post and self.request.post.code

    if not input or input == '' then
        return self:json({
            success = false,
            error = 'Captcha code is required'
        }, 400)
    end

    local is_valid, message = CaptchaHelper.validate(input, ngx)

    if is_valid then
        return self:json({
            success = true,
            message = message
        })
    else
        return self:json({
            success = false,
            error = message
        }, 400)
    end
end

function CaptchaController:refresh()
    local captcha_config = self.config.captcha or {}

    local new_code = CaptchaHelper.refresh(ngx)

    local width = tonumber(self.request.get and self.request.get.width) or captcha_config.width or 120
    local height = tonumber(self.request.get and self.request.get.height) or captcha_config.height or 80

    local image = CaptchaHelper.get_captcha_image(new_code, width, height, captcha_config)

    if not image then
        return self:json({
            success = false,
            error = 'Failed to generate captcha image'
        }, 500)
    end

    self:header('Content-Type', 'image/png')
    self:header('Cache-Control', 'no-store, no-cache, must-revalidate')
    self:header('Pragma', 'no-cache')
    self:header('Expires', '0')

    return image.data
end

function CaptchaController:verifyAjax()
    local input = self.request.post and self.request.post.code

    if not input or input == '' then
        return self:json({
            valid = false,
            message = '验证码不能为空'
        })
    end

    local is_valid, message = CaptchaHelper.validate(input, ngx)

    return self:json({
        valid = is_valid,
        message = message
    })
end

return CaptchaController
