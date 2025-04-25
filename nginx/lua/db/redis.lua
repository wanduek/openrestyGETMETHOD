local redis = require "resty.redis"
local _M = {}

-- Redis 서버와 연결
function _M.connect()
    local red = redis:new()
    if not red then
        ngx.log(ngx.ERR, "Redis not create instance")
        return nil, "Redis not create instance"
    end

    red:set_timeout(1000)  -- 1초 타임아웃 설정

    local host = os.getenv("REDIS_HOST")
    local port = tonumber(os.getenv("REDIS_PORT"))

    -- 환경 변수 확인
    if not host then
        ngx.log(ngx.ERR, "REDIS_HOST not environment.")
        return nil, "REDIS_HOST not environment."
    end

    if not port then
        ngx.log(ngx.ERR, "REDIS_PORT not environment.")
        return nil, "REDIS_PORT not environment."
    end

    -- Redis 연결 로그
    ngx.log(ngx.INFO, "Connecting to Redis at " .. host .. ":" .. port)

    -- Redis 서버와 연결
    local ok, err = red:connect(host, port)
    if not ok then
        ngx.log(ngx.ERR, "Redis connection failed: " .. (err or "unknown error"))
        return nil, "Redis connection failed: " .. (err or "unknown error")
    end

    return red
end

    

function _M.get(key)
    local red, err = _M.connect()
    if not red then return nil, err end

    local res, err = red:get(key)
    if err then return nil, err end
    if res == ngx.null then return nil, "No cache" end

    return res
end

function _M.set(key, value, exptime)
    local red, err = _M.connect()
    if not red then return nil, err end

    local ok, err = red:set(key, value)
    if not ok then return nil, err end

    if exptime then
        red:expire(key, exptime)  -- TTL 설정
    end

    return true
end

function _M.join_channel(channel_id, user_id)
    local red, err = _M.connect()
    if not red then return nil, err end

    local key, err = red:sadd(key, user_id)
    if not res then return nil, err end

    return true
    
end

return _M