local postgre = require "db.postgre"
local cjson = require "cjson.safe"
local jwt = require "middleware.jwt"
local lua_query = require "lua_query"
local response = require "response"

-- 요청 메서드 확인
if ngx.req.get_method() ~= "POST" then
    return response.method_not_allowed("Method not allowed")
end

ngx.req.read_body()
local body = ngx.req.get_body_data()
local data = cjson.decode(body)

if not data or not data.email or not data.password then
    return response.bad_request("Email and password required")
end

-- DB 연결
local db = postgre.new()

-- 이메일로 사용자 조회
local query = string.format(
    "SELECT * FROM users WHERE email = %s",
    ngx.quote_sql_str(data.email)
)
local res = db:query(query)
if not res or #res == 0 then
    return response.unauthorized("Invalid email")
end

local user = res[1]

-- 비밀번호 비교
if res[1].password ~= data.password then
    return response.unauthorized("Invalid password")
end

local main_profile = lua_query.get_main_profile(db, user.id)

-- 커넥션 풀에 반납
postgre.keepalive(db)

-- jti 생성
local jti = jwt.custom_random_jti(32)

-- JWT 생성
local payload = jwt.sign({
    aud = "publ",
    exp = ngx.time() + 3600,
    iat = ngx.time(),
    iss = "publ",
    jti = jti,
    nbf = ngx.time() - 1,
    seller = {
        distinctId = user.distinct_id ,
        email = data.email,
        id = user.id,
        identity = "IDENTITY:" .. user.type .. ":" .. user.id,
        isGlobalSeller = user.is_global_seller,
        mainProfile = {
            id = main_profile.id,
            nickname = main_profile.nickname
        },
        pAppAdditionalPermissions = {
            ["*"] = true
        },
        pAppPermission = {
            "*"
        },
        permissions = {
            "*"
        },
        role = user.role,
        status = user.status,
        type = user.type
    },
    sub = user.type .. ":" .. tostring(user.id),
    typ = "access"
})

local success_data = {
    message = "Signin successful",
    token = payload
}

response.success(success_data)

