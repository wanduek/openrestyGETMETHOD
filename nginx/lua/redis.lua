local redis = require "resty.redis"
local _M = {}

function _M.connect()
    local red = redis:new()
    red:set_timeout(1000)  -- 1초 타임아웃

    local ok, err = red:connect("redis-container", 6379)  -- Redis 서버와 연결
    if not ok then
        return nil, "Redis 연결 실패: " .. (err or "")
    end

    return red
end

function _M.get(key)
    local red, err = _M.connect()
    if not red then return nil, err end

    local res, err = red:get(key)
    if err then return nil, err end
    if res == ngx.null then return nil, "캐시 없음" end

    return res
end

function _M.set(key, value)
    local red, err = _M.connect()
    if not red then return nil, err end

    local ok, err = red:set(key, value, exptime)
    if not ok then return nil, err end

    if exptime then
        red:expire(key, exptime)  -- TTL 설정
    end

    return true
end

return _M