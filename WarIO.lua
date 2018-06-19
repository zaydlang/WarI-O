-- Full Credit to MarI/O and LuigI/O for inspiration in this project.
-- This project is more of an attempt for me to learn more about AI
-- than anything else. So, I took a look at the two aforementioned
-- projects quite a bit to see how things were structured, and then 
-- tried to implement it on my own.

local BoxRadius = 4

local PlayerX
local PlayerY

function getPlayerLocation()
  PlayerX = memory.readbyte(0x071C) + 256 * memory.readbyte(0x071A)
  PlayerY = memory.readbyte(0x03B8)
end

function getBlocks()
  local blocks = {}
  
  for i = 0, 16 do
    blocks[i] = {}
    for j = 0, 13 do -- 16 * 13 = 208
      local block = {}
      -- Idk why there's a + 8 and - 16. I couldn't figure out why my
      -- code wouldn't work until I saw those in the LuigI/O code.
      local TempX = PlayerX + (i - 8) * 16
      local BlockX = math.floor((TempX % 256) / 16)
      local BlockY = math.floor((PlayerY + (j - 6) * 13 - 48) / 16) -- -16 - 32 = -48
      block.x = BlockX * 16
      block.y = BlockY * 16
      
      local BlockAddress = 0
      if ((TempX / 256) % 2 == 1) then BlockAddress = 208 end
      BlockAddress = 0x0500 + BlockAddress + BlockY * 16 + BlockX
      if (memory.readbyte(BlockAddress) ~= 0 and BlockY < 13 and BlockY >= 0) then block.value = 1 
      else block.value = 0 end
      
      blocks[i][j] = block
    end
  end
  
  return blocks
end

function displayBlocks(blocks)
  for i = 0, 16 do
    for j = 0, 13 do
      if (blocks[i][j].value == 1) then
        gui.drawBox(blocks[i][j].x - BoxRadius, blocks[i][j].y - BoxRadius + 32, blocks[i][j].x + BoxRadius, blocks[i][j].y + BoxRadius + 32)
      end
    end
  end
end

while true do
  memory.writebyte(0x075A, 2)
  getPlayerLocation()
  displayBlocks(getBlocks())
  gui.text(0, 10, "Player Position: " .. PlayerX .. " " .. PlayerY)
  emu.frameadvance()
end
