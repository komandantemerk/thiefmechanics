local PLUGIN = PLUGIN

PLUGIN.name = "Thief Mechanics"
PLUGIN.author = "HL2RP"
PLUGIN.description = "Механика взлома закрытых ящиков с паролем при помощи отмычек."

ix.util.Include("sv_hooks.lua")

function PLUGIN:InitializedPlugins()
	for i = 0, 10 do
		ix.Craft:LoadFromDir(self.folder.."/recipes/crafting/"..i, "recipe")
	end

	if ix.lockpick and ix.lockpick.RegisterItems then
		ix.lockpick.RegisterItems()
	end
end

if ix.lockpick and ix.lockpick.RegisterItems then
	ix.lockpick.RegisterItems()
end
