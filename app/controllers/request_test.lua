local Controller = require('app.core.Controller')

local _M = {}

function _M:index()
    self:json({
        message = 'Request API Test',
        methods = {
            'get - Test GET parameters',
            'post_form - Test form POST',
            'post_json - Test JSON POST',
            'mixed - Test mixed data',
            'all - Test all input'
        }
    })
end

function _M:get()
    local Request = require('app.core.Request')
    local page = Request.get.page or 1
    local limit = Request.get.limit or 10
    local search = Request.get.q or ''

    self:json({
        type = 'GET',
        params = {
            page = tonumber(page),
            limit = tonumber(limit),
            q = search
        },
        message = 'GET parameters received'
    })
end

function _M:post_form()
    local Request = require('app.core.Request')
    local name = Request.post.name or ''
    local email = Request.post.email or ''
    local password = Request.post.password or ''

    self:json({
        type = 'POST_FORM',
        content_type = Request:header('Content-Type') or 'application/x-www-form-urlencoded',
        params = {
            name = name,
            email = email,
            has_password = password ~= ''
        },
        message = 'Form data received'
    })
end

function _M:post_json()
    local Request = require('app.core.Request')
    local json_data = Request:json_body()
    local is_json = Request:is_json()

    self:json({
        type = 'POST_JSON',
        is_json_request = is_json,
        content_type = Request:header('Content-Type'),
        json_data = json_data,
        message = 'JSON data received'
    })
end

function _M:mixed()
    local Request = require('app.core.Request')
    local all = Request:all_input()
    local page = Request.get.page
    local name = Request.json.name
    local email = Request.post.email

    self:json({
        type = 'MIXED',
        is_json = Request:is_json(),
        get_params = {
            page = tonumber(page) or nil
        },
        json_params = {
            name = name
        },
        post_params = {
            email = email
        },
        all_input = all,
        has_all = Request:has('page') and Request:has('name') and Request:has('email')
    })
end

function _M:all()
    local Request = require('app.core.Request')
    local all = Request:all_input()
    local only = Request:only('name', 'email')
    local except = Request:except('password', 'secret')

    self:json({
        type = 'ALL_INPUT',
        all = all,
        only = only,
        except_password = except,
        message = 'All input methods demonstrated'
    })
end

return _M
