local cjson = require "cjson.safe"

local _M = {}

-- 성공 응답
function _M.success(data)
    ngx.status = 200
    ngx.say(cjson.encode(data))
    return ngx.exit(200)
end

-- 생성 응답
function _M.created(data)
    ngx.status = 201
    ngx.say(cjson.encode(data))
    return ngx.exit(201)
end

-- 잘못된 요청
function bad_request(message)
    ngx.status = 400
    ngx.say(cjson.encode({ error = message }))
    return ngx.exit(400)    
end

-- 권한없음 응답
function _M.unauthorized(message)
    ngx.status = 401
    ngx.say(cjson.encode({ error = message }))
    return ngx.exit(401)
end

-- 접근 제한 응답
function _M.forbidden(message)
    ngx.status = 403
    ngx.say(cjson.encode({ error = message }))
    return ngx.exit(403)
end

-- 찾을 수 없음 
function _M.not_found(message)
    ngx.status = 404
    ngx.say(cjson.encode({ error = message }))
    return ngx.exit(404)
end

-- 허용되지 않은 메소드 
function _M.method_not_allowed(message)
    ngx.status = 405
    ngx.say(cjson.encode({ error = message }))
    return ngx.exit(405)
end

-- 중복 응답
function _M.conflict(message)
    ngx.status = 409
    ngx.say(cjson.encode({ error = message }))
    return ngx.exit(409)
end

-- 내부 서버 오류 응답
function _M.internal_server_error(message)
    ngx.status = 500
    ngx.say(cjson.encode({ error = message }))
    return ngx.exit(500)
end

-- 요청 수 초과 시 응답
function _M.too_many_requests(message)
    ngx.status = 429
    ngx.say(cjson.encode({ error = message }))
    return ngx.exit(429)
end

return _M