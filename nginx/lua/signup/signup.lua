local postgre = require "db.postgre"
local cjson = require "cjson.safe"
local jwt = require "middleware.jwt"

ngx.req.read_body()
local body = ngx.req.get_body_data()
local data = cjson.decode(body)
local secret = os.getenv("JWT_SECRET")

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

-- 예시: 사용자 이메일 중복 체크 & 삽입
local res = db:query(string.format(
    "SELECT * FROM users WHERE email = %s", ngx.quote_sql_str(data.email)
))
if res and #res > 0 then
    ngx.status = ngx.HTTP_CONFLICT
    ngx.say(cjson.encode({ error = "Email already exists" }))
    return
end

function custom_random_jti(length)
    local chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
    local result = {}

    for i = 1, length do
        local rand = math.random(1, #chars)
        table.insert(result, chars:sub(rand, rand))
    end

    return table.concat(result)
end

local jti = custom_random_jti(32)


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

local user_id = insert_res[1].id
local user_status = insert_res[1].status
local is_global_seller = insert_res[1].is_global_seller

local distinct_id = insert_res[1].distinct_id

-- main_profiles에 insert
local insert_profile_sql = string.format([[
    INSERT INTO main_profiles (user_id, nickname)
    VALUES (%d, %s) RETURNING id
]], user_id, ngx.quote_sql_str(data.nickname))

local main_profile_res = db:query(insert_profile_sql)

local main_profile_id = main_profile_res[1].id

-- JWT 생성
local token, err = jwt.sign({
    aud = "publ",
    exp = ngx.time() + 3600,
    iat = ngx.time(),
    iss = "publ",
    jti = jti,
    nbf = ngx.time() - 1,
    seller = {
        distinctId = distinct_id,
        email = data.email,
        id = user_id,
        identity = "IDENTITY:" .. data.type .. ":" .. user_id,
        isGlobalSeller = is_global_seller,
        mainProfile = {
            id = main_profile_id,
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
        status = user_status,
        type = data.type
    },
    sub = data.type .. ":" .. tostring(user_id),
    typ = "access"
})

if not token then
    ngx.log(ngx.ERR, "[JWT ERROR] failed to issue token: ", err)
    ngx.log(ngx.ERR, "secret_key: ", secret)
    ngx.status = ngx.HTTP_INTERNAL_SERVER_ERROR
    ngx.say(cjson.encode({ error = "Failed to issue token", message = err }))
    return
end

ngx.log(ngx.ERR, "[JWT] token: ", token)

-- 응답
ngx.status = ngx.HTTP_OK
ngx.say(cjson.encode({
    message = "User registered successfully",
    token = token
}))
