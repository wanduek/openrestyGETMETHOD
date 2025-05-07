local postgre = require "db.postgre"
local cjson = require "cjson.safe"
local jwt = require "middleware.jwt"
local lua_query = require "lua_query"

ngx.req.read_body()
local body = ngx.req.get_body_data()
local data = cjson.decode(body)

if not data or not data.email or not data.password then
    ngx.status = ngx.HTTP_BAD_REQUEST
    ngx.say(cjson.encode({ error = "Email and password required" }))
    return
end

-- DB 연결
local db = postgre.new()
if not db then
    ngx.status = 500
    ngx.say(cjson.encode({ error = "Failed to connect to database" }))
    return
end

-- 이메일로 사용자 조회
local query = string.format(
    "SELECT * FROM users WHERE email = %s",
    ngx.quote_sql_str(data.email)
)
local res = db:query(query)
if not res or #res == 0 then
    ngx.status = ngx.HTTP_UNAUTHORIZED
    ngx.say(cjson.encode({ error = "Invalid email or password" }))
    return
end

local user = res[1]

-- 비밀번호 비교
if res[1].password ~= data.password then
    ngx.status = ngx.HTTP_UNAUTHORIZED
    ngx.say(cjson.encode({ error = "Invalid email or password" }))
    return
end

local jti = jwt.custom_random_jti(32)

local main_profile, err= lua_query.get_main_profile(db, user.id)
if not main_profile then
    ngx.status = 404
    ngx.say(cjson.encode({ error = err }))
    return
end

-- JWT 생성
local token = jwt.sign({
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

ngx.status = 200
ngx.say(cjson.encode({
    message = "Signin successful",
    token = token
}))
