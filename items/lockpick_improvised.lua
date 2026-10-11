ITEM.name = "Отвёртка с заколкой"
ITEM.description = "Импровизированный инструмент для взлома: отвёртка и заколка. Можно вскрывать ящики и двери игроков, но надёжность низкая."
ITEM.model = "models/props_junk/junk_screwdriver.mdl"
ITEM.width = 1
ITEM.height = 1
ITEM.category = "Инструменты"
ITEM.contraband = true

function ITEM:CanTransfer(inventory, newInventory)
	return !self.bBeingUsed
end
