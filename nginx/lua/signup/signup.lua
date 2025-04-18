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
local db, err = postgre.new()
if not db then
    ngx.status = 500
    ngx.say(cjson.encode({ error = "Failed to connect to database" }))
    return
end

-- 예시: 사용자 이메일 중복 체크 & 삽입
local res, err = db:query(string.format(
    "SELECT * FROM users WHERE email = %s", ngx.quote_sql_str(data.email)
))
if res and #res > 0 then
    ngx.status = ngx.HTTP_CONFLICT
    ngx.say(cjson.encode({ error = "Email already exists" }))
    return
end

-- 사용자 정보 삽입 
local insert_sql = string.format(
    "INSERT INTO users (email, password, channel_id) VALUES (%s, %s, %s) RETURNING id",
    ngx.quote_sql_str(data.email),
    ngx.quote_sql_str(data.password),
    ngx.quote_sql_str(data.channel_id)
)
local insert_res = db:query(insert_sql)

if not insert_res or not insert_res[1] then
    ngx.status = 500
    ngx.say(cjson.encode({ error = "Failed to insert user" }))
    return
end

local user_id = insert_res[1].id

-- JWT 생성
local token, err = jwt.sign({
    sub = tostring(user_id),
    email = data.email,
    channel_id = data.channel_id,
    iat = ngx.time(),
    exp = ngx.time() + 3600 -- 1시간 유효
})

if not token then
    ngx.log(ngx.ERR, "[JWT ERROR] failed to issue token: ", err)
    ngx.log(ngx.ERR, "secret_key: ", secret)
    ngx.status = ngx.HTTP_INTERNAL_SERVER_ERROR
    ngx.say(cjson.encode({ error = "Failed to issue token", message = err}))
    return 
end

ngx.log(ngx.ERR, "[JWT] token: ", token)

-- 응답
ngx.status = ngx.HTTP_OK
ngx.say(cjson.encode({
    message = "User registered successfully",
    token = token
}))
