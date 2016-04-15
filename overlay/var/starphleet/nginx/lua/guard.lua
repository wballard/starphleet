require "string"
require "table"
local jwt = require "resty.jwt"
local jwt_secret = ngx.var.jwt_secret
local jwt_auth_site = ngx.var.jwt_auth_site
local jwt_expiration = tonumber(ngx.var.jwt_expiration)
local jwt_roles = {}
local role_authorized = false
local leeway = 900
local session = false

if not jwt_secret or jwt_secret == "" then
  ngx.log(ngx.ERR, "Error processing jwt authentication. Missing JWT_SECRET configuration value")
  return ngx.exit(500)
end

function trim (s)
  return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

-- create a table containing the roles as specified in our configuration, this 
-- will be used to validate the request contains one of the allowed roles
for role in string.gmatch(ngx.var.jwt_roles, '([^,]+)') do
  table.insert(jwt_roles,1,role)
end

-- jwt:verify checks that the token can be decrypted,
-- is salted with the specified secret, and has not expired all
-- of this can be further delved into in the lua resty.jwt module

-- first, we see if the query string has a valid token
local jwt_obj = jwt:verify(jwt_secret, ngx.var.arg_jwt, 0)
-- if the query string did NOT contain a valid token then we
-- will check for a cookie named 'jwt'
if not jwt_obj["verified"] then
  -- we add leeway to allow us to reissue a token for one that has just expired
  jwt_obj = jwt:verify(jwt_secret, ngx.var.cookie_jwt, leeway)
  -- if we got jwt from a cookie, we're already in a session
  -- by session here we simply indicate that we did NOT have a VALID token in the
  -- querystring
  session = true
end

if jwt_obj["verified"] and type(jwt_obj.payload) == "table" then
  -- ultimately this is all about validating roles, and for a token to be truly valid it must
  -- have an expiration and an 'iat' ( issued at ) value.  Expiration checking is done elsewhere in the
  -- calls to 'jwt:verify' so we know that's good. We make sure that the token itself has not exceeded
  -- the expiration time since it's creation as well, keeping old tokens from working idefinitely.
  if jwt_obj.payload.exp and jwt_obj.payload.iat and ngx.time() - jwt_obj.payload.iat <= jwt_expiration then
    -- check the roles the user has in the token against the roles
    -- specified in the service configuration.
    -- The role of the request need only match one of the allowed roles, so 
    -- we stop looking at the first match
    for user_role in string.gmatch(jwt_obj.payload.role, '([^,]+)') do
      for _,v in pairs(jwt_roles) do
        if trim(v) == trim(user_role) or trim(v) == '*' then
          role_authorized = true
          break
        end
      end
      if role_authorized then break end
    end
  end
end

-- so, finally the check to see if we are really allowed in here.  If we are 
-- determined to not be allowed we'll redirect out to the login. In this case
-- 'allowed' means we have a valid JWT AND a request role that is allowed 
-- to access the service
if jwt_obj["verified"] and role_authorized then
  -- Loop over existing request headers and remove anything starting with 'jwt-'
  -- out of an abundance of security caution, so our jwt headers cannot be spoofed.
  for k,v in pairs(ngx.req.get_headers()) do
    if (string.sub(k,1,4) == 'jwt-') then
      ngx.req.set_header(k, nil)
    end
  end
  -- Set up our JWT properties as request headers so that the service can have access
  -- to the JWT data without having to again decode things
  for k,v in pairs(jwt_obj.payload) do
    ngx.req.set_header("jwt-" .. k, v)
  end
  -- add some of this information to the ngx.ctx object so it can be accessed during later
  -- request lifecycle events
  local ctx = ngx.ctx
  ctx.jwt_obj = jwt_obj
  ctx.leeway = leeway
  -- again, this ultimatey is set IF the token DIDN'T come from the querystring
  if session then ctx.session = 'true' end
  ngx.ctx = ctx
else
  if jwt_auth_site == "RETURN_401" then
    ngx.exit(401)
  else
    -- we got here because the token was deemed invalid, bounc 'em to the auth site
    local full_request_uri = ngx.var.scheme .. '://' .. ngx.var.host .. ngx.var.request_uri
    return ngx.redirect(jwt_auth_site .. "?target=" ..ngx.escape_uri(full_request_uri) )
  end
end
