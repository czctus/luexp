local HttpService = game:GetService('HttpService')

local ver
local clientver = "1.0"

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

return function(deb)
	local module = {}

	local methods = {}

	local auth 
	local url 

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
		ProxyEndpoint = ProxyEndpoint:gsub("https://api.perox.dev", "http://localhost:3001")
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
				error("Endpoint is already used by another server.")
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
			local s,r = pcall(function()
				local header = {["Authorization"]=auth}
				local poll = HttpService:JSONDecode(HttpService:RequestAsync({["Url"]=url .. "/i-n-t/poll", ["Method"]="GET", ["Headers"]=header}).Body)
				for i,v in pairs(poll) do
					local headers = {["Authorization"]=auth, ["Content-Type"]="application/json", ["request-index"]=tostring(i)}

					function v.res.status(statuscode:number, message:string)
						HttpService:RequestAsync({["Url"]=url.."/i-n-t/req", ["Body"]=HttpService:JSONEncode({msg=message, status=statuscode}), ["Headers"]=headers, ["Method"]="POST"})
					end
					v.res.app = module

					v.req.app = module
					function v.req.get(header)
						for i,v in pairs(v.req.headers) do
							if string.lower(i) == header then
								return v
							end
						end
					end

					for i, method in pairs(methods) do
						local pattern = method.endpoint:gsub("%*", ".*")
						pattern = "^" .. pattern:gsub("/", "%%/") .. "$"
						local requestedUrl = string.gsub(string.split(v.req.originalUrl, "?")[1], "/s/xyz", "")
						if string.match(requestedUrl, pattern) and (v.method == method.method or method.method == "ALL") then
							method.callback(v.req, v.res)
							return
						end
					end
					HttpService:RequestAsync({["Url"]=url.."/i-n-t/req", ["Body"]=HttpService:JSONEncode({msg="Invalid Endpoint", status=404}), ["Headers"]=headers, ["Method"]="POST"})
				end
			end)
			if not s then
				print(r)
			end
		end
	end

	function module.get(endpoint:string, callback)
		methods[os.time()*math.random(100, 10000000)] = {
			method = "GET",
			callback = callback,
			endpoint = endpoint
		}
	end
	function module.post(endpoint:string, callback)
		methods[os.time()*math.random(100, 10000000)] = {
			method = "POST",
			callback = callback,
			endpoint = endpoint
		}
	end
	function module.put(endpoint:string, callback)
		if endpoint == "/" then
			error("Cannot PUT Root (used by internal)")
		else
			methods[os.time()*math.random(100, 10000000)] = {
				method = "PUT",
				callback = callback,
				endpoint = endpoint
			}
		end
	end
	function module.delete(endpoint:string, callback)
		if endpoint == "/" then
			error("Cannot DELETE Root (used by internal)")
		else
			methods[os.time()*math.random(100, 10000000)] = {
				method = "DELETE",
				callback = callback,
				endpoint = endpoint
			}
		end
	end
	function module.head(endpoint:string, callback)
		methods[os.time()*math.random(100, 10000000)] = {
			method = "HEAD",
			callback = callback,
			endpoint = endpoint
		}
	end
	function module.options(endpoint:string, callback)
		methods[os.time()*math.random(100, 10000000)] = {
			method = "OPTIONS",
			callback = callback,
			endpoint = endpoint
		}
	end
	function module.patch(endpoint:string, callback)
		methods[os.time()*math.random(100, 10000000)] = {
			method = "PATCH",
			callback = callback,
			endpoint = endpoint
		}
	end
	function module.all(endpoint:string, callback)
		if endpoint == "/" then
			error("Cannot all Root (used by internal)")
		else
			methods[os.time()*math.random(100, 10000000)] = {
				method = "ALL",
				callback = callback,
				endpoint = endpoint
			}
		end
	end
	function module.any(method, endpoint:string, callback)
		method = string.upper(method)
		if (method == "DELETE" or method == "PUT") and (endpoint == "/") then
			error("Cannot Root (used by internal)")
		else
			methods[os.time()*math.random(100, 10000000)] = {
				method = method,
				callback = callback,
				endpoint = endpoint
			}
		end
	end
	function module.close()
		closeServer()
	end
	function module.on(event)
		--[[
		events:
		error,
		called,
		closed,
		opened,
		listening
		]]
	end

	module.ver = ver

	return module
end
