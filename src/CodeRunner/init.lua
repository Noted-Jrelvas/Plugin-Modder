--[[
    -init.lua (CodeRunner)-
    Simulate module requiring if we have an elevated context, since it's impossible to require modules created at runtime
    Written by Jrelvas (24/2/2021)
]]--
local BASE_CODE = 

[[local originalRequire = require
local require = originalRequire(script.Parent).loadModule
local script = originalRequire(script.Parent).getInstance("%s")
originalRequire = nil
%s]] --Override script and require with this module

type Dictionary<T> = {[string]: T}
type Array<T> = {[number]: T}


local api = {}
local availableModules: Array<ModuleScript> = {}
local cachedModules: {[ModuleScript|string]: any} = {}
local debugIdList: Dictionary<string> = {}

local loadstringHost = script.LoadstringHost:FindFirstChildOfClass("BindableFunction")

local isElevated: boolean = false
do
    local _, err = pcall(error, "Looking at the source are we?")
    if string.match(err, "^builtin_") or string.match(err, "^sabuiltin_") then
        isElevated = true
     end
end

local function isLoadstringEnabled() --I do love myself some ugly hacks! Get if loadstring is available, since studio refuses to keep this consistent for plugins and makes them depend on game behavior!
    local failure, errorMessage = pcall(loadstring)

    if failure and string.match(errorMessage, "available") then
        return false
    end

    return true
end

function api.addModules(modules: Array<ModuleScript>)
    for _, module in ipairs(modules) do
        table.insert(availableModules, module)
    end
end

function api.getInstance(debugId: string): BaseScript
    assert(debugIdList[debugId], "Debug id not registered")
    return debugIdList[debugId]
end

function api.loadModule(module: LuaSourceContainer|number)
    if type(module) == "number" then --Requiring external modules isn't as much of a pain in an elevated context!
        if cachedModules[tostring(module)] then
            return cachedModules[tostring(module)]
        else --Use cached version, if we don't we'll receive an error when in an elevated context.
            local returnedValue = require(module)
            cachedModules[tostring(module)] = returnedValue
            return returnedValue
        end
    elseif not cachedModules[module] then
        local returnedValue
        local newSource = module.Source
        
        if module:IsA("BaseScript") then
            newSource = string.format("return function(plugin)\n%s\nend", newSource) --Wrap around scripts in a function that also receives a plugin argument, mimicking them.
        end

    local debugId = module:GetDebugId() --Unique id for each instance
    debugIdList[debugId] = module
    newSource = string.format(BASE_CODE, debugId, newSource)

        if not isElevated then --At least we can require modules created at runtime...
            local emulatorModule = Instance.new("ModuleScript")
            emulatorModule.Name = module.Name
            emulatorModule.Source = newSource
            emulatorModule.Parent = script
            returnedValue = require(emulatorModule)
        else
            game:DefineFastFlag("FFlagEnableLoadModule", true) --enable debug.loadmodule

            --selene: allow(incorrect_standard_library_use)
            if debug.loadmodule then --debug.loadmodule requires a module without caching it. Luckily for us, it's able to require at the right context level
                local emulatorModule = Instance.new("ModuleScript")
                emulatorModule.Name = module.Name
                emulatorModule.Source = newSource
                emulatorModule.Parent = script

                debug.loadmodule(emulatorModule)           
            elseif isLoadstringEnabled() then --debug.loadmodule is unavailable. At least we can rely on loadstring.
                returnedValue = loadstringHost:Invoke(newSource)()
            else --Our last option, time to bring out the hacks. Edit empty modules that are packed with the plugin itself.
                assert(#availableModules > 0, "CodeRunner has ran out of modules. You can add more using \"CodeRunner.addModules()\". Please note only modules that were packed with the plugin will work due to arbitrary Roblox restrictions.")
                if #availableModules < 6 then
                    warn("CodeRunner is almost out of modules. You can add more using \"CodeRunner.addModules()\". Please note only modules that were packed with the plugin will work due to arbitrary Roblox restrictions.")
                end
    
                local emulatorModule = availableModules[#availableModules]
                emulatorModule.Name = module.Name
                emulatorModule.Source = newSource
                emulatorModule.Parent = script
    
                table.remove(emulatorModule, #availableModules)
    
                returnedValue = require(emulatorModule)
            end
        end


        cachedModules[module] = returnedValue
        return returnedValue
    else
        return(cachedModules[module])
    end
end

function api.getRemainingModules()
    return #availableModules
end

return api