ix.lockpick = ix.lockpick or {}

ix.lockpick.PICK_TIME = 8
ix.lockpick.PICK_TIME_IMPROVISED = 5
ix.lockpick.TRACE_DISTANCE = 96

ix.lockpick.SOUNDS = {
	start = "doors/door_latch1.wav",
	working = "physics/metal/metal_solid_impact_soft",
	success = "doors/latchunlocked1.wav",
	fail = "doors/door_locked2.wav",
	broke = "physics/metal/metal_box_break2.wav"
}

ix.lockpick.OUTCOME = {
	OPEN = 1,
	FAIL = 2,
	BREAK = 3,
	OPEN_AND_BREAK = 4
}

ix.lockpick.itemConfigs = {
	lockpick = {
		chances = {
			{chance = 50, outcome = ix.lockpick.OUTCOME.OPEN},
			{chance = 25, outcome = ix.lockpick.OUTCOME.FAIL},
			{chance = 25, outcome = ix.lockpick.OUTCOME.BREAK}
		}
	},
	lockpick_improvised = {
		pickTime = ix.lockpick.PICK_TIME_IMPROVISED,
		chances = {
			{chance = 25, outcome = ix.lockpick.OUTCOME.OPEN},
			{chance = 50, outcome = ix.lockpick.OUTCOME.BREAK},
			{chance = 25, outcome = ix.lockpick.OUTCOME.OPEN_AND_BREAK}
		}
	}
}

function ix.lockpick.GetSoundTimerID(client, target)
	return "ixLockpickSound_" .. client:SteamID64() .. "_" .. target:EntIndex()
end

function ix.lockpick.GetActionTimerID(client)
	return "ixLockpickAction_" .. client:SteamID64()
end

function ix.lockpick.StopPickSounds(client, target)
	if SERVER and IsValid(target) then
		timer.Remove(ix.lockpick.GetSoundTimerID(client, target))
	end
end

function ix.lockpick.StopPickAction(client, target)
	if !SERVER then
		return
	end

	timer.Remove(ix.lockpick.GetActionTimerID(client))

	if IsValid(client) then
		client:SetAction()
	end

	if IsValid(target) then
		ix.lockpick.StopPickSounds(client, target)
	end
end

function ix.lockpick.StartPickSounds(client, target)
	if !SERVER then
		return
	end

	local timerID = ix.lockpick.GetSoundTimerID(client, target)

	target:EmitSound(ix.lockpick.SOUNDS.start, 55, math.random(100, 115))

	timer.Create(timerID, 1.25, 0, function()
		if !IsValid(client) or !IsValid(target) then
			timer.Remove(timerID)
			return
		end

		target:EmitSound(ix.lockpick.SOUNDS.working .. math.random(1, 3) .. ".wav", 50, math.random(90, 110))
	end)
end

function ix.lockpick.GetDoorOwner(entity)
	if !IsValid(entity) then
		return
	end

	local parent = entity.ixParent

	if IsValid(parent) then
		return parent:GetDTEntity(0)
	end

	return entity:GetDTEntity(0)
end

function ix.lockpick.IsValidContainerTarget(entity)
	return IsValid(entity)
		and entity:GetClass() == "ix_container"
		and entity:GetLocked()
end

function ix.lockpick.IsValidDoorTarget(entity)
	if !IsValid(entity) or !entity:IsDoor() then
		return false
	end

	if entity:GetNetVar("disabled") then
		return false
	end

	-- комбайновский замок и faction/class-двери не взламываем отмычкой
	if IsValid(entity.ixLock) then
		return false
	end

	if entity:GetNetVar("faction") or entity:GetNetVar("class") then
		return false
	end

	-- только двери, принадлежащие игроку
	if !IsValid(ix.lockpick.GetDoorOwner(entity)) then
		return false
	end

	-- IsLocked доступен только на сервере
	if SERVER and !entity:IsLocked() then
		return false
	end

	return true
end

function ix.lockpick.IsValidTarget(entity)
	return ix.lockpick.IsValidContainerTarget(entity) or ix.lockpick.IsValidDoorTarget(entity)
end

function ix.lockpick.GetTarget(client)
	if !IsValid(client) then
		return
	end

	local aim = client:GetAimVector()
	local start = client:GetShootPos()
	local data = {
		start = start,
		endpos = start + aim * ix.lockpick.TRACE_DISTANCE,
		filter = client
	}

	local trace = util.TraceLine(data)

	if ix.lockpick.IsValidTarget(trace.Entity) then
		return trace.Entity
	end

	data.mins = Vector(-12, -12, -12)
	data.maxs = Vector(12, 12, 12)

	trace = util.TraceHull(data)

	if ix.lockpick.IsValidTarget(trace.Entity) then
		return trace.Entity
	end

	local bestEntity
	local bestDistance = ix.lockpick.TRACE_DISTANCE * ix.lockpick.TRACE_DISTANCE

	for _, entity in ipairs(ents.FindInSphere(start, ix.lockpick.TRACE_DISTANCE)) do
		if ix.lockpick.IsValidTarget(entity) then
			local direction = (entity:WorldSpaceCenter() - start):GetNormalized()

			if aim:Dot(direction) > 0.7 then
				local distance = client:GetPos():DistToSqr(entity:GetPos())

				if distance < bestDistance then
					bestEntity = entity
					bestDistance = distance
				end
			end
		end
	end

	return bestEntity
end

function ix.lockpick.RollOutcome(chances)
	local roll = math.random(1, 100)
	local cumulative = 0

	for i = 1, #chances do
		cumulative = cumulative + chances[i].chance

		if roll <= cumulative then
			return chances[i].outcome
		end
	end

	return chances[#chances].outcome
end

function ix.lockpick.UnlockContainer(entity, client, bSilent)
	entity:SetLocked(false)
	entity.password = nil
	entity.Sessions = entity.Sessions or {}
	entity.PasswordAttempts = entity.PasswordAttempts or {}

	table.Empty(entity.Sessions)
	table.Empty(entity.PasswordAttempts)

	if SERVER then
		entity:EmitSound(ix.lockpick.SOUNDS.success, 65, 100)
	end

	if !bSilent then
		client:Notify("Вы вскрыли замок ящика.")
	end
end

function ix.lockpick.UnlockDoor(entity, client, bSilent)
	if !SERVER then
		return
	end

	local partner = entity:GetDoorPartner()

	entity:Fire("unlock")

	if IsValid(partner) then
		partner:Fire("unlock")
	end

	entity:EmitSound(ix.lockpick.SOUNDS.success, 65, 100)

	if !bSilent then
		client:Notify("Вы вскрыли замок двери.")
	end

	hook.Run("PlayerLockpickedDoor", client, entity, partner)
end

function ix.lockpick.UnlockTarget(entity, client, bSilent)
	if ix.lockpick.IsValidContainerTarget(entity) then
		ix.lockpick.UnlockContainer(entity, client, bSilent)
	elseif entity:IsDoor() then
		ix.lockpick.UnlockDoor(entity, client, bSilent)
	end
end

function ix.lockpick.HandleOutcome(outcome, item, entity, client)
	if outcome == ix.lockpick.OUTCOME.OPEN then
		ix.lockpick.UnlockTarget(entity, client)
	elseif outcome == ix.lockpick.OUTCOME.FAIL then
		if SERVER then
			entity:EmitSound(ix.lockpick.SOUNDS.fail, 60, 100)
		end

		client:Notify("Замок не поддаётся — отмычка цела.")
	elseif outcome == ix.lockpick.OUTCOME.BREAK then
		if SERVER then
			entity:EmitSound(ix.lockpick.SOUNDS.broke, 65, math.random(95, 105))
		end

		client:Notify("Отмычка сломалась, замок остался закрытым.")
		item:Remove()
	elseif outcome == ix.lockpick.OUTCOME.OPEN_AND_BREAK then
		ix.lockpick.UnlockTarget(entity, client, true)

		if SERVER then
			entity:EmitSound(ix.lockpick.SOUNDS.broke, 65, math.random(95, 105))
		end

		client:Notify("Замок вскрыт, но отмычка сломалась.")
		item:Remove()
	end
end

function ix.lockpick.StartPickAction(client, item, target, chances, pickTime)
	local timerID = ix.lockpick.GetActionTimerID(client)
	local reps = math.max(1, math.ceil(pickTime / 0.1))

	ix.lockpick.StopPickAction(client, target)

	item.bBeingUsed = true
	item.ixLockpickTarget = target

	client:SetAction("Взламываете замок...", pickTime)
	ix.lockpick.StartPickSounds(client, target)

	timer.Create(timerID, 0.1, reps, function()
		if !IsValid(client) or !IsValid(target) or !item.bBeingUsed then
			ix.lockpick.StopPickAction(client, target)
			item.bBeingUsed = false
			item.ixLockpickTarget = nil
			return
		end

		if client:GetPos():DistToSqr(target:GetPos()) > 16384 then
			ix.lockpick.StopPickAction(client, target)
			item.bBeingUsed = false
			item.ixLockpickTarget = nil
			client:Notify("Вы отошли слишком далеко.")
			return
		end

		if timer.RepsLeft(timerID) == 0 then
			ix.lockpick.StopPickAction(client, target)
			item.bBeingUsed = false
			item.ixLockpickTarget = nil

			if !ix.lockpick.IsValidTarget(target) then
				client:Notify("Замок больше недоступен для взлома.")
				return
			end

			ix.lockpick.HandleOutcome(ix.lockpick.RollOutcome(chances), item, target, client)
		end
	end)
end

function ix.lockpick.CreatePickFunction(chances, pickTime)
	pickTime = pickTime or ix.lockpick.PICK_TIME

	return {
		name = "Взломать",
		OnClick = function(item)
			if IsValid(ix.gui.menu) then
				ix.gui.menu:Remove()
			end
		end,
		OnRun = function(item)
			local client = item.player

			if !IsValid(client) or client:IsRestricted() then
				return false
			end

			local target = ix.lockpick.GetTarget(client)

			if !ix.lockpick.IsValidTarget(target) then
				client:Notify("Нужно смотреть на закрытый ящик или дверь игрока.")
				return false
			end

			if client:GetPos():DistToSqr(target:GetPos()) > 16384 then
				client:Notify("Вы слишком далеко.")
				return false
			end

			if item.bBeingUsed then
				return false
			end

			ix.lockpick.StartPickAction(client, item, target, chances, pickTime)

			return false
		end,
		OnCanRun = function(item)
			return !IsValid(item.entity) and !item.bBeingUsed
		end
	}
end

function ix.lockpick.RegisterItems()
	for uniqueID, config in pairs(ix.lockpick.itemConfigs) do
		local itemTable = ix.Item:Get(uniqueID)

		if itemTable then
			itemTable.functions.pick = ix.lockpick.CreatePickFunction(config.chances, config.pickTime)
			ix.Item:Register(uniqueID, itemTable)
		end
	end
end
