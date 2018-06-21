-- Full Credit to MarI/O and LuigI/O for inspiration in this project.
-- This project is more of an attempt for me to learn more about AI
-- than anything else. So, I took a look at the two aforementioned
-- projects quite a bit to see how things were structured, and then 
-- tried to implement it on my own.

local BoxRadius = 3

local PlayerX
local PlayerY
local OldPlayerX
local OldPlayerY
local Blocks

local CurrentSpecie = 0
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
        gui.text(0, i * 15 + 25, "Enemy coords: " .. enemy.x .. " " .. enemy.y)
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
  
  for i = 0, number do
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
  
  if (true) then
    StationaryFrames = StationaryFrames + 1
  else
    StationaryFrames = 0
  end
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

local genome = getRandomGenome(1)

while true do
  local IsAlive = (memory.readbyte(0x00E) ~= 0x0B)
  local fitness = memory.readbyte(0x0086) + 256 * memory.readbyte(0x071A) - 40
  print(StationaryFrames)
  if (IsAlive == false or StationaryFrames >= 180) then
      CurrentSpecie = CurrentSpecie + 1
      memory.writebyte(0x075A, 2)
  end
  
  --memory.writebyte(0x0787, 0x02)
  getPlayerLocation()
  
  local blocks = {}
  blocks = getBlocks(blocks)
  blocks = getEnemies(blocks)
  testSpecie(genome[0], blocks)
  
  display(blocks)
  displayJoypad(joypad.getimmediate())
  
  gui.text(0, 10, "Player Position: " .. PlayerX .. " " .. PlayerY)
  gui.text(0, 25, "Fitness: " .. fitness)
  emu.frameadvance()
end
