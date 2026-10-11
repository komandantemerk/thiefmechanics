if SERVER then
	function PLUGIN:PlayerDisconnected(client)
		ix.lockpick.StopPickAction(client)
	end
end
