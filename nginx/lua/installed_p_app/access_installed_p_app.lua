local jwt = require "middleware.jwt"

local token =jwt.get_token_from_request()
local _, payload = jwt.verify(token)
