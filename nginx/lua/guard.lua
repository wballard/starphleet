require "os"
require "string"
require "table"
local jwt = require "resty.jwt"
local jwt_token = ngx.var.arg_jwt or ngx.var.cookie_jwt
local jwt_secret = os.getenv("JWT_SECRET")
local jwt_auth_site = os.getenv("JWT_AUTH_SITE")
local jwt_roles = {}
local role_authorized = false

--TODO: we need to return a 500 with a message useful for developers
if not jwt_auth_site then
  jwt_auth_site = "/"
end

for role in string.gmatch(ngx.var.jwt_roles, '([^,]+)') do
  table.insert(jwt_roles,1,role)
end

local jwt_obj = jwt:verify(jwt_secret, jwt_token, 0)

if type(jwt_obj.payload) == "table" then
  -- TODO: need to trim strings
  -- TODO: changed "role" to "roles", after we've updated the token creator
  for user_role in string.gmatch(jwt_obj.payload.role, '([^,]+)') do
    for _,v in pairs(jwt_roles) do
      if v == user_role or v == '*' then
        role_authorized = true
        break
      end
    end
    if authenticated then break end
  end
end

if not jwt_obj["verified"] or not role_authorized then
  local full_request_uri = ngx.var.scheme .. '://' .. ngx.var.host .. ngx.var.request_uri
  return ngx.redirect(jwt_auth_site .. "?target=" ..ngx.escape_uri(full_request_uri) )
else
  for k,v in pairs(jwt_obj.payload) do
    ngx.req.set_header("jwt-" .. k, v)
  end
end
