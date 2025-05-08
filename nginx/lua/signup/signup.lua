local postgre = require "db.postgre"
local cjson = require "cjson.safe"
local jwt = require "middleware.jwt"
local response = require "response"

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
    return response.internal_server_error("Failed to connect to database")
end

-- 예시: 사용자 이메일 중복 체크 & 삽입
local res = db:query(string.format(
    "SELECT * FROM users WHERE email = %s", ngx.quote_sql_str(data.email)
))
if res and #res > 0 then
    ngx.status = ngx.HTTP_CONFLICT
    ngx.say(cjson.encode({ error = "Email already exists" }))
    return
end

local jti = jwt.custom_random_jti(32)

-- 사용자 정보 삽입
local insert_sql = string.format(
    "INSERT INTO users (email, password, role, type) VALUES (%s, %s, %s, %s) RETURNING id, distinct_id, status, is_global_seller",
    ngx.quote_sql_str(data.email),
    ngx.quote_sql_str(data.password),
    ngx.quote_sql_str(data.role),
    ngx.quote_sql_str(data.type)

)
local insert_res = db:query(insert_sql)

if not insert_res or not insert_res[1] or not insert_res[1].id then
    ngx.status = 500
    ngx.say(cjson.encode({ error = "Failed to insert user" }))
    return
end

local user = insert_res[1]

-- main_profiles에 insert
local insert_profile_sql = string.format([[
    INSERT INTO main_profiles (user_id, nickname)
    VALUES (%d, %s) RETURNING id
]], user_id, ngx.quote_sql_str(data.nickname))

local main_profile_res = db:query(insert_profile_sql)

local main_profile = main_profile_res[1]

-- JWT 생성
local token, err = jwt.sign({
    aud = "publ",
    exp = ngx.time() + 3600,
    iat = ngx.time(),
    iss = "publ",
    jti = jti,
    nbf = ngx.time() - 1,
    seller = {
        distinctId = user.distinct_id,
        email = data.email,
        id = user.id,
        identity = "IDENTITY:" .. data.type .. ":" .. user.id,
        isGlobalSeller = user.is_global_seller,
        mainProfile = {
            id = main_profile.id,
            nickname = data.nickname
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
        role = data.role,
        status = user.status,
        type = data.type
    },
    sub = data.type .. ":" .. tostring(user.id),
    typ = "access"
})

-- 응답
ngx.status = ngx.HTTP_OK
ngx.say(cjson.encode({
    message = "User registered successfully",
    token = token
}))
