local Controller = require('app.core.Controller')
local QueryBuilder = require('app.db.query')

local _M = {}

function _M:index()
    local sql = QueryBuilder.new('users')
        :select('id', 'name', 'email')
        :where('status', 'active')
        :order_by('created_at', 'DESC')
        :limit(10)
        :to_sql()

    self:json({
        example = 'basic_select',
        sql = sql
    })
end

function _M:joins()
    local sql = QueryBuilder.new('users')
        :select('users.id', 'users.name', 'orders.total')
        :left_join('orders')
        :on('users.id', '=', 'orders.user_id')
        :where('users.status', 'active')
        :where('orders.status', 'pending')
        :order_by('users.name')
        :to_sql()

    self:json({
        example = 'join',
        sql = sql
    })
end

function _M:where_conditions()
    local sql = QueryBuilder.new('products')
        :select('*')
        :where('price', '>', 100)
        :where('category_id', 1)
        :or_where('category_id', 2)
        :where_in('status', {'active', 'pending'})
        :like('name', '%test%')
        :order_by('price', 'ASC')
        :to_sql()

    self:json({
        example = 'where_conditions',
        sql = sql
    })
end

function _M:aggregates()
    self:json({
        message = 'Use Model:count() for aggregates',
        example = 'model:count({ status = "active" })',
        note = 'QueryBuilder no longer provides count/sum/avg/max methods. Use Model layer directly.'
    })
end

function _M:insert_example()
    self:json({
        message = 'Use Model:insert() for inserts',
        example = 'model:set_table("users"):insert({ name = "John" })',
        note = 'QueryBuilder no longer provides insert method. Use Model layer directly.'
    })
end

function _M:update_example()
    self:json({
        message = 'Use Model:update() for updates',
        example = 'model:update({ name = "New" }, { id = 1 })',
        note = 'QueryBuilder no longer provides update method. Use Model layer directly.'
    })
end

function _M:delete_example()
    self:json({
        message = 'Use Model:delete() for deletes',
        example = 'model:delete({ status = "deleted" })',
        note = 'QueryBuilder no longer provides delete method. Use Model layer directly.'
    })
end

function _M:complex_query()
    local sql = QueryBuilder.new('orders')
        :select(
            'orders.id',
            'orders.total',
            'users.name as user_name',
            'products.name as product_name'
        )
        :distinct()
        :from('orders')
        :join('users')
        :on('orders.user_id', '=', 'users.id')
        :left_join('order_items')
        :on('orders.id', '=', 'order_items.order_id')
        :left_join('products')
        :on('order_items.product_id', '=', 'products.id')
        :where('orders.status', 'completed')
        :where('users.status', 'active')
        :group_by('orders.id')
        :having('orders.total', '>', 100)
        :order_by('orders.created_at', 'DESC')
        :limit(20)
        :to_sql()

    self:json({
        complex_query = sql
    })
end

function _M:raw_expressions()
    local sql = QueryBuilder.new('users')
        :select('*')
        :where_raw('DATE(created_at) = CURDATE()')
        :order_by_raw('FIELD(priority, "high", "medium", "low")')
        :to_sql()

    self:json({
        raw_expressions = sql
    })
end

function _M:select()
    local builder = QueryBuilder.new('users')
    local sql = builder
        :select('id', 'name', 'email', 'status', 'created_at')
        :where('status', 'active')
        :order_by('created_at', 'DESC')
        :limit(10)
        :to_sql()

    local db = Mysql:new()
    local ok, err = db:connect()

    if not ok then
        return self:json({
            success = false,
            error = 'Database connection failed',
            message = err
        }, 500)
    end

    local rows, err, errno = db:query(sql)
    db:set_keepalive()

    if err then
        return self:json({
            success = false,
            error = 'Query failed',
            message = err,
            errno = errno
        }, 500)
    end

    return self:json({
        success = true,
        data = rows or {},
        sql = sql,
        count = #rows or 0
    })
end

return _M
