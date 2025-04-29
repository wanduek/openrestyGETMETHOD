local postgre = require "db.postgre"
local cjson = require "cjson.safe"
local jwt = require "middleware.jwt"
local ramdom_jti = require "signup.signup"

ngx.req.read_body()
local body = ngx.req.get_body_data()
local data = cjson.decode(body)

if not data or not data.email or not data.password then
    ngx.status = ngx.HTTP_BAD_REQUEST
    ngx.say(cjson.encode({ error = "Email and password required" }))
    return
end

-- DB 연결
local db, err = postgre.new()
if not db then
    ngx.status = 500
    ngx.say(cjson.encode({ error = "Failed to connect to database" }))
    return
end

-- 이메일로 사용자 조회
local query = string.format(
    "SELECT id, email, password, distinct_id, type FROM users WHERE email = %s",
    ngx.quote_sql_str(data.email)
)
local res = db:query(query)

if not res or #res == 0 then
    ngx.status = ngx.HTTP_UNAUTHORIZED
    ngx.say(cjson.encode({ error = "Invalid email or password" }))
    return
end

local user_id = res[1].id
local distinct_id = res[1].distinct_id
local type = res[1].type
local role = res[1].role

-- 비밀번호 비교
if user.password ~= data.password then
    ngx.status = ngx.HTTP_UNAUTHORIZED
    ngx.say(cjson.encode({ error = "Invalid email or password" }))
    return
end

local jti = ramdom_jti.custom_random_jti()

-- mainProfile 조회
local main_profile_query = string.format(
    "SELECT id, nickname FROM main_profile"
)

local main_profile_res = db:query(main_profile_query)

local main_profile_id = main_profile_res[1].id
local main_profile_nickname = main_profile_res[1].nickname

-- JWT 생성
local token = jwt.sign({
    aud = "publ",
    exp = ngx.time() + 3600,
    iat = ngx.time(),
    iss = "publ",
    jti = jti,
    nbf = ngx.time() - 1,
    seller = {
        distinctId = distinct_id ,
        email = data.email,
        id = user_id,
        identity = "IDENTITY:" .. type .. ":" .. user_id,
        isGlobalSeller = "false",
        mainProfile = {
            id = main_profile_id,
            nickname = main_profile_nickname
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
        role = role,
        status = "NORMAL",
        type = type
    },
    sub = tostring(user_id),
    typ = "access"
})

ngx.status = ngx.HTTP_OK
ngx.say(cjson.encode({
    message = "Signin successful",
    token = token
}))
