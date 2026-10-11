ITEM.name = "Отмычка"
ITEM.description = "Простая металлическая отмычка. Подойдёт для взлома закрытых ящиков с паролем и дверей игроков, но результат непредсказуем."
ITEM.model = "models/props_c17/TrapPropeller_Lever.mdl"
ITEM.width = 2
ITEM.height = 1
ITEM.category = "Инструменты"
ITEM.contraband = true

function ITEM:CanTransfer(inventory, newInventory)
	return !self.bBeingUsed
end
