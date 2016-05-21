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
	
	limx = (memory.readbyte(0x5E)+1)*0x10
	
	if memory.readbyte(0x1412)==1 then
		x = math.floor((marioX+dx+8)/16)
		y = math.floor((marioY+dy)/16)
		if x>limx or x<0 then return 0 end
		return memory.readbyte(0x1C800 + math.floor(x/0x10)*0x100 + math.floor(y/0x10)*0x10*limx + (y%0x10)*0x10 + x%0x10)
	else
		x = math.floor((marioX+dx+8)/16)
		y = math.floor((marioY+dy)/16)
		return memory.readbyte(0x1C800 + math.floor(x/0x10)*0x1B0 + y*0x10 + x%0x10)
	end
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
			if tilesSeen["L" .. level .. "X" .. x .. "Y" .. y] == nil then
				tilesSeen["L" .. level .. "X" .. x .. "Y" .. y] = 1
				totalSeen = totalSeen + 1;
				if tile == 1 then
					totalSeen = totalSeen + 5;
				end
				timeout = TimeoutConstant
			end
			if tile == 1 then
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
	return memory.readbyte(0x1493) > 0 or memory.readbyte(0x1434) > 0
end

function SMW.isBossfight()
	--read level mode and check if its a boss mode
	return (memory.readbyte(0x0D9B) >= 0x80 or memory.readbyte(0x0DDA) == 5)
end

function SMW.guessFitness()

	--we have to remember if we were in a bossfight
	--because for lemmy and wendy, we'd have to check by music
	--and when mario dies the check for music fails
	if not wasBossfight then
		wasBossfight = SMW.isBossfight();
		if wasBossfight then
			bossfightTime = SMW.getTimeLeft();
			bossfightFrame = pool.currentFrame;
		end
	end
	
	local fitness = totalSeen - pool.currentFrame / 2
	if SMW.levelBeat() then
		fitness = fitness + 3000;
	end
	if wasBossfight then
		--if we haven't spent half of the time we were in the bossfight yet, we gain points
		if SMW.getTimeLeft()>=bossfightTime/2 then
			--fitness is totalSeen - frame at start of bossfight/2 + frames in bossfight/2
			fitness = fitness + (pool.currentFrame - bossfightFrame/2)		
		else
			--fitness is totalSeen - frame at start of bossfight/2 + (half of the frames in the bossfight)/2 - frames after that half/2
			fitness = fitness + (pool.currentFrame - bossfightFrame)/2 + (bossfightTime*20 - (pool.currentFrame-bossfightFrame-bossfightTime*20))/2
		end
	end
	if wasBossfight and SMW.levelBeat() then
		fitness = 50000 - pool.currentFrame
	end
	return fitness
end

function SMW.getTimeLeft()
	return memory.readbyte(0xF31)*100 + memory.readbyte(0xF32)*10 + memory.readbyte(0xF31)
end

function SMW.reset()
	wasBossfight = false
end

function SMW.calcFitness(species, genome)
	SMW.getPositions()
	
	if memory.readbyte(0x009D)==0 then
		timeout = timeout - 1
	end
	
	timeoutBonus = pool.currentFrame / 4
	if (timeout + timeoutBonus <= 0 and (not wasBossfight)) or SMW.isDead() or SMW.levelBeat() then
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