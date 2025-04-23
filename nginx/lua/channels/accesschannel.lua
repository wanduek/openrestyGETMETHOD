local jwt = require "middleware.jwt"
local postgres = require "db.postgre"
local cjson = require "cjson.safe"

local _M = {}

function _M.verify_channel_access()
    -- JWT 토큰에서 payload 추출
    local token = jwt.get_token_from_request()
    local ok, claims = jwt.verify(token)

    if not ok then
        ngx.status = ngx.HTTP_UNAUTHORIZED
        ngx.say(cjson.encode({ error = "Invalid JWT token" }))
        ngx.exit(ngx.HTTP_UNAUTHORIZED)
        return 
    end

    local user_channel_id = claims.channelId
    if not user_channel_id then
        ngx.status = ngx.HTTP_FORBIDDEN
        ngx.say(cjson.encode({ error = "No channelId in JWT token" }))
        ngx.exit(ngx.HTTP_FORBIDDEN)
        return 
    end

    -- PostgreSQL 접속
    local db, err = postgres.new()
    if not db then
        ngx.status = ngx.HTTP_INTERNAL_SERVER_ERROR
        ngx.say(cjson.encode({ error = "DB connection failed: " .. err }))
        ngx.exit(500)
        return 
    end

    -- DB에서 channel 이름 확인
    local channel_id = claims.channelId
    local sql = "SELECT * FROM channels WHERE name LIKE '" .. ngx.escape_uri(channel_id) .. "'"
    local res = db:query(sql, { channel_id })

    if not res or #res == 0 then
        ngx.status = ngx.HTTP_FORBIDDEN
        ngx.say(cjson.encode({ error = "Channel not found or unauthorized" }))
        ngx.exit(ngx.HTTP_FORBIDDEN)
        return 
    end

    return true, claims
end

return _M
