-- Full Credit to MarI/O and LuigI/O for inspiration in this project.
-- This project is more of an attempt for me to learn more about AI
-- than anything else. So, I took a look at the two aforementioned
-- projects quite a bit to see how things were structured, and then 
-- tried to implement it on my own.

local BoxRadius = 3

local PlayerX
local PlayerY
local Blocks

function getPlayerLocation()
  PlayerX = memory.readbyte(0x071C) + 256 * memory.readbyte(0x071A)
  PlayerY = memory.readbyte(0x03B8)
end

function getBlocks(blocks)
  for i = 0, 16 do
    blocks[i] = {}
    for j = 0, 13 do -- 16 * 13 = 208
      blocks[i][j] = {}
      local TempX = PlayerX + (i) * 16
      local BlockX = math.floor((TempX % 256) / 16)
      local BlockY = j * 16
      
      local BlockAddress = 0
      if (math.floor(TempX / 256) % 2 == 1) then BlockAddress = 208 end
      BlockAddress = 0x0500 + BlockAddress + BlockY + BlockX
      if (memory.readbyte(BlockAddress) ~= 0 and BlockY < 13 * 16 and BlockY >= 0) then blocks[i][j].value = 1 
      else blocks[i][j].value = 0 end
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
        blocks[enemy.x + 1][enemy.y - 1].value = 2
      end
    end
  end
  
  return blocks
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

function display(blocks)
  for i = 0, 16 do
    for j = 0, 13 do
      if (blocks[i][j].value == 1) then
        gui.drawBox(i * 2 * BoxRadius - BoxRadius, j * 2 * BoxRadius - BoxRadius + 32, i * 2 * BoxRadius + BoxRadius, j * 2 * BoxRadius + BoxRadius + 32, "white") 
      end
      if (blocks[i][j].value == 2) then
        gui.drawBox(i * 2 * BoxRadius - BoxRadius, j * 2 * BoxRadius - BoxRadius + 32, i * 2 * BoxRadius + BoxRadius, j * 2 * BoxRadius + BoxRadius + 32, "red")
      end
    end
  end
end

function sigmoid(x)
  return (1 / (1 + e^(-x)))
end

function firstLayer(specie)
  local blocks = specie.blocks
  
  for i = 0, 16 do
    for j = 0, 13 do
      if (blocks[i][j].value ~= nil) then print("Wowzers! " .. i .. " " .. j) 
        blocks[i][j].sig = sigmoid(blocks[i][j].value * blocks[i][j].weightA + blocks[i][j].weightB)
      end
    end
  end
  
  return specie
end

function secondLayer(specie)
  local nodes = specie.buttons
  for i = 0, 6 do
    local previous = nodes.previous
    
    local average = 0
    for j, block in ipairs(previous) do
      average = average + specie.blocks[block[0]][block[1]].sig
    end
    average = average / #previous
    
    if (average > 0.5) then nodes[i].pressed = true else nodes[i].pressed = false end
  end
  
  return specie
end

function sendInput(input)
  local buttons
  buttons["P1 A"] = input[0].pressed
  buttons["P1 B"] = input[1].pressed
  buttons["P1 Down"] = input[2].pressed
  buttons["P1 Left"] = input[3].pressed
  buttons["P1 Right"] = input[4].pressed
  buttons["P1 Up"] = input[5].pressed
  
  buttons["P1 Select"] = false
  buttons["P1 Start"] = false
  
  joypad.set(buttons)
end

function getRandomSpecie() 
  local specie = {}
  local blocks = {}
  specie.buttons = {}
  specie.buttons.previous = {}
  
  for i = 0, 16 do
    blocks[i] = {}
    for j = 0, 13 do
      local block = {}
      block.weightA = math.random()
      block.weightB = math.random()
      blocks[i][j] = blocks
      specie.buttons.previous[math.floor(math.random(6))][#specie.buttons.previous[math.floor(math.random(6))]][0] = i;
      specie.buttons.previous[math.floor(math.random(6))][#specie.buttons.previous[math.floor(math.random(6))]][1] = j;
    end
  end
  
  specie.blocks = blocks
  return specie
end

  
local specie = getRandomSpecie()
  
while true do
  memory.writebyte(0x075A, 2)
  memory.writebyte(0x0787, 0x02)
  getPlayerLocation()
  
  local blocks = {}
  blocks = getBlocks(blocks)
  blocks = getEnemies(blocks)
  display(blocks)
  displayJoypad(joypad.getimmediate())
  
  specie = firstLayer(specie)
  specie = secondLayer(specie)
  sendInput(specie.buttons)
  
  gui.text(0, 10, "Player Position: " .. PlayerX .. " " .. PlayerY)
  emu.frameadvance()
end
