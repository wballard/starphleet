require "string"
require "table"
local bit = require("bit")
local cjson = require("cjson")
local jwt = require("resty.jwt")
local jwt_secret = ngx.var.jwt_secret
local session_private_key = ngx.var.session_private_key
local session_public_key_current = ngx.var.session_public_key_current
local session_public_key_old = ngx.var.session_public_key_old
local jwt_auth_site = ngx.var.jwt_auth_site
local jwt_auth_header = ngx.var.jwt_auth_header
local jwt_access_flags = ngx.var.jwt_access_flags
local jwt_cookie_domain = ngx.var.jwt_cookie_domain
local jwt_cookie_name = ngx.var.jwt_cookie_name
local jwt_revocation_dir = ngx.var.jwt_revocation_dir
local jwt_max_token_age_in_seconds = tonumber(ngx.var.jwt_max_token_age_in_seconds)
local jwt_expiration_in_seconds = tonumber(ngx.var.jwt_expiration_in_seconds)
local user_identity_cookie = ngx.var.user_identity_cookie
local headers = ngx.req.get_headers()
local _setCookie = {}

-- *****************************************************************************
-- * Helper Methods
-- *****************************************************************************

------------------------------------------------------------------------------
-- @function _replace()
--
-- Doing a direct string replace in LUA with dynamic text requires escaping
-- all the special lua chars.  Found the solution, implemented below, here:
-- http://stackoverflow.com/a/29379912
------------------------------------------------------------------------------
local function _replace(str, what, with)
  what = string.gsub(what, "[%(%)%.%+%-%*%?%[%]%^%$%%]", "%%%1") -- escape pattern
  with = string.gsub(with, "[%%]", "%%%%") -- escape replacement
  return string.gsub(str, what, with)
end

------------------------------------------------------------------------------
-- @function _fileExists(fileName)
--
-- Check if a file exists.  We use a file system check to revoke JWT tokens
-- Using the solution found here:
--   http://stackoverflow.com/a/4991602
------------------------------------------------------------------------------
function _fileExists(fileName)
   local file = io.open(fileName,"r")
   if file ~= nil then
     io.close(file)
     return true
   else
     return false
   end
end

------------------------------------------------------------------------------
-- @function _sendUserToLogin()
--
-- Build the appropriate URL based on the calling service' "auth_site"
-- setting.  Then redirect the user to the "auth_site".  This function
-- will be called anywhere a JWT token fails to meet the criteria to
-- allow the user to proceed
------------------------------------------------------------------------------
local _sendUserToLogin = function()
  ngx.req.set_header('X-Starphleet-JWT-Secret', jwt_secret);
  ngx.req.set_header('X-Starphleet-Redirect', "true");
  ngx.req.set_header('X-Starphleet-OriginalUrl', ngx.var.request_uri);
  ngx.req.set_header('X-Starphleet-Authentic', ngx.var.authentic_token);
  return ngx.exec(jwt_auth_site .. "/")
end

------------------------------------------------------------------------------
-- @function _getAuthorizationHeader()
--
-- Return the body of the Authorization header after stripping out
-- any fragments of "Bearer".  The resulting string will either be
-- the JWT token or an empty string of Authorization wasn't passed
------------------------------------------------------------------------------
local _getAuthorizationHeader = function()
  if headers["Authorization"] then
    return headers["Authorization"]:gsub("Bearer ","")
  end

  return ""
end

------------------------------------------------------------------------------
-- @function _getUrlSession()
--
-- In an attempt to change the session name we are going to accept
-- both "jwt" and "session"
------------------------------------------------------------------------------
local _getUrlSession = function()
  if ngx.var.arg_jwt then
    return ngx.var.arg_jwt
  end
  if ngx.var.arg__session then
    return ngx.var.arg__session
  end

  return ""
end

------------------------------------------------------------------------------
-- @function _resetHeaders(token)
--
-- Pass the results of "resty:verify" to this method to reset any "jwt-*"
-- headers to match the "payload" portion of the jwt token.
--
-- The headers will be available to apps like this:
--   jwt-iat: $token.payload.iat
--   jwt-exp: $token.payload.exp
--   jwt-roles: $token.payload.roles
--   ...etc
--
-- The first iteration deletes anything starting with "jwt-".  The second
-- loop re-maps the payload to headers
--
-- This has been modified to also populate "session-" headers which will
-- eventually replace jwt-*
------------------------------------------------------------------------------
local _resetHeaders = function(token)
  for k,v in pairs(ngx.req.get_headers()) do
    if (string.sub(k,1,4) == 'jwt-') then
      ngx.req.set_header(k, nil)
    end
  end
  for k,v in pairs(token.payload) do
    ngx.req.set_header("jwt-" .. k, cjson.encode(v))
  end
  for k,v in pairs(ngx.req.get_headers()) do
    if (string.sub(k,1,8) == 'session-') then
      ngx.req.set_header(k, nil)
    end
  end
  for k,v in pairs(token.payload) do
    ngx.req.set_header("session-" .. k, cjson.encode(v))
  end

  -- If the "un" claim exists in the valid JWT token we will
  -- set the jwt_auth_header which mimics the behavior of the
  -- other authentication methods
  if token.payload.un and
     type(token.payload.un) == "string" and
     user_identity_cookie and
     user_identity_cookie ~= "" then
    -- If the un field is set we'll also set the user_identity_cookie
    -- so that traditional betas will work with JWT
    local cookieString = ""
    cookieString = cookieString .. user_identity_cookie .. "=" .. token.payload.un
    cookieString = cookieString .. (jwt_cookie_domain and '; Domain=' .. jwt_cookie_domain or '')
    cookieString = cookieString .. '; Path=/'
    table.insert(_setCookie, cookieString)
    ngx.req.set_header(jwt_auth_header, token.payload.un)
  end
end

------------------------------------------------------------------------------
-- @function _isJwtTokenIdentityChanging(token)
--
-- Pass two payloads that result from a "resty:verify" to this method
-- to determine if their jid has changed.  If the jid has changed
-- we will return true
--
-- We check that two tokens passed are:
--   * Valid
--   * Both contain jid
--   * Jid has changed
--
------------------------------------------------------------------------------
local _isJwtTokenIdentityChanging = function(jwt_token_one, jwt_token_two)
  if jwt_token_one["valid"] and
    jwt_token_two["valid"] and
    jwt_token_one.payload.jid and
    jwt_token_two.payload.jid and
    jwt_token_one.payload.jid ~= jwt_token_two.payload.jid then
    --
    return true
  end
  --
  return false
end

------------------------------------------------------------------------------
-- @function _dump(table)
--
-- Convert a table to a string to help with debug logs
------------------------------------------------------------------------------
function _dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. _dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

------------------------------------------------------------------------------
-- @function _legacy()
--
-- Used to signal an old session is being used to help identify old usages
-- of keys we are deprecating
------------------------------------------------------------------------------
function _legacy()
  legacy = true
  ngx.log(ngx.ERR, "Old Session Token at URL: " .. ngx.var.request_uri)
end

------------------------------------------------------------------------------
-- @function _isValidToken(token)
--
-- Pass the results of "resty:verify" to this method to determine if result
-- meets the criteria to proceed with the request.
--
-- To Be Valid:
--   * Must verify and decode (handled by resty)
--   * Must include a payload
--   * Must include the reserved 'iat'/'exp' session claims
--   * iat and exp fields must be valid numbers
--   * Token is not older than the max age configured
--   * Must not be expired
------------------------------------------------------------------------------
local _isValidToken = function(token)
  if token["verified"] and
    type(token["payload"]) == "table" and
    token.payload.iat and
    token.payload.exp and
    type(token.payload.iat) == "number" and
    type(token.payload.exp) == "number" and
    ngx.time() - token.payload.iat <= jwt_max_token_age_in_seconds then
    --
    -- To support revocations - we will now check if a jid exists - and,
    -- if it exists then we will revoke the token if a file exists in
    -- the revocation dir with the jid as the name of the file.  This should
    -- later be amended to enforce jid's
    if token.payload.jid and
    _fileExists(jwt_revocation_dir .. "/" .. token.payload.jid) then
      return false
    end
    --
    return true
  end
  --
  return false
end

-- *****************************************************************************
-- * Main
-- *****************************************************************************

------------------------------------------------------------------------------
-- Decode each of the token types.  We handle things slightly different
-- based on how the caller sent us the Session token.  From a high level:
--    * Passing JWT via URL will get you in the door and starphleet
--      will set a cookie using the payload from your token.  The first
--      action will be a 302 redirect back to the same URL stripped
--      of the session token from the url.
--    * You can pass a token via the Authorization: Bearer header and
--      starphleet will treat your request as an API call
--    * You can set your own cookie using the JWT_COOKIE_NAME
--      and JWT_COOKIE_DOMAIN params appropriately.  It is recommended
--      to pass the token via the URL.
------------------------------------------------------------------------------
local authorizationBearerString = _getAuthorizationHeader()
local urlSession = _getUrlSession()
local verified_url_token = jwt:verify(session_public_key_current, urlSession)
local verified_cookie_token = jwt:verify(session_public_key_current, ngx.var["cookie_" .. jwt_cookie_name])
local verified_bearer_token = jwt:verify(session_public_key_current, authorizationBearerString)

------------------------------------------------------------------------------
-- Below we follow the rules described above.  We respect a url param
-- "disablesessionredirect", which, when present - we will NOT redirect
-- and strip the JWT token from the URL.
------------------------------------------------------------------------------
local token = nil
local redirect = nil
if _isValidToken(verified_bearer_token) then
  token = verified_bearer_token
elseif _isValidToken(verified_url_token) then
  token = verified_url_token
  if not string.find(ngx.var.request_uri, "disablejwtredirect=") and
     not string.find(ngx.var.request_uri, "disablesessionredirect=") then
    --
    redirect = ngx.var.request_uri
    redirect = redirect:gsub([[jwt=[^&]*&?]],"")
    redirect = redirect:gsub([[_session=[^&]*&?]],"")
    redirect = redirect:gsub([[%?$]],"")
    redirect = redirect:gsub([[&$]],"")
  end
elseif _isValidToken(verified_cookie_token) then
  if not _isJwtTokenIdentityChanging(verified_url_token, verified_cookie_token) then
    token = verified_cookie_token
  end
end

for _, secret in pairs({jwt_secret, session_public_key_old}) do
  if not token then
    ------------------------------------------------------------------------------
    -- If below looks like a duplicate; it is.  Only, we are going to test
    -- a second secret.  This allows us to key rotate and we will log
    -- when the old key is being used.
    ------------------------------------------------------------------------------
    verified_url_token = jwt:verify(secret, urlSession)
    verified_cookie_token = jwt:verify(secret, ngx.var["cookie_" .. jwt_cookie_name])
    verified_bearer_token = jwt:verify(secret, authorizationBearerString)

    if _isValidToken(verified_bearer_token) then
      token = verified_bearer_token
      _legacy()
    elseif _isValidToken(verified_url_token) then
      token = verified_url_token
      _legacy()
      if not string.find(ngx.var.request_uri, "disablejwtredirect=") and
         not string.find(ngx.var.request_uri, "disablesessionredirect=") then
        --
        redirect = ngx.var.request_uri
        redirect = redirect:gsub([[jwt=[^&]*&?]],"")
        redirect = redirect:gsub([[_session=[^&]*&?]],"")
        redirect = redirect:gsub([[%?$]],"")
        redirect = redirect:gsub([[&$]],"")
      end
    elseif _isValidToken(verified_cookie_token) then
      if not _isJwtTokenIdentityChanging(verified_url_token, verified_cookie_token) then
        token = verified_cookie_token
      end
    end
  end
end

------------------------------------------------------------------------------
-- @function _accessDenied()
--
-- This is called whenever a user's session is determined to not be valid.
-- It gives us a chance to log, setup a valid header, and nil out the token
-- of the user which will later force the user to get prompted for auth
------------------------------------------------------------------------------
function _accessDenied()
  ngx.log(ngx.ERR, "Access Denied By Access Flags")

  local _accessDeniedFlags = jwt_access_flags
  if token and token.payload and token.payload.af then
    _accessDeniedFlags = _accessDeniedFlags..','..token.payload.af
  end
  ngx.req.set_header('X-Starphleet-Access-Denied', _accessDeniedFlags)
  token = nil
end

------------------------------------------------------------------------------
-- @function _allowUserToProceed(token)
--
-- @return Boolean
--
-- We determine if someone should be allowed access to the resource requested.
-- For legacy reasons, the jwt_access_flags may come in two forms:
--
--   standard int (4)
--   role-$group:$mask
--
-- The latter form is introduced to allow an infinite number of flags and
-- categories. Someone is permitted access if they have a claim in the
-- session token that aligns with access flag setting for the service
------------------------------------------------------------------------------
function _allowUserToProceed(token)
  if not jwt_access_flags then
    jwt_access_flags = ""
  end
  -- This is lua for 'split on space'
  for role_or_flag in jwt_access_flags:gmatch("%S+") do
    -- No point in moving forward if the token doesn't have a payload
    if token and token.payload then
      -- If the access flag (role_or_flag) in the environment or orders file
      -- is only an integer then we have the old style. A number means
      -- we only have a bitmask.  All we will do is compare this to the
      -- af claim in the session
      if type(tonumber(role_or_flag)) == 'number' and token.payload.af then
        return bit.band(token.payload.af, role_or_flag) > 0
      -- ..but if the access flags are set to the other form:
      -- example |  role-marketing:3 role-othergroup:1
      -- Then we will loop through all those groups and check
      -- the session claims for a match and then check the flags
      -- for that match.  Any access allows the user through
      else
        for role, flag in role_or_flag:gmatch("(%S-):(%d*)") do
          if token.payload[role] then
            if bit.band(token.payload[role], flag) > 0 then
              return true
            end
          end
        end
      end -- end of else
    end
  end -- end of outer for loop

  -- If we fall through we'll return an explicit false
  -- because lua can be snarky sometimes
  return false
end

if not _allowUserToProceed(token) then
  _accessDenied()
end

------------------------------------------------------------------------------
-- If the above process results in a valid token then we set the cookie
-- with the appropriate JWT payload
------------------------------------------------------------------------------
if (token) then
  if jwt_private_key and jwt_private_key ~= ""
  or jwt_secret and jwt_secret ~= ""
  then
    ------------------------------------------------------------------------------
    -- Refresh the expire time
    ------------------------------------------------------------------------------
    token.payload.exp = ngx.time() + jwt_expiration_in_seconds

    ------------------------------------------------------------------------------
    -- Below we write the HS256 enabled cookie if we have enough information
    ------------------------------------------------------------------------------
    if jwt_secret ~= "" then
      -- Adding static entries to cookie name during transition to new sign type
      -- because we will support writing two cookies for the transition period
      local cookie_name = "jwt"
      ------------------------------------------------------------------------------
      -- Create a new jwt token
      ------------------------------------------------------------------------------
      token.header.alg = "HS256"
      local signedJwtToken = jwt:sign(jwt_secret, { payload=token.payload, header=token.header } )

      ------------------------------------------------------------------------------
      -- LUA does not support string appends OR ternary operations
      -- Even still, for now, I'm keeping the format for easy
      -- manipulations.  Dynamically build a cookie string to assign
      -- the JWT session token to the request
      ------------------------------------------------------------------------------
      local cookieString = ""
      cookieString = cookieString .. (signedJwtToken and cookie_name .. "=" .. signedJwtToken or '')
      cookieString = cookieString .. (jwt_cookie_domain and '; Domain=' .. jwt_cookie_domain or '')
      cookieString = cookieString .. '; Path=/'
      cookieString = cookieString .. (jwt_expiration_in_seconds and '; Expires=' .. ngx.cookie_time(token.payload.exp) or '')
      table.insert(_setCookie, cookieString)
    end

    ------------------------------------------------------------------------------
    -- Below we write the RS256 enabled cookie if we have enough information
    ------------------------------------------------------------------------------
    if jwt_private_key ~= "" then
      -- Adding static entries to cookie name during transition to new sign type
      -- because we will support writing two cookies for the transition period
      local cookie_name = "_session"
      ------------------------------------------------------------------------------
      -- Create a new jwt token
      ------------------------------------------------------------------------------
      token.header.alg = "RS256"
      local signedJwtToken = jwt:sign(jwt_private_key, { payload=token.payload, header=token.header } )

      ------------------------------------------------------------------------------
      -- LUA does not support string appends OR ternary operations
      -- Even still, for now, I'm keeping the format for easy
      -- manipulations.  Dynamically build a cookie string to assign
      -- the JWT session token to the request
      ------------------------------------------------------------------------------
      local cookieString = ""
      cookieString = cookieString .. (signedJwtToken and cookie_name .. "=" .. signedJwtToken or '')
      cookieString = cookieString .. (jwt_cookie_domain and '; Domain=' .. jwt_cookie_domain or '')
      cookieString = cookieString .. '; Path=/'
      cookieString = cookieString .. (jwt_expiration_in_seconds and '; Expires=' .. ngx.cookie_time(token.payload.exp) or '')
      table.insert(_setCookie, cookieString)
    end

    if token and token.payload and token.payload.un and token.payload.un ~= "" then
      local userCookieString = ""
      userCookieString = userCookieString .. (token.payload.un and 'starphleet_user' .. "=" .. token.payload.un or '')
      userCookieString = userCookieString .. (jwt_cookie_domain and '; Domain=' .. jwt_cookie_domain or '')
      userCookieString = userCookieString .. '; Path=/'
      userCookieString = userCookieString .. (jwt_expiration_in_seconds and '; Expires=' .. ngx.cookie_time(token.payload.exp) or '')
      table.insert(_setCookie, userCookieString)
    end

    ngx.header['Set-Cookie'] = _setCookie

    if redirect then
      return ngx.redirect(redirect)
    end
  end

  -- ** Reset any headers starting with jwt- (or session-) with fields in our payload ** --
  return _resetHeaders(token)
end

------------------------------------------------------------------------------
-- We get to here if none of the tokens succeeded in being valid.
-- Before we redirect the user to the login page we check to see
-- if the request was made using the Authorization header.  If it was
-- made using the Auth header, this was an API call and we set status
-- to 401 letting the API call know it needs to re-authenticate.
------------------------------------------------------------------------------
if authorizationBearerString ~= "" then
  return ngx.exit(401)
end

------------------------------------------------------------------------------
-- If we get here, no condition existed to verify a JWT token sent to us
-- and thus, no matter what, we redirect the user to the login page
------------------------------------------------------------------------------
_sendUserToLogin()
