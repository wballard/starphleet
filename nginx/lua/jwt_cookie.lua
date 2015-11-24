require "os"
local jwt = require "resty.jwt"
local jwt_secret = os.getenv("JWT_SECRET")
local token_duration = 60

local jwt_obj = jwt:verify(jwt_secret, ngx.var.arg_jwt, 0)
if not jwt_obj["verified"] then
  jwt_obj = jwt:verify(jwt_secret, ngx.var.cookie_jwt, 0)
end

if jwt_obj["verified"] then
  local exp = ngx.time() + token_duration
  local token = { payload=jwt_obj.payload, header= { typ="JWT", alg="HS256"} }
  token.payload.exp = exp
  local jwt_cookie = jwt:sign(jwt_secret,token)
  ngx.header['Set-Cookie'] = "jwt=" .. jwt_cookie .. "; Path=/; Expires=" .. ngx.cookie_time(ngx.time() + token_duration)
end
