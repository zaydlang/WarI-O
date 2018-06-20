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
      local block = {}
      local TempX = PlayerX + (i) * 16
      local BlockX = math.floor((TempX % 256) / 16)
      local BlockY = j * 16
      
      local BlockAddress = 0
      if (math.floor(TempX / 256) % 2 == 1) then BlockAddress = 208 end
      BlockAddress = 0x0500 + BlockAddress + BlockY + BlockX
      if (memory.readbyte(BlockAddress) ~= 0 and BlockY < 13 * 16 and BlockY >= 0) then block.value = 1 
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
        enemy.value = 2
        blocks[enemy.x + 1][enemy.y - 1] = enemy
      end
    end
  end
  
  blocks.enemies = enemies
  return blocks
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

while true do
  memory.writebyte(0x075A, 2)
  memory.writebyte(0x0787, 0x02)
  getPlayerLocation()
  
  local blocks = {}
  blocks = getBlocks(blocks)
  blocks = getEnemies(blocks)
  display(blocks)
  
  gui.text(0, 10, "Player Position: " .. PlayerX .. " " .. PlayerY)
  emu.frameadvance()
end
