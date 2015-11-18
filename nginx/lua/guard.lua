require "os"
local jwt = require "resty.jwt"
local jwt_token = ngx.var.arg_jwt
local jwt_secret = os.getenv("JWT_SECRET")
local jwt_auth_site = os.getenv("JWT_AUTH_SITE")
if not jwt_auth_site then
    jwt_auth_site = "/"
end
if jwt_token then
    ngx.header['Set-Cookie'] = "jwt=" .. jwt_token
else
    jwt_token = ngx.var.cookie_jwt
end

local jwt_obj = jwt:verify(jwt_secret, jwt_token, 0)

if not jwt_obj["verified"] then
    local full_request_uri = ngx.var.scheme .. '://' .. ngx.var.host .. ngx.var.request_uri
    return ngx.redirect(jwt_auth_site .. "?target=" ..ngx.escape_uri(full_request_uri) )
end
