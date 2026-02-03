local BaseController = require('app.core.Controller')
local Session = require('app.lib.session')

local SessionController = {}

function SessionController:index()
    local session = Session:new()

    return self:json({
        success = true,
        message = 'Session API',
        endpoints = {
            ['GET /session'] = 'Get session info',
            ['POST /session/set'] = 'Set session value',
            ['POST /session/get'] = 'Get session value',
            ['POST /session/remove'] = 'Remove session key',
            ['POST /session/clear'] = 'Clear all session data',
            ['POST /session/regenerate'] = 'Regenerate session ID',
            ['POST /session/destroy'] = 'Destroy session',
            ['POST /session/flash/set'] = 'Set flash message',
            ['POST /session/flash/get'] = 'Get flash message',
            ['POST /session/touch'] = 'Touch session (extend expiry)',
        },
        session_id = session:get_id(),
        is_new = session:is_new(),
        data_count = session:count()
    })
end

function SessionController:set()
    local key = self:request():post('key')
    local value = self:request():post('value')

    if not key then
        return self:json({
            success = false,
            error = 'Key is required'
        }, 400)
    end

    local session = Session:new()
    session:set(key, value)
    session:save()

    return self:json({
        success = true,
        message = 'Session value set',
        key = key,
        value = value
    })
end

function SessionController:get()
    local key = self:request():post('key')

    local session = Session:new()

    if not key then
        return self:json({
            success = true,
            message = 'All session data',
            data = session:get_all_data()
        })
    end

    local value = session:get(key)

    if value == nil then
        return self:json({
            success = false,
            error = 'Key not found'
        }, 404)
    end

    return self:json({
        success = true,
        key = key,
        value = value
    })
end

function SessionController:remove()
    local key = self:request():post('key')

    if not key then
        return self:json({
            success = false,
            error = 'Key is required'
        }, 400)
    end

    local session = Session:new()
    local existed = session:has(key)
    session:remove(key)
    session:save()

    return self:json({
        success = true,
        message = existed and 'Key removed' or 'Key did not exist',
        key = key
    })
end

function SessionController:clear()
    local session = Session:new()
    session:clear()
    session:save()

    return self:json({
        success = true,
        message = 'Session cleared'
    })
end

function SessionController:regenerate()
    local session = Session:new()
    local old_id = session:get_id()
    local new_id = session:regenerate()
    session:save()

    return self:json({
        success = true,
        message = 'Session ID regenerated',
        old_session_id = old_id,
        new_session_id = new_id
    })
end

function SessionController:destroy()
    local session = Session:new()
    session:destroy()

    return self:json({
        success = true,
        message = 'Session destroyed'
    })
end

function SessionController:setFlash()
    local key = self:request():post('key')
    local value = self:request():post('value')

    if not key then
        return self:json({
            success = false,
            error = 'Key is required'
        }, 400)
    end

    local session = Session:new()
    session:set_flash(key, value)
    session:save()

    return self:json({
        success = true,
        message = 'Flash message set (available on next request)',
        key = key,
        value = value
    })
end

function SessionController:getFlash()
    local key = self:request():post('key')

    if not key then
        return self:json({
            success = false,
            error = 'Key is required'
        }, 400)
    end

    local session = Session:new()
    local value = session:get_flash(key)

    if value == nil then
        return self:json({
            success = false,
            error = 'Flash message not found or expired'
        }, 404)
    end

    return self:json({
        success = true,
        key = key,
        value = value
    })
end

function SessionController:touch()
    local session = Session:new()
    session:touch()

    return self:json({
        success = true,
        message = 'Session extended',
        session_id = session:get_id()
    })
end

function SessionController:counter()
    local session = Session:new()

    local count = session:get('page_views') or 0
    count = count + 1
    session:set('page_views', count)
    session:save()

    return self:json({
        success = true,
        page_views = count,
        session_id = session:get_id()
    })
end

function SessionController:userLogin()
    local username = self:request():post('username')
    local password = self:request():post('password')

    if not username or not password then
        return self:json({
            success = false,
            error = 'Username and password required'
        }, 400)
    end

    local session = Session:new()
    session:set('user', {
        username = username,
        logged_in = true,
        login_time = os.time()
    })
    session:save()

    return self:json({
        success = true,
        message = 'Logged in successfully',
        user = {
            username = username,
            logged_in = true
        }
    })
end

function SessionController:userInfo()
    local session = Session:new()
    local user = session:get('user')

    if not user or not user.logged_in then
        return self:json({
            success = false,
            error = 'Not logged in'
        }, 401)
    end

    return self:json({
        success = true,
        user = user
    })
end

function SessionController:userLogout()
    local session = Session:new()
    session:remove('user')
    session:save()

    return self:json({
        success = true,
        message = 'Logged out successfully'
    })
end

return SessionController
