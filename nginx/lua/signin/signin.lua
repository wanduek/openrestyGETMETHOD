local postgre = require "db.postgre"
local cjson = require "cjson.safe"
local jwt = require "middleware.jwt"

ngx.req.read_body()
local body = ngx.req.get_body_data()
local data = cjson.decode(body)

if not data or not data.email or not data.password or not data.channel_id then
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
    "SELECT id, email, password FROM users WHERE email = %s",
    ngx.quote_sql_str(data.email)
)
local res, err = db:query(query)

if not res or #res == 0 then
    ngx.status = ngx.HTTP_UNAUTHORIZED
    ngx.say(cjson.encode({ error = "Invalid email or password" }))
    return
end

local user = res[1]

-- 비밀번호 비교
if user.password ~= data.password then
    ngx.status = ngx.HTTP_UNAUTHORIZED
    ngx.say(cjson.encode({ error = "Invalid email or password" }))
    return
end

-- JWT 발급
local token = jwt.sign({
    sub = tostring(user.id),
    email = user.email,
    channel_id = user.channel_id,
    iat = ngx.time(),
    exp = ngx.time() + 3600
})

ngx.status = ngx.HTTP_OK
ngx.say(cjson.encode({
    message = "Signin successful",
    token = token
}))
