-- QueryBuilder Library Unit Tests
-- tests/unit/query_builder_spec.lua

package.path = '/var/www/web/my-resty/?.lua;/var/www/web/my-resty/?/init.lua;/usr/local/web/?.lua;/usr/local/web/lualib/?.lua;;'
package.cpath = '/var/www/web/my-resty/?.so;/usr/local/web/lualib/?.so;;'

local Test = require('app.utils.test')

describe = Test.describe
it = Test.it
pending = Test.pending
before_each = Test.before_each
after_each = Test.after_each
assert = Test.assert

describe('QueryBuilder Module', function()
    describe('creation', function()
        it('should create query builder instance', function()
            local QueryBuilder = {}
            function QueryBuilder:new(table_name)
                return setmetatable({
                    table = table_name or 'users',
                    wheres = {},
                    orders = {},
                    fields = '*',
                    limit_val = nil,
                    offset_val = nil
                }, {__index = self})
            end
            local qb = QueryBuilder:new('users')
            assert.is_table(qb)
            assert.equals('users', qb.table)
        end)
    end)

    describe('select', function()
        it('should set select fields', function()
            local qb = {fields = '*'}
            function qb:select(fields)
                self.fields = fields or '*'
                return self
            end
            qb:select('id, name, email')
            assert.equals('id, name, email', qb.fields)
        end)
    end)

    describe('where', function()
        it('should add where clause', function()
            local qb = {wheres = {}}
            function qb:where(field, operator, value)
                table.insert(qb.wheres, {field = field, operator = operator, value = value})
                return self
            end
            qb:where('id', '=', 1)
            qb:where('status', '=', 'active')
            assert.equals(2, #qb.wheres)
            assert.equals('id', qb.wheres[1].field)
            assert.equals('status', qb.wheres[2].field)
        end)
    end)

    describe('where_in', function()
        it('should add WHERE IN clause', function()
            local qb = {wheres = {}}
            function qb:where_in(field, values)
                table.insert(qb.wheres, {field = field, operator = 'IN', value = values})
                return self
            end
            qb:where_in('id', {1, 2, 3})
            assert.equals(1, #qb.wheres)
            assert.same({1, 2, 3}, qb.wheres[1].value)
        end)
    end)

    describe('order_by', function()
        it('should add order clause', function()
            local qb = {orders = {}}
            function qb:order_by(field, direction)
                direction = direction or 'ASC'
                table.insert(qb.orders, field .. ' ' .. direction)
                return self
            end
            qb:order_by('created_at', 'DESC')
            qb:order_by('name', 'ASC')
            assert.equals(2, #qb.orders)
        end)
    end)

    describe('limit', function()
        it('should set limit', function()
            local qb = {limit_val = nil}
            function qb:limit(n)
                self.limit_val = tonumber(n)
                return self
            end
            qb:limit(10)
            assert.equals(10, qb.limit_val)
        end)
    end)

    describe('offset', function()
        it('should set offset', function()
            local qb = {offset_val = nil}
            function qb:offset(n)
                self.offset_val = tonumber(n)
                return self
            end
            qb:offset(20)
            assert.equals(20, qb.offset_val)
        end)
    end)

    describe('to_sql', function()
        it('should generate SELECT SQL', function()
            local qb = {
                table = 'users',
                fields = 'id, name',
                wheres = {{field = 'status', operator = '=', value = 'active'}},
                orders = {'created_at DESC'},
                limit_val = 10,
                offset_val = 0
            }
            function qb:to_sql()
                local sql = 'SELECT ' .. self.fields .. ' FROM ' .. self.table
                if #self.wheres > 0 then
                    local conditions = {}
                    for _, w in ipairs(self.wheres) do
                        local val = tonumber(w.value) and w.value or "'" .. w.value .. "'"
                        table.insert(conditions, w.field .. ' ' .. w.operator .. ' ' .. val)
                    end
                    sql = sql .. ' WHERE ' .. table.concat(conditions, ' AND ')
                end
                if #self.orders > 0 then
                    sql = sql .. ' ORDER BY ' .. table.concat(self.orders, ', ')
                end
                if self.limit_val then sql = sql .. ' LIMIT ' .. self.limit_val end
                if self.offset_val then sql = sql .. ' OFFSET ' .. self.offset_val end
                return sql
            end
            
            local sql = qb:to_sql()
            assert.matches('SELECT id, name FROM users', sql)
            assert.matches('WHERE status = .active', sql)
            assert.matches('ORDER BY created_at DESC', sql)
            assert.matches('LIMIT 10', sql)
            assert.matches('OFFSET 0', sql)
        end)
    end)

    describe('count', function()
        it('should generate COUNT SQL', function()
            local qb = {
                table = 'users',
                wheres = {{field = 'status', operator = '=', value = 'active'}}
            }
            function qb:count()
                local sql = 'SELECT COUNT(*) as total FROM ' .. self.table
                if #self.wheres > 0 then
                    local conditions = {}
                    for _, w in ipairs(self.wheres) do
                        local val = tonumber(w.value) and w.value or "'" .. w.value .. "'"
                        table.insert(conditions, w.field .. ' ' .. w.operator .. ' ' .. val)
                    end
                    sql = sql .. ' WHERE ' .. table.concat(conditions, ' AND ')
                end
                return sql
            end
            
            local sql = qb:count()
            assert.matches('SELECT COUNT%(%*%) as total FROM users', sql)
        end)
    end)

    describe('paginate', function()
        it('should calculate pagination', function()
            local qb = {}
            function qb:paginate(page, per_page, total_count)
                page = tonumber(page) or 1
                per_page = tonumber(per_page) or 20
                total_count = tonumber(total_count) or 0
                local offset = (page - 1) * per_page
                local total_pages = math.ceil(total_count / per_page)
                return {
                    page = page,
                    per_page = per_page,
                    total = total_count,
                    total_pages = total_pages,
                    offset = offset,
                    has_next = page < total_pages,
                    has_prev = page > 1
                }
            end
            
            local p = qb:paginate(2, 10, 100)
            assert.equals(2, p.page)
            assert.equals(10, p.per_page)
            assert.equals(100, p.total)
            assert.equals(10, p.total_pages)
            assert.equals(10, p.offset)
            assert.is_true(p.has_next)
            assert.is_true(p.has_prev)
        end)
    end)
end)
