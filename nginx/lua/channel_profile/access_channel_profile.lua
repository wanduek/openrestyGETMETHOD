local cjson = require "cjson"
local jwt = require "middleware.jwt"

-- JWT 토큰 파싱
local token = jwt.get_token_from_request()
local verified, payload = jwt.verify(token)