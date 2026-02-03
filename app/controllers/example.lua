local Controller = require('app.core.Controller')
local QueryBuilder = require('app.core.QueryBuilder')

local _M = {}

function _M:index()
    local sql = QueryBuilder.new('users')
        :select('id', 'name', 'email')
        :where('status', 'active')
        :order_by('created_at', 'DESC')
        :limit(10)
        :get_sql()

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
        :get_sql()

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
        :where_null('deleted_at')
        :like('name', '%test%')
        :order_by('price', 'ASC')
        :get_sql()

    self:json({
        example = 'where_conditions',
        sql = sql
    })
end

function _M:aggregates()
    local count_sql = QueryBuilder.new('users'):count()
    local sum_sql = QueryBuilder.new('orders'):sum('total')
    local avg_sql = QueryBuilder.new('products'):avg('price')
    local max_sql = QueryBuilder.new('products'):max('price')

    self:json({
        count = count_sql,
        sum = sum_sql,
        avg = avg_sql,
        max = max_sql
    })
end

function _M:insert_example()
    local insert_sql = QueryBuilder.new('users'):insert({
        name = 'John Doe',
        email = 'john@example.com',
        status = 'active'
    })

    local batch_sql = QueryBuilder.new('users'):insert_batch({
        {name = 'User 1', email = 'user1@example.com'},
        {name = 'User 2', email = 'user2@example.com'},
    })

    self:json({
        insert = insert_sql,
        batch_insert = batch_sql
    })
end

function _M:update_example()
    local sql = QueryBuilder.new('users')
        :where('id', 1)
        :update({
            name = 'Updated Name',
            status = 'inactive'
        })

    self:json({
        update = sql
    })
end

function _M:delete_example()
    local sql = QueryBuilder.new('users')
        :where('status', 'deleted')
        :delete()

    self:json({
        delete = sql
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
        :get_sql()

    self:json({
        complex_query = sql
    })
end

function _M:raw_expressions()
    local sql = QueryBuilder.new('users')
        :select('*')
        :where_raw('DATE(created_at) = CURDATE()')
        :order_by_raw('FIELD(priority, "high", "medium", "low")')
        :get_sql()

    self:json({
        raw_expressions = sql
    })
end

return _M
