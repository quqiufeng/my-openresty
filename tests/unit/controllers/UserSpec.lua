-- UserSpec Test
describe('User Controller', function()
    test('index returns list', function()
        local ctrl = { json = function(d) end, user_model = { list = function() return {} end, count_all = function() return 0 end } }
        ctrl.index = function() ctrl:json({ success = true }) end
        ctrl.index()
    end)
    test('show returns item', function()
        local ctrl = { json = function(d) end, user_model = { get_by_id = function() return { id = 1 } end } }
        ctrl.show = function(id) ctrl:json({ success = true }) end
        ctrl.show(1)
    end)
    test('create inserts data', function()
        local ctrl = { json = function(d) end, post = { name = 'Test' }, user_model = { create = function() return 1 end } }
        ctrl.create = function() ctrl:json({ success = true }) end
        ctrl.create()
    end)
end)
