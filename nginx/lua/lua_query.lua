local response = require "response"

local _M = {}

-- users 조회
function _M.get_user_by_id(db, user_id)
    local sql = string.format("SELECT * FROM users WHERE id = %d", user_id)
    local res = db:query(sql)
    if not res or #res == 0 then
        return response.forbidden("Not found user")
    end
    return res and res[1]
end

-- main_profiles 조회
function _M.get_main_profile(db, user_id)
    local sql = string.format("SELECT * FROM main_profiles WHERE user_id = %d", user_id)
    local res = db:query(sql)
    if not res or #res == 0 then
        return response.not_found("Not found main_profile") 
    end
    return res and res[1]
end

-- channels 조회
function _M.get_channel_by_id(db, channel_id)
    local sql = string.format("SELECT * FROM channels WHERE id = %d", channel_id)
    local res = db:query(sql)
    if not res or #res == 0 then
        return resposne.not_found("Not found channel_id") 
    end
    return res and res[1]
end

-- pApps 조회
function _M.get_installed_papps(db, channel_id)
    local sql = string.format("SELECT * FROM p_apps WHERE channel_id = %d", channel_id)
    local res = db:query(sql)
    if not res then 
        return response.not_found("Not found installedPApps")  
    end

    local installed = {}
    for _, app in ipairs(res) do
        installed[app.p_app_code] = {
            grantedAbilities = { app.granted_abilities },
            id = app.id
        }
    end
    return installed
end

-- user_channels 조회
function _M.get_user_channel(db, user_id, channel_id)
    local sql = string.format("SELECT * FROM user_channels WHERE user_id = %s AND channel_id = %s", 
    ngx.quote_sql_str(user_id), ngx.quote_sql_str(channel_id))
    local res = db:query(sql)
    if not res or #res == 0 then 
        return response.forbidden("User does not belong to this channel")
    end
    return res and res[1]
end

-- channel_memberships 조회
function _M.get_channel_membership(db, channel_id)
    local sql = string.format("SELECT id, channel_id, profile_id FROM channel_memberships WHERE channel_id = %s", channel_id)
    local res = db:query(sql)
    if not res or #res == 0 then
        return response.not_found("Not found channel_id") 
    end
    return res and res[1]
end

-- profiles 조회
function _M.get_profile_by_id(db, profile_id)
    local sql = string.format("SELECT * FROM profiles WHERE id = %s", profile_id)
    local res = db:query(sql)
    if not res then
        return response.not_found("Not found profile_id") 
    end

    local profile = res
    return {
        id = profile.id,
        nickname = profile.nickname,
        age = profile.age,
        birthYear = profile.birth_year,
        certifiedAge = profile.certified_age,
        gender = profile.gender,
        imageSrc = profile.image_src,
        isFeatured = profile.is_featured,
        distinctId = profile.distinct_id
    }
end

return _M
