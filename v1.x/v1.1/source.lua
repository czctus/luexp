--[[

This project is licensed under MIT License <https://mit-license.org/>

Written by @czctus on github <https://github.com/czctus>
You can also get the api reference at our discord  <https://discord.gg/tq9vQfH9Au>

You may redistribute,  modify, and use the source code for any purpose,
but you must include the copyright notice and this entire permission notice
in all copies of the source code.

Abusing Luexp's services is strictly not permitted.  Doing so may result in a
temporary ban from our services.

Luexp is provided free. You can get a copy at our Github <https://github.com/czctus/Luexp>

]]

local HttpService = game:GetService('HttpService')

local ver
local clientver = "1.1"

local statusCodes = HttpService:JSONDecode(HttpService:GetAsync("https://status.js.org/codes.json"))

local s, r = pcall(function()
	ver = HttpService:GetAsync("https://api.perox.dev/s/ver")
end)

if not s then
	print(r)
	ver = `luexp-client {clientver}; luexp-server luexp/?; (express@?; Node ?; ?)`
else
	ver = `luexp-client {clientver}; ` .. ver
	if tostring(string.sub(ver, 38, 40)) ~= clientver then
		warn("Miss-Matched Version!\nusing: luexp@" .. string.sub(ver, 37, 40))
	end 
end

local ProxyEndpoint = "https://api.perox.dev/proxy"
local init = "https://api.perox.dev/s/"
local DefaultHeaders = {
	["X-Powered-By"] = "luexp/1.0",
	["C-User-Agent"] = "luexp/1.0"
}

local app = function(deb)
	local module = {}

	local methods = {}

	local auth 
	local url 

	for i,v in pairs(script.Packages:GetChildren()) do
		module[v.Name] = require(v)
	end

	local function closeServer(index)
		index = index or 1
		if url and auth and index ~= 6 then
			local delres = HttpService:RequestAsync({["Url"]=url, ["Method"]="DELETE", ["Headers"]={["Authorization"]=auth}})

			url, auth = nil, nil

			if not delres.Success then
				warn("Failed to delete endpoint!")
				closeServer(index + 1)
			end
		elseif index == 6 then
			error("Failed to close server after 5 attempts.")
		end
	end

	if deb then
		warn("debug mode is active\ni do not recommend enabling this.")
		init = init:gsub("https://api.perox.dev", "http://localhost:3001")
	end

	function module.listen(endpoint:string, callback)
		local req = {
			["Url"]=ProxyEndpoint.."?url="..init..endpoint.."&method=PUT",
			["Method"]="POST",
			["Headers"] = DefaultHeaders
		}
		local res = HttpService:RequestAsync(req)
		if not res.Success then
			if res.StatusCode == 409 then
				error(`Endpoint is already used by another server.\nYou can resolve this by contacting czctus on Discord and asking for {endpoint} to be removed.`)
			else
				error("Failed to start server, " .. res.StatusCode .. "\n" .. res.StatusMessage)
				return
			end
		else
			url = HttpService:JSONDecode(res.Body).url
			auth = HttpService:JSONDecode(res.Body).auth
			if deb then
				url = url:gsub("https://api.perox.dev", "http://localhost:3001")
			end
			if callback then
				callback(url, auth)
			end
		end
		game:BindToClose(closeServer) --cleanup for memory leaks
		while (url and auth) do
			task.wait(0.25)
			local c;
			local s,r = pcall(function()
				local header = {["Authorization"]=auth}
				local poll = HttpService:JSONDecode(HttpService:RequestAsync({["Url"]=url .. "/i-n-t/poll", ["Method"]="GET", ["Headers"]=header}).Body)
				for i,v in pairs(poll) do
					c = i
					local headers = {["Authorization"]=auth, ["Content-Type"]="application/json", ["request-index"]=tostring(i)}
					local chain = {
						statusCode = "200"
					}
					function v.res.status(statuscode:number)
						chain.statusCode = tostring(statuscode)
						return chain
					end
					function v.res.send(message:string)
						if statusCodes[chain.statusCode] then
							HttpService:RequestAsync({["Url"]=url.."/i-n-t/req", ["Body"]=HttpService:JSONEncode({msg=message, status=chain.statusCode}), ["Headers"]=headers, ["Method"]="POST"})
						else
							HttpService:RequestAsync({["Url"]=url.."/i-n-t/req", ["Body"]=HttpService:JSONEncode({msg="Server Attempted to send a invalid HTTP Code [" .. chain.statusCode .. "]", status=500}), ["Headers"]=headers, ["Method"]="POST"})
						end
						return chain
					end
					function v.res.sendStatus(statuscode:number)
						chain.statusCode = tostring(statuscode)
						if statusCodes[chain.statusCode] then
							HttpService:RequestAsync({["Url"]=url.."/i-n-t/req", ["Body"]=HttpService:JSONEncode({msg=statusCodes[chain.statusCode].message, status=chain.statusCode}), ["Headers"]=headers, ["Method"]="POST"})
						else
							HttpService:RequestAsync({["Url"]=url.."/i-n-t/req", ["Body"]=HttpService:JSONEncode({msg="Server Attempted to send a invalid HTTP Code [" .. chain.statusCode .. "]", status=500}), ["Headers"]=headers, ["Method"]="POST"})
						end
						return chain
					end
					chain.status = v.res.status
					chain.send = v.res.send
					v.res.app = module

					v.req.app = module
					v.req.url = string.gsub(string.split(v.req.originalUrl, "?")[1], "/s/" .. endpoint, "")
					function v.req.get(header)
						for i,v in pairs(v.req.headers) do
							if string.lower(i) == header then
								return v
							end
						end
					end
					
					local shouldnt404 = false

					for i, method in pairs(methods) do
						shouldnt404 = false
						if method.use and method.use == true then
							local calledNext = false
							local function next(req, res)
								calledNext = true
								if req then
									v.req = req
								end
								if res then
									v.res = res
								end
							end
							method.callback(v.req, v.res, next)
							if not calledNext then
								shouldnt404 = true
								break
							end
						else
							local pattern = method.endpoint:gsub("%*", ".*")
							pattern = "^" .. pattern:gsub("/", "%%/") .. "$"
							local requestedUrl = string.gsub(string.split(v.req.originalUrl, "?")[1], "/s/" .. endpoint, "")
							if string.match(requestedUrl, pattern) and (v.method == method.method or method.method == "ALL") then
								method.callback(v.req, v.res)
								return
							end
						end
					end
					if not shouldnt404 then
						HttpService:RequestAsync({["Url"]=url.."/i-n-t/req", ["Body"]=HttpService:JSONEncode({msg=`Cannot {v.req.method} {string.gsub(string.split(v.req.originalUrl, "?")[1], "/s/" .. endpoint, "")}`, status=404}), ["Headers"]=headers, ["Method"]="POST"})
					end
				end
			end)
			if not s then
				if (url and auth) then
					local headers = {["Authorization"]=auth, ["Content-Type"]="application/json", ["request-index"]=tostring(c)}
					HttpService:RequestAsync({["Url"]=url.."/i-n-t/req", ["Body"]=HttpService:JSONEncode({msg="[luexp err]", status=500}), ["Headers"]=headers, ["Method"]="POST"})
					warn(`[luexp err] {debug.traceback(r)} {r}`)
				end
			end
		end
	end

	function module.get(endpoint:string, callback)
		table.insert(methods, {
			method = "GET",
			callback = callback,
			endpoint = endpoint
		})
	end
	function module.post(endpoint:string, callback)
		table.insert(methods, {
			method = "POST",
			callback = callback,
			endpoint = endpoint
		})
	end
	function module.put(endpoint:string, callback)
		table.insert(methods, {
			method = "PUT",
			callback = callback,
			endpoint = endpoint
		})
	end
	function module.delete(endpoint:string, callback)
		table.insert(methods, {
			method = "DELETE",
			callback = callback,
			endpoint = endpoint
		})
	end
	function module.head(endpoint:string, callback)
		table.insert(methods, {
			method = "HEAD",
			callback = callback,
			endpoint = endpoint
		})
	end
	function module.options(endpoint:string, callback)
		table.insert(methods, {
			method = "OPTIONS",
			callback = callback,
			endpoint = endpoint
		})
	end
	function module.patch(endpoint:string, callback)
		table.insert(methods, {
			method = "PATCH",
			callback = callback,
			endpoint = endpoint
		})
	end
	function module.all(endpoint:string, callback)
		table.insert(methods, {
			method = "ALL",
			callback = callback,
			endpoint = endpoint
		})
	end
	function module.any(method, endpoint:string, callback)
		method = string.upper(method)
		table.insert(methods, {
			method = method,
			callback = callback,
			endpoint = endpoint
		})
	end
	function module.use(callback)
		table.insert(methods, {
			use = true,
			callback = callback,
		})
	end
	function module.close()
		closeServer()
	end

	module.ver = ver

	return module
end

local module = {}

function module.json(req, res, next)
	if req.headers["content-type"] == "application/json" then
		if typeof(req.body) == "table" then
			if req.body["type"] and req.body["type"] == "raw" then
				req.body = require(script.Packages.raw2str)(req.body)
			end
		end
		if typeof(req.body) == "string" then
			local data = HttpService:JSONDecode(req.body)
			req.body = data
		end
	end
	next(req, res)
end

function module.raw(req, res, next)
	local text = req.body
	local buffer = {["type"]="raw", data={}}

	for i = 1, #text do
		local char = text:sub(i, i)
		local ascii = string.byte(char)
		table.insert(buffer.data, ascii)
	end

	req.body = buffer

	next(req)
end

setmetatable(module, {
	__call = function(base, ...)
		return app(...)
	end
})

return module
