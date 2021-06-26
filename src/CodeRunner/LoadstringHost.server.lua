--[[
    -LoadstringHost.server.lua-
    Separate enviorement to run loadstring, so the env from the caller doesn't leak. It's critical we assign no variables whatsoever, or dispose of them.
    Written by Jrelvas (24/2/2021)
]]--
--#selene: allow(unused_variable)

Instance.new("BindableFunction").Parent = script
local plugin = nil --Modules don't have access to plugin; emulate this.

script:FindFirstChildOfClass("BindableFunction").OnInvoke = function(source: string)
    source = "source = nil\n"..source
    return loadstring(source)
end