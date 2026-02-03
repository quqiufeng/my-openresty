local ok, err = ngx.timer.every(30, function()
    local log = ngx.log
    local INF = ngx.INFO

    log(INF, '[Worker] Running cleanup tasks')
end)

if not ok then
    ngx.log(ngx.ERR, 'Failed to create timer: ', err)
end
