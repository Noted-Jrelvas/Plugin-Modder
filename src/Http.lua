--[[
    -Http.lua-
    Handle HttpRequests + util function for adding arguments into urls.
    Written by Jrelvas (23/2/2021)
]]--
type Dictionary<T> = {[string]: T}

local HttpService = game:GetService("HttpService")

local function findEnumItem(enum: Enum, name: string): EnumItem
    for _, enumItem in ipairs(enum:GetEnumItems()) do
        if enumItem.Name == name then
            return enumItem
        end
    end
    return nil
end
local api = {}

function api.addParams(url: string, params: {[any]: any}): string
    url ..= "?"
    local isFirst = true

    for k, v in pairs(params) do
        local paramName = HttpService:UrlEncode(tostring(k))
        local paramValue = HttpService:UrlEncode(tostring(v))

        local paramUrl = string.format("%s=%s", paramName, paramValue)
        if not isFirst then
            paramUrl = "&" ..paramUrl
        end
        url ..= paramUrl
        isFirst = false
    end

    return url
end

function api.fetch(url: string, options: Dictionary<any>?, useInternal: boolean?)
    options = options or {}
    options.method = options.method or "GET"

    assert(type(options.method) == "string", "method must be a string")
    assert(type(options.headers) == "table" or not options.headers, "headers must be a dictionary of headers or nil")
    assert(type(options.body) == "string" or not options.body, "body must be a string or nil")

    if not useInternal then
        --if not HttpService.HttpEnabled then
        --    return {success = false, errorType = "HttpEnabled"}
        --end
        local success, returnedValue = pcall(HttpService.RequestAsync, HttpService, {
            Url = url,
            Method = options.method,
            Headers = options.headers,
            Body = options.body
        })
        if not success then
            print(returnedValue)
            if string.match(returnedValue, "Http requests are not enabled") then
                return {
                    success = false,
                    errorType = "HttpEnabled"
                }
            end
            return {
                success = false,
                errorType = "HttpError",
                httpError = findEnumItem(Enum.HttpError, string.gsub(returnedValue, "^HttpError: ", "")) or Enum.HttpError.Unknown
            }
        else
            returnedValue.success = true
            return returnedValue
        end
    else
        local co = coroutine.running()
        local data
        local request = HttpService:RequestInternal({
            Url = url,
            Method = options.method,
            Headers = options.headers,
            Body = options.body
        })

        coroutine.wrap(function()
            request:Start(function(success, result)
                print(success, result)
                result.success = success
                data = result
                coroutine.resume(co, result)
            end)
        end)()

        return data or coroutine.yield()
    end
end

return api