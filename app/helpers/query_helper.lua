local _M = {}

function _M.table(table_name)
    local QueryBuilder = require('app.core.QueryBuilder')
    return QueryBuilder.new(table_name)
end

function _M.qb(table_name)
    return _M.table(table_name)
end

function _M.db()
    local Model = require('app.core.Model')
    return Model:new()
end

function _M.query(sql)
    local db = _M.db()
    return db:query(sql)
end

function _M.select(sql)
    local db = _M.db()
    return db:query(sql)
end

function _M.insert(table, data)
    local QueryBuilder = require('app.core.QueryBuilder')
    return QueryBuilder.new(table):insert(data)
end

function _M.update(table, data, where)
    local QueryBuilder = require('app.core.QueryBuilder')
    return QueryBuilder.new(table):where(where):update(data)
end

function _M.delete(table, where)
    local QueryBuilder = require('app.core.QueryBuilder')
    return QueryBuilder.new(table):where(where):delete()
end

function _M.count(table, where)
    local QueryBuilder = require('app.core.QueryBuilder')
    local qb = QueryBuilder.new(table)
    if where then
        qb:where(where)
    end
    return qb:count()
end

function _M.transaction(callback)
    local db = _M.db()
    db:query('START TRANSACTION')
    local ok, err = pcall(callback)
    if ok then
        db:query('COMMIT')
        return true
    else
        db:query('ROLLBACK')
        return nil, err
    end
end

return _M
