local boxRadius = 3

local playerX
local playerY

local currentSpecieNumber = 1
local stationaryFrames = 0

local generation = 1
local speciesPerGenome = 50

local charset = {}  do -- [0-9a-zA-Z]
    for c = 48, 57  do table.insert(charset, string.char(c)) end
    for c = 65, 90  do table.insert(charset, string.char(c)) end
    for c = 97, 122 do table.insert(charset, string.char(c)) end
end

function randomString(length)
    if not length or length <= 0 then return '' end
    return randomString(length - 1) .. charset[math.random(1, #charset)]
end

function generateId()
    return randomString(5)
end

function updatePlayerLocation()
    playerX = memory.readbyte(0x071C) + 256 * memory.readbyte(0x071A)
    playerY = memory.readbyte(0x03B8)
end

function getBlocks(blocks)
    for i = 0, 16 do
        blocks[i] = {}
        for j = 0, 13 do -- 16 * 13 = 208
            local block = {}
            local tempX = playerX + (i) * 16
            local blockX = math.floor((tempX % 256) / 16)
            local blockY = j * 16

            local blockAddress = 0
            if (math.floor(tempX / 256) % 2 == 1) then
                blockAddress = 208
            end
            blockAddress = 0x0500 + blockAddress + blockY + blockX
            if (memory.readbyte(blockAddress) ~= 0 and blockY < 13 * 16 and blockY >= 0) then
                block.value = 10
            else
                block.value = 0
            end

            blocks[i][j] = block
        end
    end

    return blocks
end

function getEnemies(blocks)
    for i = 0, 5 do
        if (memory.readbyte(0x00F + i) == 1) then
            local enemy = {}
            enemy.x = (memory.readbyte(0x0087 + i) + 256 * memory.readbyte(0x006E + i) - playerX)

            if (enemy.x >= 0 and enemy.x <= 256) then
                enemy.x = math.floor(enemy.x % 256 / 16)
                enemy.y = math.floor((memory.readbyte(0x00CF + i) - 8) / 16)
                enemy.value = -10
                blocks[enemy.x + 1][enemy.y - 1] = enemy
            end
        end
    end

    blocks.enemies = enemies
    return blocks
end

function getRandomGenome(number)
    local genome = {}

    for i = 1, number do
        local specie = {}

        -- creating layer 1
        local nodes1 = {}
        for j = 0, 16 do
            nodes1[j] = {}
            for k = 0, 13 do
                nodes1[j][k] = {}
                nodes1[j][k].weightA = math.random() - 0.5
                nodes1[j][k].weightB = math.random() * 0.1
                nodes1[j][k].out = math.floor(math.random(6))
                nodes1[j][k].value = 0
            end
        end
        specie.layer1 = nodes1

        -- creating layer 2
        local nodes2 = {}
        for i = 0, 6 do
            nodes2[i] = {}
            nodes2[i].value = 0
            nodes2[i].numberToAverage = 0
        end
        specie.layer2 = nodes2

        specie.id = generateId()

        genome[i] = specie
    end

    return genome
end

local oldFitnessNoTime
local totalPreviousFitness
local finishedLevel = false

function testSpecie(specie, blocks)
    -- First Layer
    local nodes1 = specie.layer1
    for i = 0, 16 do
        for j = 0, 13 do
            nodes1[i][j].value = sigmoid(nodes1[i][j].weightA * blocks[i][j].value + nodes1[i][j].weightB)
        end
    end

    -- Second Layer
    local nodes2 = specie.layer2
    for i = 0, 16 do
        for j = 0, 13 do
            nodes2[nodes1[i][j].out].value = nodes2[nodes1[i][j].out].value + nodes1[i][j].value
            nodes2[nodes1[i][j].out].numberToAverage = nodes2[nodes1[i][j].out].numberToAverage + 1
        end
    end
    for i = 0, 6 do
        nodes2[i].value = nodes2[i].value / nodes2[i].numberToAverage
        nodes2[i].numberToAverage = 0
    end

    local buttons = {}
    buttons["P1 A"] = nodes2[1].value > 0.5
    buttons["P1 B"] = nodes2[2].value > 0.5
    buttons["P1 Up"] = nodes2[3].value > 0.5
    buttons["P1 Down"] = nodes2[4].value > 0.5
    buttons["P1 Left"] = nodes2[5].value > 0.5
    buttons["P1 Right"] = nodes2[6].value > 0.5
    buttons["P1 Start"] = false
    buttons["P1 Select"] = false
    joypad.set(buttons)

    local currentFitnessNoTime = memory.readbyte(0x0086) + 256 * memory.readbyte(0x006D) + totalPreviousFitness
    local time = 0
    time = time + 100 * memory.readbyte(0x07F8)
    time = time + 010 * memory.readbyte(0x07F9)
    time = time + 001 * memory.readbyte(0x07FA)
    local currentFitness = currentFitnessNoTime + 4 * time
    specie.fitness = round(currentFitness)

    if (memory.readbyte(0x001D) == 0x03 and not finishedLevel) then -- sliding down flagpole
        finishedLevel = true
        totalPreviousFitness = currentFitness + 750
    end

    if (finishedLevel) then
        if (memory.readbyte(0x0770) == 02) then -- end of current world
            finishedLevel = false
        end

        return
    end

    if (oldFitnessNoTime == currentFitnessNoTime) then
        stationaryFrames = stationaryFrames + 1
        if (stationaryFrames >= 90) then
            memory.writebyte(0x00E, 0x0B) -- kill Mario
        end
    else
        stationaryFrames = 0
    end

    oldFitnessNoTime = currentFitnessNoTime

    gui.text(0, 40, "Fitness: " .. specie.fitness)
end

function sigmoid(x)
    return 1 / (1 + math.exp(-1 * x))
end

function round(x)
    return math.floor(x + 0.5)
end

function display(blocks)
    for i = 0, 16 do
        for j = 0, 13 do
            if (blocks[i][j].value == 10) then
                gui.drawBox(i * 2 * boxRadius - boxRadius, j * 2 * boxRadius - boxRadius + 32, i * 2 * boxRadius + boxRadius, j * 2 * boxRadius + boxRadius + 32, "white")
            end
            if (blocks[i][j].value == -10) then
                gui.drawBox(i * 2 * boxRadius - boxRadius, j * 2 * boxRadius - boxRadius + 32, i * 2 * boxRadius + boxRadius, j * 2 * boxRadius + boxRadius + 32, "red")
            end
        end
    end
end

function displayJoypad(joypad)
    if (joypad["P1 A"] == true) then gui.drawBox(240, 40, 250, 55, "white", "white") end
    gui.drawText(240, 40, "A")
    if (joypad["P1 B"] == true) then gui.drawBox(240, 55, 250, 70, "white", "white") end
    gui.drawText(240, 55, "B")
    if (joypad["P1 Up"] == true) then gui.drawBox(240, 70, 250, 85, "white", "white") end
    gui.drawText(240, 70, "U")
    if (joypad["P1 Down"] == true) then gui.drawBox(240, 85, 250, 100, "white", "white") end
    gui.drawText(240, 85, "D")
    if (joypad["P1 Left"] == true) then gui.drawBox(240, 100, 250, 115, "white", "white") end
    gui.drawText(240, 100, "L")
    if (joypad["P1 Right"] == true) then gui.drawBox(240, 115, 250, 129, "white", "white") end
    gui.drawText(240, 115, "R")
end

function compare(specie1, specie2)
    return specie1.fitness > specie2.fitness
end

local percentToBreed = 0.2
local baseMutationRate = 0.04
local mutationRate = baseMutationRate
local lastMean = 0
local staleGenerations = 0

local numberToBreed = round(percentToBreed * speciesPerGenome)

function newGenome(oldGenome)
    table.sort(oldGenome, compare)

    local mean = 0
    for i = 1, numberToBreed do
        mean = mean + oldGenome[i].fitness
    end

    mean = round(mean / numberToBreed)

    if (mean <= lastMean) then
        mutationRate = math.min(mutationRate + 0.01, 0.1)
        staleGenerations = staleGenerations + 1
    else
        mutationRate = baseMutationRate
        staleGenerations = 0
    end

    local deltaMean = mean - lastMean
    if (deltaMean > 0) then
        deltaMean = "+" .. deltaMean
    elseif (deltaMean == 0) then
        deltaMean = "-"
    end

    local newGenome = breed(oldGenome)
    print("====================")
    print("generation " .. generation)
    if (generation == 1) then
        print("mean = " .. mean)
    else
        print("mean = " .. mean .. " (" .. deltaMean .. ")")
    end
    print("====================")
    for i = 1, numberToBreed do
        print(oldGenome[i].fitness .. " | " .. oldGenome[i].id)
    end

    lastMean = mean

    if (staleGenerations == 20) then
        newGenome = getRandomGenome(speciesPerGenome)
        staleGenerations = 0
    end

    return newGenome
end

function breed(oldGenome)
    local newGenome = {unpack(oldGenome) }
    for i = numberToBreed + 1, speciesPerGenome do
        local parentA = newGenome[math.floor(math.random() * numberToBreed) + 1]
        local parentB = newGenome[math.floor(math.random() * numberToBreed) + 1]
        newGenome[i] = {}
        newGenome[i].layer1 = {}
        newGenome[i].layer2 = {}

        -- Layer One
        for j = 0, 16 do
            newGenome[i].layer1[j] = {}

            for k = 0, 13 do
                newGenome[i].layer1[j][k] = {}

                if (math.random() > 0.5) then
                    newGenome[i].layer1[j][k].weightA = parentA.layer1[j][k].weightA
                    newGenome[i].layer1[j][k].weightB = parentA.layer1[j][k].weightB
                else
                    newGenome[i].layer1[j][k].weightA = parentB.layer1[j][k].weightA
                    newGenome[i].layer1[j][k].weightB = parentB.layer1[j][k].weightB
                end

                if (math.random() > 0.5) then
                    newGenome[i].layer1[j][k].out = parentA.layer1[j][k].out
                else
                    newGenome[i].layer1[j][k].out = parentB.layer1[j][k].out
                end

                newGenome[i].value = 0

                if (math.random() < mutationRate) then
                    newGenome[i].layer1[j][k].weightA = newGenome[i].layer1[j][k].weightA + ((math.random() * 0.4) - 0.2)
                    newGenome[i].layer1[j][k].weightB = newGenome[i].layer1[j][k].weightB + ((math.random() * 0.04) - 0.02)
                end
            end
        end

        -- Layer Two
        for j = 0, 6 do
            newGenome[i].layer2[j] = {}
            newGenome[i].layer2[j].value = 0
            newGenome[i].layer2[j].numberToAverage = 0
        end

        newGenome[i].fitness = 0
        newGenome[i].id = generateId()
    end

    return newGenome
end

function loadGenome(number)
    -- TODO make this actually work

    print("Loading File...")
    local filename = "load.gen"
    local file = io.open(filename, "r")
    local genome = {}

    for i = 1, number do
        local specie = {}
        -- Creating Layer 1
        local nodes1 = {}
        for j = 0, 16 do
            nodes1[j] = {}
            for k = 0, 13 do
                nodes1[j][k] = {}
                nodes1[j][k].weightA = file:read("*number")
                nodes1[j][k].weightB = file:read("*number")
                nodes1[j][k].out = file:read("*number")
                nodes1[j][k].value = 0
            end
        end
        specie.layer1 = nodes1

        -- Creating Layer 2
        local nodes2 = {}
        for i = 0, 6 do
            nodes2[i] = {}
            nodes2[i].value = 0
            nodes2[i].numberToAverage = 0
        end
        specie.layer2 = nodes2

        genome[i] = specie
        line:read("*line")
    end
    file:close()
    --]]
    print("File Loaded.")
    return genome
end

function resetVariables()
    oldFitnessNoTime = 0
    totalPreviousFitness = 0
end

-- Initialization
local genome = getRandomGenome(speciesPerGenome) -- loadGenome() or getRandomGenome()
local startTime = os.time()
oldFitnessNoTime = memory.readbyte(0x0086) + 256 * memory.readbyte(0x071A) - 40
savestate.load("SMB.State")
resetVariables()

function saveGenome(genome, filename)
    local file = io.open(filename, "w")

    for i = 1, speciesPerGenome do
        file:write("====================\n")
        file:write(genome[i].id .. "\n")
        file:write("====================\n")
        for j = 0, 16 do
            for k = 0, 13 do
                file:write(genome[i].layer1[j][k].weightA .. "\n")
                file:write(genome[i].layer1[j][k].weightB .. "\n")
                file:write(genome[i].layer1[j][k].out .. "\n")
            end
        end
        file:write("\n\n\n")
    end
    file:close()
end

while true do
    local IsAlive = (memory.readbyte(0x00E) ~= 0x0B)
    if (memory.readbyte(0x00B5) > 1) then
        IsAlive = false
    end

    if (IsAlive == false) then
        local buttons = {}
        buttons["P1 A"] = false
        buttons["P1 B"] = false
        buttons["P1 Up"] = false
        buttons["P1 Down"] = false
        buttons["P1 Left"] = false
        buttons["P1 Right"] = false
        buttons["P1 Start"] = false
        buttons["P1 Select"] = false
        joypad.set(buttons)

        savestate.load("SMB.State")
        resetVariables()
        if (currentSpecieNumber ~= #genome) then
            currentSpecieNumber = currentSpecieNumber + 1
            stationaryFrames = 0
        else
            saveGenome(genome, generation .. ".gen")
            genome = newGenome(genome)
            generation = generation + 1
            currentSpecieNumber = 1
        end
    end

    local currentSpecie = genome[currentSpecieNumber]

    updatePlayerLocation()
    local blocks = {}
    blocks = getBlocks(blocks)
    blocks = getEnemies(blocks)
    testSpecie(currentSpecie, blocks)
    display(blocks)
    displayJoypad(joypad.getimmediate())

    local time = os.time() - startTime
    local days = math.floor(time / 86400)
    local hours = math.floor((time % 86400) / 3600)
    local minutes = math.floor((time % 3600) / 60)
    local seconds = math.floor((time % 60))

    local specieTextDigits = math.ceil(math.log(speciesPerGenome) / math.log(10))

    gui.text(0, 10, "Generation: " .. generation)
    gui.text(0, 25, "Species: " .. string.format("%0" .. specieTextDigits .. "d/", currentSpecieNumber) .. speciesPerGenome .. " (" .. currentSpecie.id .. ")")
    gui.text(0, 65, "Mutation Rate: " .. (mutationRate * 100) .. "%")
    gui.text(0, 80, "Stale Generations: " .. staleGenerations)
    gui.text(0, 105, string.format("Runtime: %02d:%02d:%02d:%02d", days, hours, minutes, seconds))
    emu.frameadvance()
end