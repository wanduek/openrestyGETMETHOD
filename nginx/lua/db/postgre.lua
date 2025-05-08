local pg = require "resty.postgres"
local response = require "response"

local _M = {}

function _M.new()
    local db = pg:new()
    if not db then
        return nil, "Failed to create postgres object"
    end

    db:set_timeout(1000)

    local ok, err = db:connect({
        host = os.getenv("DB_HOST"),
        port = tonumber(os.getenv("DB_PORT")),
        database = os.getenv("DB_NAME"),
        user = os.getenv("DB_USER"),
        password = os.getenv("DB_PASSWORD")
    })

    if not ok then
        return response.internal_server_error("Failed to connect to database")
    end

    return db, nil
end

-- 커넥션 풀 반난 함수
function _M.keepalive(db)
    if not db then 
        return
    end
    local pool_timeout = 10000
    local pool_size = 50

    local ok, err =db:set_keepalive(pool_timeout, pool_size) -- 10초, 최대 50개 커넥션 풀링
    if not ok then
        ngx.log(ngx.ERR, "Failed to set keepalive: ", err)
    end
    
end

return _M
