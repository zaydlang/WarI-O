-- Full Credit to MarI/O and LuigI/O for inspiration in this project.
-- This project is more of an attempt for me to learn more about AI
-- than anything else. So, I took a look at the two aforementioned
-- projects quite a bit to see how things were structured, and then 
-- tried to implement it on my own.

local BoxRadius = 3

local PlayerX
local PlayerY
local OldPlayerFitness
local Blocks

local CurrentSpecie = 1
local StationaryFrames = 0

function getPlayerLocation()
  PlayerX = memory.readbyte(0x071C) + 256 * memory.readbyte(0x071A)
  PlayerY = memory.readbyte(0x03B8)
end

function getBlocks(blocks)
  for i = 0, 16 do
    blocks[i] = {}
    for j = 0, 13 do -- 16 * 13 = 208
      local block = {}
      local TempX = PlayerX + (i) * 16
      local BlockX = math.floor((TempX % 256) / 16)
      local BlockY = j * 16
      
      local BlockAddress = 0
      if (math.floor(TempX / 256) % 2 == 1) then BlockAddress = 208 end
      BlockAddress = 0x0500 + BlockAddress + BlockY + BlockX
      if (memory.readbyte(BlockAddress) ~= 0 and BlockY < 13 * 16 and BlockY >= 0) then block.value = 10
      else block.value = 0 end
      
      blocks[i][j] = block
    end
  end
  
  return blocks
end

function getEnemies(blocks)
  for i = 0, 5 do
    if (memory.readbyte(0x00F + i) == 1) then
      local enemy = {}
      enemy.x = (memory.readbyte(0x0087 + i) + 256 * memory.readbyte(0x006E + i) - PlayerX)
      
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
    
    -- Creating Layer 1
    local NodesOne = {}
    for j = 0, 16 do
      NodesOne[j] = {}
      for k = 0, 13 do
        NodesOne[j][k] = {}
        NodesOne[j][k].WeightA = math.random() - 0.5
        NodesOne[j][k].WeightB = math.random() * 0.1
        NodesOne[j][k].out = math.floor(math.random(6))
        NodesOne[j][k].value = 0
      end
    end
    specie.LayerOne = NodesOne
    
    -- Creating Layer 2
    local NodesTwo = {}
    for i = 0, 6 do
      NodesTwo[i] = {}
      NodesTwo[i].value = 0
      NodesTwo[i].NumberToAverage = 0
    end
    specie.LayerTwo = NodesTwo
    
    genome[i] = specie
  end
  
  return genome
end

function testSpecie(specie, blocks)
  -- First Layer
  local NodesOne = specie.LayerOne
  for i = 0, 16 do
    for j = 0, 13 do
      NodesOne[i][j].value = sigmoid(NodesOne[i][j].WeightA * blocks[i][j].value + NodesOne[i][j].WeightB)
    end
  end
  
  -- Second Layer
  local NodesTwo = specie.LayerTwo
  for i = 0, 16 do
    for j = 0, 13 do
      NodesTwo[NodesOne[i][j].out].value = NodesTwo[NodesOne[i][j].out].value + NodesOne[i][j].value
      NodesTwo[NodesOne[i][j].out].NumberToAverage = NodesTwo[NodesOne[i][j].out].NumberToAverage + 1
    end
  end
  for i = 0, 6 do
    NodesTwo[i].value = NodesTwo[i].value / NodesTwo[i].NumberToAverage
    NodesTwo[i].NumberToAverage = 0
  end
  
  -- Sending Input
  
  local buttons = {}
  buttons["P1 A"]      = NodesTwo[1].value > 0.5
  buttons["P1 B"]      = NodesTwo[2].value > 0.5
  buttons["P1 Up"]     = NodesTwo[3].value > 0.5
  buttons["P1 Down"]   = NodesTwo[4].value > 0.5
  buttons["P1 Left"]   = NodesTwo[5].value > 0.5
  buttons["P1 Right"]  = NodesTwo[6].value > 0.5
  buttons["P1 Start"]  = false
  buttons["P1 Select"] = false
  joypad.set(buttons)
  
  -- Current Fitness
  local fitness = memory.readbyte(0x0086) + 256 * memory.readbyte(0x006D)
  specie.fitness = fitness
  if (OldPlayerFitness == fitness) then
    StationaryFrames = StationaryFrames + 1
    if (StationaryFrames >= 180) then
      memory.writebyte(0x00E, 0x0B) -- My way of killing Mario.
    end
  else
    StationaryFrames = 0
  end
  OldPlayerFitness = fitness
  gui.text(0, 40, "Fitness: " .. fitness)
end

function sigmoid(x) 
  return 1 / (1 + math.exp(-1 * x))
end

function display(blocks)
  for i = 0, 16 do
    for j = 0, 13 do
      if (blocks[i][j].value == 10) then
        gui.drawBox(i * 2 * BoxRadius - BoxRadius, j * 2 * BoxRadius - BoxRadius + 32, i * 2 * BoxRadius + BoxRadius, j * 2 * BoxRadius + BoxRadius + 32, "white") 
      end
      if (blocks[i][j].value == -10) then
        gui.drawBox(i * 2 * BoxRadius - BoxRadius, j * 2 * BoxRadius - BoxRadius + 32, i * 2 * BoxRadius + BoxRadius, j * 2 * BoxRadius + BoxRadius + 32, "red")
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

function compare(speciea, specieb)
    return speciea.fitness > specieb.fitness
end

function newgenome(oldgenome)
  local PercentToBreed = 0.2
  local newgenome = {}
  local i = 1
  
  table.sort(oldgenome, compare)
  for i = 1, PercentToBreed * #oldgenome do
    newgenome[i] = oldgenome[i]
  end
  
  newgenome = breed(newgenome, #oldgenome)
  for i = 1, 20 do
    print(newgenome[i].fitness)
  end
  return newgenome
end

function breed(newgenome, size)
  local OldGenomeSize = #newgenome
  
  for i = #newgenome + 1, size do
    local ParentA = math.floor(math.random() * OldGenomeSize) + 1
    local ParentB = math.floor(math.random() * OldGenomeSize) + 1
    newgenome[i] = {}
    newgenome[i].LayerOne = {}
    newgenome[i].LayerTwo = {}
    
    -- Layer One
    for j = 0, 16 do
      newgenome[i].LayerOne[j] = {}
      
      for k = 0, 13 do
        newgenome[i].LayerOne[j][k] = {}
        
        if (math.random() > 0.5) then
          newgenome[i].LayerOne[j][k].WeightA = newgenome[ParentA].LayerOne[j][k].WeightA
          newgenome[i].LayerOne[j][k].WeightB = newgenome[ParentA].LayerOne[j][k].WeightB
        else
          newgenome[i].LayerOne[j][k].WeightA = newgenome[ParentB].LayerOne[j][k].WeightA
          newgenome[i].LayerOne[j][k].WeightB = newgenome[ParentB].LayerOne[j][k].WeightB
        end
        
        if (math.random() > 0.5) then
          newgenome[i].LayerOne[j][k].out = newgenome[ParentA].LayerOne[j][k].out
        else
          newgenome[i].LayerOne[j][k].out = newgenome[ParentB].LayerOne[j][k].out
        end
        
        newgenome[i].value = 0
        
        if (math.random() < 0.01) then
          newgenome[i].LayerOne[j][k].WeightA = newgenome[i].LayerOne[j][k].WeightA + ((math.random() * 0.2) - 0.1)
          newgenome[i].LayerOne[j][k].WeightB = newgenome[i].LayerOne[j][k].WeightB + ((math.random() * 0.02) - 0.01)
        end
      end
    end
    
    -- Layer Two
    for j = 0, 6 do
      newgenome[i].LayerTwo[j] = {}
      newgenome[i].LayerTwo[j].value = 0
      newgenome[i].LayerTwo[j].NumberToAverage = 0
    end
  end
  
  return newgenome
end

function loadGenome(number)
  print("Loading File...")
  local filename = "load.gen"
  local file = io.open(filename, "r")
  local genome = {}
  
  for i = 1, number do
    local specie = {}
    -- Creating Layer 1
    local NodesOne = {}
    for j = 0, 16 do
      NodesOne[j] = {}
      for k = 0, 13 do
        NodesOne[j][k] = {}
        NodesOne[j][k].WeightA = file:read("*number")
        NodesOne[j][k].WeightB = file:read("*number")
        NodesOne[j][k].out = file:read("*number")
        NodesOne[j][k].value = 0
      end
    end
    specie.LayerOne = NodesOne
    
    -- Creating Layer 2
    local NodesTwo = {}
    for i = 0, 6 do
      NodesTwo[i] = {}
      NodesTwo[i].value = 0
      NodesTwo[i].NumberToAverage = 0
    end
    specie.LayerTwo = NodesTwo
    
    genome[i] = specie
  end
  file:close()
  --]]
  print("File Loaded.")
  return genome
end

-- Initialization
local genome = getRandomGenome(100) -- loadGenome() or getRandomGenome()
local Generation = 1
OldPlayerFitness = memory.readbyte(0x0086) + 256 * memory.readbyte(0x071A) - 40
savestate.load("SMB.State")

function saveGenome()
  local filename = Generation .. ".gen"
  local file = io.open(filename, "w")
  for i = 1, 100 do
    for j = 0, 16 do
       for k = 0, 13 do
          file:write(genome[i].LayerOne[j][k].WeightA .. "\n")
          file:write(genome[i].LayerOne[j][k].WeightB .. "\n")
          file:write(genome[i].LayerOne[j][k].out .. "\n")
       end
    end
  end
  file:close()
end

while true do
  local IsAlive = (memory.readbyte(0x00E) ~= 0x0B)
  if (memory.readbyte(0x00B5) > 1) then IsAlive = false end
  
  if (IsAlive == false) then
      savestate.load("SMB.State")
      if (CurrentSpecie ~= #genome) then
        CurrentSpecie = CurrentSpecie + 1
        StationaryFrames = 0
      else
        saveGenome(Generation)
        genome = newgenome(genome)
        Generation = Generation + 1
        CurrentSpecie = 1
      end
  end
  
  --memory.writebyte(0x0787, 0x02)
  getPlayerLocation()
  local blocks = {}
  blocks = getBlocks(blocks)
  blocks = getEnemies(blocks)
  testSpecie(genome[CurrentSpecie], blocks)
  display(blocks)
  displayJoypad(joypad.getimmediate())
  
  gui.text(0, 10, "Generation: " .. Generation)
  gui.text(0, 25, "Species: " .. CurrentSpecie)
  emu.frameadvance()
end

-- 7:45 PM Start Program
