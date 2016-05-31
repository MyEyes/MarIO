local history = {}

history.generations = {}


function history.clear()
	history.generations = {}
end

function history.save(filename)
	local file = io.open(filename, "w")
	file:write(#history.generations .. "\n")
	for n, generation in ipairs(history.generations) do
		file:write(generation.maxFitness .. "\n")
		file:write(#generation.species .. "\n")
		for m,species in ipairs(generation.species) do
			file:write(species.name .. "\n")
			file:write(species.topFitness .. "\n")
		end
	end
	file:close()
end

function history.load(filename)
	history.clear()
	local file = io.open(filename, "r")
	local numGens = file:read("*number")
	for g=1,numGens do
		history.generations[g] = {}
		history.generations[g].maxFitness = file:read("*number")
		local numSpecies = file:read("*number")
		history.generations[g].species = {}
		for s=1,numSpecies do
			history.generations[g].species[s] = {}
			--read to end of previous line first
			file:read("*line")
			history.generations[g].species[s].name = file:read("*line")
			history.generations[g].species[s].topFitness = file:read("*number")
		end
	end
	file:close()
end

function history.setGeneration(id, pool)
	history.generations[id] = {}
	history.generations[id].maxFitness = pool.maxFitness
	history.generations[id].species = {}
	for n, species in pairs(pool.species) do
		history.generations[id].species[n] = {}
		history.generations[id].species[n].name = pool.species[n].name
		history.generations[id].species[n].topFitness = pool.species[n].topFitness
	end
end

function history.show()
	local width = 250
	local height = 60
	local yBot = 161+height
	local xLeft = 3
	gui.drawBox( xLeft, yBot-height, width+3, yBot, 0xFF000000, 0x80808080)
	gui.drawText(xLeft, yBot-height + 1, "History", 0xFF000000, 11)
	if #history.generations>0 then
		local maxFitness = history.generations[#history.generations].maxFitness
		local nodes = #history.generations+1
		for n, generation in ipairs(history.generations) do
			local last = 0
			if n==1 then last = 0 else last = history.generations[n-1].maxFitness end
			local current = generation.maxFitness
			gui.drawLine(xLeft+n*width/nodes, yBot-height*last/maxFitness, xLeft+(n+1)*width/nodes, yBot-height*current/maxFitness, 0xFF000000)
			last=current
		end
	end
end

return history