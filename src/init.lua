--[[
    -init.lua-
    The root of the plugin, handles the front-end API.
    Written by Jrelvas (23/2/2021)
]]--
type Dictionary<T> = {[string]: T}
type Array<T> = {[number]: T}
local OWNERSHIP_ENDPOINT = "https://api.%s/ownership/hasasset"

local StudioService = game:GetService("StudioService")
local HttpService = game:GetService("HttpService")
local Http = require(script.Http)
local CodeRunner = require(script.CodeRunner)

local isElevated: boolean = false
local cachedPlugins: Dictionary<Instance> = {}
do
    local _, err = pcall(error, "Looking at the source are we?")
    if string.match(err, "^builtin_") or string.match(err, "^sabuiltin_") then
        isElevated = true
     end
end

--Public API
local api = {}

api.settings = {
    proxy = "rprxy.xyz",
    pluginRef = nil
}

function api.loadPlugin(pluginId: number|string, injectSource: (LuaSourceContainer, string) -> string|nil?)
    pluginId = tostring(pluginId)
    local plugin = api.settings.pluginRef
    local domain = isElevated and "roblox.com" or api.settings.proxy

    assert(typeof(plugin) == "Instance" and plugin:IsA("Plugin"), "settings.pluginRef must be a reference to a plugin, this is required so emulated scripts get access to the plugin context")
    assert(type(domain) == "string", "Domain must be a string")

    local pluginInstance

    if not cachedPlugins[pluginId] then
        local result = Http.fetch(Http.addParams(string.format(OWNERSHIP_ENDPOINT, domain), {userId = StudioService:GetUserId(), assetId = pluginId}), {}, isElevated)

        if result.success and result.StatusCode ~= 200 then
            return {success = false, reason = "ServerError", result.StatusCode}
        elseif not result.success then
            if result.errorType == "HttpEnabled" then
                return {success = false, reason = "HttpEnabledIsFalse"}
            elseif result.errorType == "HttpError" then
                return {success = false, reason = "HttpError", result.httpError}
            end
            return {success = false, reason = "UnknownHttpError"}
        end

        local ownsPlugin: boolean = HttpService:JSONDecode(result.Body)

        if not ownsPlugin then
            return {success = false, reason = "PluginNotOwned"}
        end

        pluginInstance = game:GetObjects(string.format("rbxassetid://%s", pluginId))[1]
        cachedPlugins[pluginId] = pluginInstance:Clone()
    else
        pluginInstance = cachedPlugins[pluginId]:Clone()
    end
    local scriptsToExecute: Array<LuaSourceContainer> = {} --Make sure scripts only run when everything is handled!

    for _, instance in ipairs(pluginInstance:GetDescendants()) do
        if instance:IsA("LuaSourceContainer") then
            local newSource: string = instance.Source
            if injectSource then
                newSource = injectSource(instance)
            end

            if newSource then
                instance.Source = newSource
            end

            if instance:IsA("BaseScript") then
                instance.Disabled = true
                table.insert(scriptsToExecute, instance)
            end
        end
    end

    for _, executableScript in ipairs(scriptsToExecute) do
        CodeRunner.loadModule(executableScript)(plugin) --Execute every script
    end

    return {success = true}
end

function api.addModules(modules: Array<ModuleScript>)
    CodeRunner.addModules(modules)
end
return api