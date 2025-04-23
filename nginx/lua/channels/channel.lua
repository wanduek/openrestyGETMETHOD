local accesschannel = require "channels.accesschannel"
local cjson = require "cjson"



if ngx.req.get_method() ~= "POST" then
    ngx.status = 405
    ngx.header["Content-Type"] = "application/json"
    ngx.say(cjson.encode({
        error = "Method not allowed"
    }))
    return
end
    
local ok, payload_or_err = accesschannel.verify_channel_access()
if not ok then
    ngx.status = ngx.HTTP_FORBIDDEN
    ngx.say(cjson.encode({ error = payload_or_err}))
    ngx.exit(ngx.HTTP_FORBIDDEN)
    return
end

ngx.say(cjson.encode({
    message = "Joined channel ",
    channelId = payload_or_err.channelId,
    userId = payload_or_err.userId
}))