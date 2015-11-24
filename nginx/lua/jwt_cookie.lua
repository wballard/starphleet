require "os"
local jwt = require "resty.jwt"
local jwt_secret = os.getenv("JWT_SECRET")
local jwt_token = ngx.var.arg_jwt or ngx.var.cookie_jwt
local token_duration = 60

local jwt_obj = jwt:verify(jwt_secret, jwt_token, 0)
if jwt_obj["verified"] then
  local exp = ngx.time() + token_duration
  local token = { payload=jwt_obj.payload, header= { typ="JWT", alg="HS256"} }
  token.payload.exp = exp
  local jwt_cookie = jwt:sign(jwt_secret,token)
  ngx.header['Set-Cookie'] = "jwt=" .. jwt_cookie .. "; Path=/; Expires=" .. ngx.cookie_time(exp)
end
