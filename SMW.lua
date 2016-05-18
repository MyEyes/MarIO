local SMW = {}

function SMW.init()

	if gameinfo.getromname() == "Super Mario World (USA)" then
	Filename = "DP1.state"
	ButtonNames = {
		"A",
		"B",
		"X",
		"Y",
		"Up",
		"Down",
		"Left",
		"Right",
	}
	console.writeline("Loaded SMW Package")
	else
		error("Not Super Mario World");
	end
	
end

function SMW.getPositions()
	marioX = memory.read_s16_le(0x94)
	marioY = memory.read_s16_le(0x96)
	
	local layer1x = memory.read_s16_le(0x1A);
	local layer1y = memory.read_s16_le(0x1C);
	
	screenX = marioX-layer1x
	screenY = marioY-layer1y
end

function SMW.getTile(dx, dy)
	x = math.floor((marioX+dx+8)/16)
	y = math.floor((marioY+dy)/16)
	
	return memory.readbyte(0x1C800 + math.floor(x/0x10)*0x1B0 + y*0x10 + x%0x10)
end


function SMW.getSprites()
	local sprites = {}
	for slot=0,11 do
		local status = memory.readbyte(0x14C8+slot)
		if status ~= 0 then
			spritex = memory.readbyte(0xE4+slot) + memory.readbyte(0x14E0+slot)*256
			spritey = memory.readbyte(0xD8+slot) + memory.readbyte(0x14D4+slot)*256
			sprites[#sprites+1] = {["x"]=spritex, ["y"]=spritey}
		end
	end		
		
	return sprites
end

function SMW.getExtendedSprites()
	local extended = {}
	for slot=0,11 do
		local number = memory.readbyte(0x170B+slot)
		if number ~= 0 then
			spritex = memory.readbyte(0x171F+slot) + memory.readbyte(0x1733+slot)*256
			spritey = memory.readbyte(0x1715+slot) + memory.readbyte(0x1729+slot)*256
			extended[#extended+1] = {["x"]=spritex, ["y"]=spritey}
		end
	end		
		
	return extended
end

function SMW.getInputs()
	SMW.getPositions()
	
	sprites = SMW.getSprites()
	extended = SMW.getExtendedSprites()
	
	local inputs = {}
	
	local level = memory.readbyte(0x141A);
	
	for dy=-BoxRadius*16,BoxRadius*16,16 do
		for dx=-BoxRadius*16,BoxRadius*16,16 do
			inputs[#inputs+1] = 0
			local x = math.floor((marioX+dx+8)/16)
			local y = math.floor((marioY+dy)/16)
			
			tile = SMW.getTile(dx, dy)
			if tilesSeen["L" .. level .. "X" .. x .. "Y" .. y] == nil and marioY+dy < 0x1B0 then
				tilesSeen["L" .. level .. "X" .. x .. "Y" .. y] = 1
				totalSeen = totalSeen + 1;
				if tile == 1 then
					totalSeen = totalSeen + 5;
				end
				timeout = TimeoutConstant
			end
			if tile == 1 and marioY+dy < 0x1B0 then
				inputs[#inputs] = 1
			end
			
			for i = 1,#sprites do
				distx = math.abs(sprites[i]["x"] - (marioX+dx))
				disty = math.abs(sprites[i]["y"] - (marioY+dy))
				if distx <= 8 and disty <= 8 then
					inputs[#inputs] = -1
				end
			end

			for i = 1,#extended do
				distx = math.abs(extended[i]["x"] - (marioX+dx))
				disty = math.abs(extended[i]["y"] - (marioY+dy))
				if distx < 8 and disty < 8 then
					inputs[#inputs] = -1
				end
			end
		end
	end
	inputs[#inputs+1] = 1
	inputs[#inputs+1] = 0
	--Is a messagebox active
	if memory.readbyte(0x1426) > 0 then
		inputs [#inputs] = 1
	else
		inputs [#inputs] = -1
	end
	
	return inputs
end

function SMW.isDead()
	--read mario animation state, if 62 its the dead mario frame and we're dead
	return (memory.readbyte(0x13E0) == 62)
end

function SMW.levelBeat()
	--read level end countdown timer, if set the level has ended
	return memory.readbyte(0x1493) > 0
end

function SMW.isBossfight()
	--read level mode and check if its a boss mode
	return (memory.readbyte(0x0D9B) >= 0x80 or memory.readbyte(0x0DDA) == 5)
end

function SMW.guessFitness()
	local fitness = totalSeen - pool.currentFrame / 2
	if SMW.levelBeat() then
		fitness = fitness + 3000;
	end
	if SMW.isBossfight() then
		fitness = fitness + pool.currentFrame
	end
	if SMW.isBossfight() and SMW.levelBeat() then
		fitness = 50000 - pool.currentFrame
	end
	return fitness
end

function SMW.calcFitness(species, genome)
	SMW.getPositions()
		
	timeout = timeout - 1
	
	timeoutBonus = pool.currentFrame / 4
	if (timeout + timeoutBonus <= 0 and (not SMW.isBossfight())) or SMW.isDead() or SMW.levelBeat() then
		local fitness = SMW.guessFitness()
		if fitness == 0 then
			fitness = -1
		end
		genome.fitness = fitness
		
		if fitness > pool.maxFitness then
			pool.maxFitness = fitness
			forms.settext(maxFitnessLabel, "Max Fitness: " .. math.floor(pool.maxFitness))
			writeFile("backup." .. pool.generation .. "." .. forms.gettext(saveLoadFile))
		end
		
		-- console.writeline("Gen " .. pool.generation .. " species " .. pool.currentSpecies .. " genome " .. pool.currentGenome .. " fitness: " .. fitness)
		pool.currentSpecies = 1
		pool.currentGenome = 1
		while fitnessAlreadyMeasured() do
			nextGenome()
		end
		initializeRun()
	end
end

return SMW