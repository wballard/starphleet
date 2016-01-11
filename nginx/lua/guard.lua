require "os"
require "string"
require "table"
local jwt = require "resty.jwt"
local jwt_secret = os.getenv("JWT_SECRET")
local jwt_auth_site = os.getenv("JWT_AUTH_SITE")
local jwt_roles = {}
local role_authorized = false

if not jwt_auth_site then
  ngx.log(ngx.ERR, "Error processing jwt authentication. Missing JWT_AUTH_SITE environment variable")
  return ngx.exit(500)
end

if not jwt_secret then
  ngx.log(ngx.ERR, "Error processing jwt authentication. Missing JWT_SECRET environment variable")
  return ngx.exit(500)
end

function trim (s)
  return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

for role in string.gmatch(ngx.var.jwt_roles, '([^,]+)') do
  table.insert(jwt_roles,1,role)
end

-- jwt:verify checks that the token can be decrypted,
-- is salted with the specified secret, and has not expired
local jwt_obj = jwt:verify(jwt_secret, ngx.var.arg_jwt, 0)
if not jwt_obj["verified"] then
  jwt_obj = jwt:verify(jwt_secret, ngx.var.cookie_jwt, 0)
end

if type(jwt_obj.payload) == "table" then
  -- check that there is are exp and iat properties
  -- and that iat is not more than  24 hours old
  if jwt_obj.payload.exp and jwt_obj.payload.iat and ngx.time() - jwt_obj.payload.iat <= 24*60*60 then
    -- check the roles the user has in the toke against the roles
    -- specified in the .jwt file for the orders. Empty .jwt files
    -- get rewritten to "*" in the starphleet_publish script
    for user_role in string.gmatch(jwt_obj.payload.role, '([^,]+)') do
      for _,v in pairs(jwt_roles) do
        if trim(v) == trim(user_role) or trim(v) == '*' then
          role_authorized = true
          break
        end
      end
      if authenticated then break end
    end
  end
end

if jwt_obj["verified"] and role_authorized then
  -- Loop over existing request headers and remove anything starting with 'jwt-'
  -- out of an abundance of security caution, so our jwt headers cannot be spoofed.
  for k,v in pairs(ngx.req.get_headers()) do
    if (string.sub(k,1,4) == 'jwt-') then
      ngx.req.set_header(k, nil)
    end
  end
  -- Set up our JWT properties as request headers
  for k,v in pairs(jwt_obj.payload) do
    ngx.req.set_header("jwt-" .. k, v)
  end
else
  local full_request_uri = ngx.var.scheme .. '://' .. ngx.var.host .. ngx.var.request_uri
  return ngx.redirect(jwt_auth_site .. "?target=" ..ngx.escape_uri(full_request_uri) )
end
