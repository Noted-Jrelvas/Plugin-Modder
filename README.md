# PluginModder
This was a project I was working on back when using custom builtins in Roblox Studio was possible, but has since been abandoned due to their removal. 
### NOTE: This is most likely broken and won\'t work anymore, but it\'s still a great way to study some of the internal API used by Roblox builtins and its limitations.
## Overview
PluginModder is a module with a (somewhat) simple API that can fetch any plugin you own from Roblox then elevate it to a Built-in Plugin and even allow the code to be modified programmatically! Note that this isn\'t a **plugin**, it\'s a module that massively simplifies elevating **existing plugins**.

## Use cases
With the removal of custom builtins, the main point of this module, running a plugin as an elevated plugin and still receiving updates for it, was lost. Even though the name of this module is "PluginModder", the ability to modify the code of a plugin is more of a fun bonus than a real feature, a plugin could easily be broken by an update that changes what you\'re modifying.

If custom builtins were still a thing, these would be the usecases for this module:
- Allow plugins that interact with instances  get more control over instances that are protect by Roblox.
- Get access to RobloxSecurity members in command bars or code running plugins like InCommand.
- Run plugins early before the DataModel even starts to load (useful for plugins that rely on things being created).

## How to use
**NOTE: Since the only known method of creating a custom builtin was removed, these instructions are obsolete, following them using a normal plugin will result in no code elevation.**

If you simply want to elevate a plugin, you first have to build this rojo project using ` rojo build` CLI command and open the model file built in studio.

You should get a single module called `PluginModder`, all you have to do is to create a new plugin structure and require the module using a script, set `pluginRef` in the configuration to your own plugin and then call `loadPlugin` to load the plugin you want to elevate.

You should also include a folder with a number of **empty** ModuleScripts and register them with `addModules`, you can learn about why you might have to do this in "How does it work?"

The code should look something like this:
```lua
local PluginModder = require(plugin.PluginModder)
PluginModder.config.pluginRef = plugin

PluginModder.addModules(plugin.ModuleFolder:GetChildren())
PluginModder.loadPlugin(00000) --This is the plugin's id. Yes, you have to own it.
```

After this is done, save your root folder to a file (**DO NOT SAVE IT AS A PLUGIN, OR ELSE THE CODE WON\'T BE ELEVATED**). you\'ll then have to flip the FFlag `DoNotLoadUnverifiedBuiltIns` to `false` using a tool like CloneTrooper1019's Roblox Studio Mod Manager, after that, you can either add your model file directly to your studio installation's builtin plugins (usually in on `%AppData%\..\local\Roblox Studio\BuiltInPlugins`), or use the mod manager's mod directory.

You can also modify the plugin\'s scripts! All you have to do is pass a function as loadPlugin\'s second argument!
```lua
local PluginModder = require(plugin.PluginModder)
PluginModder.config.pluginRef = plugin

local function handleModify(script)
	if script:IsA("BaseScript") then
		return "print(\"Hello World\")" --this replaces every the source of every Script and LocalScript to "print("Hello World")", while leaving ModuleScripts intact
end
PluginModder.addModules(plugin.ModuleFolder:GetChildren())
PluginModder.loadPlugin(00000) --This is the plugin's id. Yes, you have to own it.
```

## API
```lua
<table> PluginModder.config = {
	proxy = "rprxy.xyz",
	pluginRef = nil
}
```
This member allows you to configure the module. 
`proxy` is the website that will be used as a proxy if PluginModder isn\'t elevated (Roblox blocks requests to roblox.com, even in plugins), it\'s `rprxy.xyz` by default.
`pluginRef` is the plugin instance PluginModder uses to fill in the plugin global from emulated plugins, needs to be set before loading a plugin.
- - -
```lua
<function> PluginModder.loadPlugin(pluginId: string|number, injectSource: function|nil)
```
This function loads a plugin, *it can be called as many time as you want, as long as host modules aren\'t required to be used or there are enough available to handle loading that plugin.*
`pluginId` is the id of the plugin that should be fetched from Roblox, the Roblox Studio user must own it.
`ìnjectSource` is a function that will be called for every script in the plugin, if it returns a string, that string will be the new source of that module, it\'s be called with a single argument, the script.
```lua
local function handleInject(script)
	if module.Name = "Crab" then
		return "print(\"Crab is no more \")" --Crab will now print this message instead of running its actual code
	end
	return nil --Since we've returned nil, no change will happen
end
```
- - -
```lua
<function> PluginModder.addModules(modules: table)
```
An array of modules that should be used as a host module. Due to Roblox limitations, it\'s required to call if debug.loadmodule isn\'t available and isn\'t being ran on edit mode. You can read more about it in "How does it work?"
## How does it work?
PluginModder first fetches the plugin\'s source using [`DataModel:GetObjects()`](https://developer.roblox.com/en-us/api-reference/function/DataModel/GetObjects "`DataModel:GetObjects()`"), then it determines if each script\'s source should be overwritten based on the function that\'s passed in its API. Once the sources are modified, it\'s time to actually run the code, and that\'s where PluginModder will be the most useful for you! Here\'s the steps it goes through to run the code:

- Determine if the script is a [`BaseScript`](https://developer.roblox.com/en-us/api-reference/class/BaseScript "`BaseScript`") or a [`ModuleScript`](https://developer.roblox.com/en-us/api-reference/class/ModuleScript "`ModuleScript`")
	- If it\'s a BaseScript, modify its code and treat it as a module, then require its code as soon as every script is ready
	- If it\'s a ModuleScript, just modify its code for now
- The BaseScripts are now being required, but not using `require`! We can\'t actually require new modules! Built-In Plugins can\'t require all modules, just modules that are included in their model file, so we have to get around this restriction. But how? The answer is using a custom require function!
	- First, we see if the module\'s result has been cached in a custom  cache and return that instead, so we\'re not running the same thing twice, just like `require`.
	- Then we check if the module we\'re requiring is external (`require(id)`), luckily builtins can require external modules, but not if they\'re cached, that\'s no problem since we\'re already caching modules anyways.
	- Before starting the truly insane hacks, we check if we\'re actually in an elevated context, we can just require the modules normally if we\'re not (although that means the code won\'t be elevated either, which is the whole point of PluginModder...)
	- OK, we\'re elevated, it\'s time to pull a hack out of the hack bag. First thing we\'re doing is setting the FFlag `FFlagEnableLoadModule` to true. Turns out there\'s 3 functions in `DataModel` that can define certain fast values, they are `DefineFastFlag`, `DefineFastInt` and `DefineFastString` respectively, so all we have to do is `game:DefineFastFlag("FFlagEnableLoadModule", true)` and suddenly a new function in the debug library is available, `debug.loadmodule()`. loadmodule is similar to require, but it doesn\'t have the "only modules included in the plugin\'s model file" restriction and it also doesn\'t cache, but we already have our own custom cache so that\'s no problem! However, loadmodule is just a debugging function and we can\'t expect it to exist forever, so we need a fallback method...
	- We could use loadstring if loadmodule isn\'t available for some reason! So we make a separate script and make it call loadstring instead, so our own environment doesn\'t interfere with the module being emulated. Of course, we also have that script\'s env to worry about, but that\'s much simpler to deal with, but all we have to do is:
		- Define `plugin` as nil. (Modules don\'t have access to it, and BaseScripts we\'re emulating are already modified to handle that.)
		- Get rid of any arguments we need to use in the loadstring process by attaching some code that sets those variables to nil in the source.

	However, there is one issue with this fallback method (or else it\'d be the primary method!), and that is how functions called in the plugin depend on the context of the actual game... this means loadstring will work normally while in edit mode, but `ServerScriptService.LoadStringEnabled` needs to be true in a server simulation for loadstring to work and it won\'t work at all on the client!? Why would you do this Roblox!?
	- With loadmodule and loadstring both unavailable, we have to resort to our last and hackiest method. Sure, you can\'t require modules that weren\'t packaged... but nobody said anything about editing existing ones ;). Yes, since plugins can edit a script\'s source, that means you can technically add a source to an empty module and it\'ll still be considered a "packaged module", so we package a bunch of empty modules in the plugin PluginModder is included on and use one as a host each time we need to require a module. This comes with a problem though, `script` will point to the host module instead of the original module. So to fix this, we use `Ìnstance:GetDebugId()`, this is a very handy function available for plugins that gives you an unique id for every instance in the game, so, we first register that id in PluginModder, then we modify the source of the module and register that id as an argument in a call to a function in PluginModder\'s internal api that returns the original module, therefore solving the emulation issue, and making our emulation of the real module flawless*. The only real limitation of this method is that each module can only be written once (require remembers if the module was cached even if you edited it!), so you only have a limited amount of times you can require.
	- After all of this is done, we also modify the source of the module and define `require` as this custom require function, making all of this apply to all modules, and not just the BaseScripts!

## Known Issues
- *Remember how I said the emulation would be perfect? That\'s actually a lie, because in the case of a BaseScript, its ClassName would now be `ModuleScript` instead of `Script` or `LocalScript`, which could be an issue if the emulated plugin is checking for that for some reason.
- Probably a lot of tiny hidden bugs, I abandoned this project when its code was complete, but midway through testing, so not all behavior is accounted for! 

## Credits
Special thanks to [metatablecatgirl](https://www.roblox.com/users/8094244/profile "metatablecatgirl") for finding out about debug.loadmodule\'s existence.