require "os"
local jwt = require "resty.jwt"
local jwt_secret = os.getenv("JWT_SECRET")
local jwt_cookie_domain = os.getenv("JWT_COOKIE_DOMAIN")
local token_duration = 900

ngx.log(ngx.INFO, "jwt_secret=" .. jwt_secret)
ngx.log(ngx.INFO, "jwt_cookie_domain=" .. jwt_cookie_domain)

local jwt_obj = jwt:verify(jwt_secret, ngx.var.arg_jwt, 0)
if not jwt_obj["verified"] then
  jwt_obj = jwt:verify(jwt_secret, ngx.var.cookie_jwt, 0)
end

if jwt_obj["verified"] then
  local exp = ngx.time() + token_duration
  local token = { payload=jwt_obj.payload, header= jwt_obj.header }
  token.payload.exp = exp
  local jwt_cookie = jwt:sign(jwt_secret,token)
  local cookie_domain = not jwt_cookie_domain and '' or '; Domain=' .. jwt_cookie_domain
  ngx.header['Set-Cookie'] = "jwt=" .. jwt_cookie .. cookie_domain .. "; Path=/; Expires=" .. ngx.cookie_time(ngx.time() + token_duration)
end
