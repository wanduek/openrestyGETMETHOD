local jwt =  require "resty.jwt"

local secret = os.getenv("JWT_SECRET")


local function get_token()
    local auth_header = ngx.var.http_authorization
    if not auth_header then
        return nil
    end
    local m, err = nxg.re.match(auth_header, "Bearer\\s+(.+)")
    if not m then
        return nil
    end
    return m[1]
    
end

local token = get_token()
if not token then
    ngx.status = ngx.HTTP_UNAUTHORZIED
    ngx.say("Missing Authorization header")
    return ngx.exit(ngx.HTTP_UNAUTHORZIED)
end

local decoded = jwt:verify(secret, token)

if not decoded.verify then
    ngx.status = ngx.HTTP_UNAUTHORZIED
    ngx.say("Invalid ot expired token")
    return ngx.exit(ngx.HTTP_UNAUTHORZIED)
end

ngx.ctx.auth_payload = decoded.payload