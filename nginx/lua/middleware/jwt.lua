local jwt = require "resty.jwt"
local cjson = require "cjson.safe"

local _M = {}

-- JWT 생성 (sign)
function _M.sign(payload)
    local secret_raw = os.getenv("JWT_SECRET")
    local secret = ngx.decode_base64(secret_raw) or secret_raw

    if not secret then
        ngx.log(ngx.ERR, "[JWT] Invalid JWT secret")
        return nil, "Invalid JWT secret"
    end

    ngx.log(ngx.INFO, "[JWT] Signing payload: ", cjson.encode(payload))
    ngx.log(ngx.INFO, "[JWT] Using secret: ", secret)

    local ok, token_or_err = pcall(jwt.sign, jwt, secret, {
        header = { typ = "JWT", alg = "HS256" },
        payload = payload
    })

    if not ok then
        ngx.log(ngx.ERR, "[JWT ERROR] sign failed: ", token_or_err)
        return nil, "Failed to create token"
    end

    if not token_or_err or type(token_or_err) ~= "string" then
        ngx.log(ngx.ERR, "[JWT ERROR] invalid token return: ", cjson.encode(token_or_err))
        return nil, "Invalid token format"
    end

    return token_or_err
end

-- JWT 검증 (verify)
function _M.verify(token)
    if not token or token == "" then
        ngx.status = ngx.HTTP_UNAUTHORIZED
        ngx.header.content_type = "application/json; charset=utf-8"
        ngx.say("{\"error\": \"Missing JWT token\"}")
        ngx.exit(ngx.HTTP_UNAUTHORIZED)
    end

    local secret_raw = os.getenv("JWT_SECRET")
    local secret = ngx.decode_base64(secret_raw) or secret_raw

    local jwt_obj = jwt:verify(secret, token)

    if not jwt_obj["verified"] then
        ngx.status = ngx.HTTP_UNAUTHORIZED
        ngx.log(ngx.WARN, jwt_obj.reason)
        ngx.header.content_type = "application/json; charset=utf-8"
        ngx.say("{\"error\": \"" .. jwt_obj.reason .. "\"}")
        ngx.exit(ngx.HTTP_UNAUTHORIZED)
    end

    local payload = jwt_obj.payload

    return true, payload
end

-- JWT 토큰 받기
function _M.get_token_from_request()
    -- 첫 번째: URL 파라미터에서 가져오기
    local token = ngx.var.arg_token

    -- 두 번째: 쿠키에서 가져오기
    if not token then
        token = ngx.var.cookie_token
    end

    -- 세 번째: Authorization 헤더에서 가져오기
    if not token then
        -- local auth_header = ngx.var.http_Authorization
        local headers = ngx.req.get_headers()
        local auth_header = headers["Authorization"]
        if not auth_header or type(auth_header) == "table" then
            ngx.status = ngx.HTTP_UNAUTHORIZED
            ngx.header.content_type = "application/json"
            ngx.say("{\"error\": \"Invalid Authorization header\"}")
            ngx.exit(ngx.HTTP_UNAUTHORIZED)
        end

        local _, _, bearer_token = string.find(auth_header, "Bearer%s+(.+)")

        if not bearer_token then
            ngx.status = ngx.HTTP_UNAUTHORIZED
            ngx.header.content_type = "application/json"
            ngx.say("{\"error\": \"Malformed Authorization header\"}")
            ngx.exit(ngx.HTTP_UNAUTHORIZED)
        end

        token = bearer_token
    end


    -- 토큰이 없다면 401 오류 반환
    if not token then
        ngx.status = ngx.HTTP_UNAUTHORIZED
        ngx.header.content_type = "application/json"
        ngx.say("{\"error\": \"Missing JWT token\"}")
        ngx.exit(ngx.HTTP_UNAUTHORIZED)
    end

    return token
end

function _M.custom_random_jti(length)
    local chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
    local result = {}

    for i = 1, length do
        local rand = math.random(1, #chars)
        table.insert(result, chars:sub(rand, rand))
    end

    return table.concat(result)
end

return _M
