--[[
    GD50
    Match-3 Remake

    -- PlayState Class --

    Author: Colton Ogden
    cogden@cs50.harvard.edu

    State in which we can actually play, moving around a grid cursor that
    can swap two tiles; when two tiles make a legal swap (a swap that results
    in a valid match), perform the swap and destroy all matched tiles, adding
    their values to the player's point score. The player can continue playing
    until they exceed the number of points needed to get to the next level
    or until the time runs out, at which point they are brought back to the
    main menu or the score entry menu if they made the top 10.
]]

PlayState = Class{__includes = BaseState}

function PlayState:init()
    
    -- start our transition alpha at full, so we fade in
    self.transitionAlpha = 255

    -- position in the grid which we're highlighting
    self.boardHighlightX = 0
    self.boardHighlightY = 0

    -- timer used to switch the highlight rect's color
    self.rectHighlighted = false

    -- flag to show whether we're able to process input (not swapping or clearing)
    self.canInput = true

    -- tile we're currently highlighting (preparing to swap)
    self.highlightedTile = nil

    self.score = 0
    self.timer = 60

    -- Boolean to check if the board should verified for any potential match
    self.shouldVerifyBoard = true

    -- Board Reset message position
    self.boardResetMessageY = -90

    -- set our Timer class to turn cursor highlight on and off
    Timer.every(0.5, function()
        self.rectHighlighted = not self.rectHighlighted
    end)

    -- subtract 1 from timer every second
    Timer.every(1, function()
        self.timer = self.timer - 1

        -- play warning sound on timer if we get low
        if self.timer <= 5 then
            gSounds['clock']:play()
        end
    end)
end

function PlayState:enter(params)
    
    -- grab level # from the params we're passed
    self.level = params.level

    -- spawn a board and place it toward the right
    self.board = params.board or Board(VIRTUAL_WIDTH - 272, 16)

    -- grab score from params if it was passed
    self.score = params.score or 0

    -- score we have to reach to get to the next level
    self.scoreGoal = self.level * 1.25 * 1000
end

function PlayState:update(dt)
    if love.keyboard.wasPressed('escape') then
        love.event.quit()
    end

    -- go back to start if time runs out
    if self.timer <= 0 then
        
        -- clear timers from prior PlayStates
        Timer.clear()
        
        gSounds['game-over']:play()

        gStateMachine:change('game-over', {
            score = self.score
        })
    end

    -- go to next level if we surpass score goal
    if self.score >= self.scoreGoal then
        
        -- clear timers from prior PlayStates
        -- always clear before you change state, else next state's timers
        -- will also clear!
        Timer.clear()

        gSounds['next-level']:play()

        -- change to begin game state with new level (incremented)
        gStateMachine:change('begin-game', {
            level = self.level + 1,
            score = self.score
        })
    end

    if self.shouldVerifyBoard then
        self.shouldVerifyBoard = false
        local boardValid = self:validateBoard()
        print("Board Valid : " .. tostring(boardValid))

        -- If no more potential matches, stop the user input
        -- and display the reset message. After reset message,
        -- generate tiles and enable user input
        if not boardValid then
            self.canInput = false
            Timer.tween(
                1.0, {
                    [self] = {boardResetMessageY = VIRTUAL_HEIGHT / 2 - 8}
                }
            )
            :finish(function ()
                Timer.tween(1.0, {
                    [self] = {boardResetMessageY = -90}
                }):finish(function ()
                    self.board:initializeTiles()
                    self.shouldVerifyBoard = true
                    self.canInput = true
                    -- Add 2 seconds timer that was wasted during tween
                    self.timer = self.timer + 2
                end)
            end)
            
        end
    end

    if self.canInput then

        mouseX, mouseY = getMouse()
        if self:mouseInBound(mouseX, mouseY) then

            -- Make mouse positions relative to board x and y so that
            -- outline coordinates are calculated correctly
            mouseY = mouseY - self.board.y
            mouseX = mouseX - self.board.x
            self.boardHighlightX, self.boardHighlightY = (math.floor(mouseX / 32) % 8) ,math.floor((mouseY / 32) % 8)
        end
        
        -- move cursor around based on bounds of grid, playing sounds
        if love.keyboard.wasPressed('up') then
            self.boardHighlightY = math.max(0, self.boardHighlightY - 1)
            gSounds['select']:play()
        elseif love.keyboard.wasPressed('down') then
            self.boardHighlightY = math.min(7, self.boardHighlightY + 1)
            gSounds['select']:play()
        elseif love.keyboard.wasPressed('left') then
            self.boardHighlightX = math.max(0, self.boardHighlightX - 1)
            gSounds['select']:play()
        elseif love.keyboard.wasPressed('right') then
            self.boardHighlightX = math.min(7, self.boardHighlightX + 1)
            gSounds['select']:play()
        end
        
        -- if we've pressed enter, to select or deselect a tile...
        if love.keyboard.wasPressed('enter') or love.keyboard.wasPressed('return') or self:validMousePress() then
            
            -- if same tile as currently highlighted, deselect
            local x = self.boardHighlightX + 1
            local y = self.boardHighlightY + 1
            
            -- if nothing is highlighted, highlight current tile
            if not self.highlightedTile then
                self.highlightedTile = self.board.tiles[y][x]

            -- if we select the position already highlighted, remove highlight
            elseif self.highlightedTile == self.board.tiles[y][x] then
                self.highlightedTile = nil

            -- if the difference between X and Y combined of this highlighted tile
            -- vs the previous is not equal to 1, also remove highlight
            elseif math.abs(self.highlightedTile.gridX - x) + math.abs(self.highlightedTile.gridY - y) > 1 then
                gSounds['error']:play()
                self.highlightedTile = nil
            else
                -- Swap tiles function which returns the tween timer
                local currentTile = self.board.tiles[y][x]
                self:swapTiles(self.highlightedTile, currentTile)
                :finish(function()
                    self.shouldVerifyBoard = true
                    local highlightedTile = self.highlightedTile
                    
                    local xStart, xEnd, yStart, yEnd = 1, 8, 1, 8

                    local xSwap = math.abs(currentTile.gridX - highlightedTile.gridX) == 1
                    local ySwap = math.abs(currentTile.gridY - highlightedTile.gridY) == 1
                    
                    if xSwap then
                        -- for X swap, check only the row and the 2 columns where the swap has take
                        yStart = currentTile.gridY
                        yEnd = yStart
                        xStart = math.min(currentTile.gridX, highlightedTile.gridX)
                        xEnd = math.max(currentTile.gridX, highlightedTile.gridX)
                        
                    elseif ySwap then
                        -- for y swap, check the only column and the 2 rows where the swap has taken place
                        xStart = currentTile.gridX
                        xEnd = xStart
                        yStart = math.min(currentTile.gridY, highlightedTile.gridY)
                        yEnd = math.max(currentTile.gridY, highlightedTile.gridY)
                    end

                    -- If not matches, revert the previous swap
                    if not self:calculateMatches(yStart, yEnd, xStart, xEnd) then
                        self.shouldVerifyBoard = false
                        self:swapTiles(currentTile, highlightedTile)
                    end
                end)
            end
        end
    end

    Timer.update(dt)
end

--[[
    Calculates whether any matches were found on the board and tweens the needed
    tiles to their new destinations if so. Also removes tiles from the board that
    have matched and replaces them with new randomized tiles, deferring most of this
    to the Board class.
]]
function PlayState:calculateMatches(xStart, xEnd, yStart, yEnd)
    self.highlightedTile = nil

    -- if we have any matches, remove them and tween the falling blocks that result
    local matches = self.board:calculateMatches(xStart, xEnd, yStart, yEnd)
    
    if matches then
        gSounds['match']:stop()
        gSounds['match']:play()

        -- add score for each match
        -- Update timer based on number of matches
        for k, match in pairs(matches) do
            self.timer = self.timer + #match
            
            -- Calculate score based on the tile variety
            for j, tile in pairs(match) do
                self.score = self.score + (tile.variety * 100)
            end
        end

        -- remove any tiles that matched from the board, making empty spaces
        self.board:removeMatches()

        -- gets a table with tween values for tiles that should now fall
        local tilesToFall = self.board:getFallingTiles()

        -- tween new tiles that spawn from the ceiling over 0.25s to fill in
        -- the new upper gaps that exist
        Timer.tween(0.25, tilesToFall):finish(function()
            
            -- recursively call function in case new matches have been created
            -- as a result of falling blocks once new blocks have finished falling
            self:calculateMatches(1, 8, 1, 8)
        end)
    
    -- if no matches, we can continue playing
    else
        self.canInput = true
        return false
    end
    return true
end


--[[
    Helper function to swap the tiles
]]
function PlayState:swapTiles(tile1, tile2)

    self:swapTilesWithoutTween(tile1, tile2)
    -- tween coordinates between the two so they swap
    return Timer.tween(0.1, {
        [tile1] = {x = tile2.x, y = tile2.y},
        [tile2] = {x = tile1.x, y = tile1.y}
    })
end

--[[
    Swap without tween
]]
function PlayState:swapTilesWithoutTween(tile1, tile2)
     -- swap grid positions of tiles
     local tempX = tile1.gridX
     local tempY = tile1.gridY
 
     tile1.gridX = tile2.gridX
     tile1.gridY = tile2.gridY
 
     tile2.gridX = tempX
     tile2.gridY = tempY
 
     -- swap tiles in the tiles table
     self.board.tiles[tile1.gridY][tile1.gridX] = tile1
     self.board.tiles[tile2.gridY][tile2.gridX] = tile2
end

function PlayState:render()
    -- render board of tiles
    self.board:render()

    -- render highlighted tile if it exists
    if self.highlightedTile then
        
        -- multiply so drawing white rect makes it brighter
        love.graphics.setBlendMode('add')

        love.graphics.setColor(255, 255, 255, 96)
        love.graphics.rectangle('fill', (self.highlightedTile.gridX - 1) * 32 + (VIRTUAL_WIDTH - 272),
            (self.highlightedTile.gridY - 1) * 32 + 16, 32, 32, 4)

        -- back to alpha
        love.graphics.setBlendMode('alpha')
    end

    -- render highlight rect color based on timer
    if self.rectHighlighted then
        love.graphics.setColor(217, 87, 99, 255)
    else
        love.graphics.setColor(172, 50, 50, 255)
    end

    -- draw actual cursor rect
    love.graphics.setLineWidth(4)
    love.graphics.rectangle('line', self.boardHighlightX * 32 + (VIRTUAL_WIDTH - 272),
        self.boardHighlightY * 32 + 16, 32, 32, 4)

    -- GUI text
    love.graphics.setColor(56, 56, 56, 234)
    love.graphics.rectangle('fill', 16, 16, 186, 116, 4)

    love.graphics.setColor(99, 155, 255, 255)
    love.graphics.setFont(gFonts['medium'])
    love.graphics.printf('Level: ' .. tostring(self.level), 20, 24, 182, 'center')
    love.graphics.printf('Score: ' .. tostring(self.score), 20, 52, 182, 'center')
    love.graphics.printf('Goal : ' .. tostring(self.scoreGoal), 20, 80, 182, 'center')
    love.graphics.printf('Timer: ' .. tostring(self.timer), 20, 108, 182, 'center')

    self:boardResetMessageRender()
end

--[[
    Check if the board has any potential matches or not
]]
function PlayState:validateBoard()

    local match = self:horizontalVerification(false)
    if not match then
        match = self:horizontalVerification(true)
    end
    if not match then
        match = self:verticalVerification(false)
    end
    if not match then
        match = self:verticalVerification(true)
    end
    return match
end


function PlayState:horizontalVerification(reverseCheck)

    local anyMatchPresent = false

    local xStart = 2
    local xEnd = 8
    local step = 1

    if reverseCheck then
        xStart = 7
        xEnd = 1
        step = -1
    end

    -- top down horizontal match first
    for y = 1, 8 do

        -- if a single match has been found, no need to check further
        if anyMatchPresent then
            break
        end

        for x = xStart, xEnd, step do

            local prevTile = self.board.tiles[y][x-step]
            local currentTile = self.board.tiles[y][x]

            self:swapTilesWithoutTween(prevTile, currentTile)

            if self.board:isMatchPresent(
                currentTile.gridY,
                currentTile.gridY,
                math.min(currentTile.gridX, prevTile.gridX),
                math.max(currentTile.gridX, prevTile.gridX)
            ) then
                print("Horizontal Match at " .. currentTile.gridY .. " " .. currentTile.gridX)
                anyMatchPresent = true
                -- Mark board verify flag to false as board is valid
                self.shouldVerifyBoard = false
                -- reverse the swap
                self:swapTilesWithoutTween(prevTile, currentTile)
                break;
            else
                self:swapTilesWithoutTween(prevTile, currentTile)
            end
        end
    end

    return anyMatchPresent
end

--[[
    Check if the match exist in vertical swaps
]]
function PlayState:verticalVerification(reverseCheck)

    local anyMatchPresent = false

    local yStart = 2
    local yEnd = 8
    local step = 1

    if reverseCheck then
        yStart = 7
        yStart = 1
        step = -1
    end

    -- top down horizontal match first
    for x = 1, 8 do

        -- if a single match has been found, no need to check further
        if anyMatchPresent then
            break
        end

        for y = yStart, yEnd, step do

            local prevTile = self.board.tiles[y-step][x]
            local currentTile = self.board.tiles[y][x]

            self:swapTilesWithoutTween(prevTile, currentTile)

            if self.board:isMatchPresent(
                math.min(currentTile.gridY, prevTile.gridY),
                math.max(currentTile.gridY, prevTile.gridY),
                currentTile.gridX,
                currentTile.gridX
            ) then
                print("Vertical Match at " .. currentTile.gridY .. " " .. currentTile.gridX)
                anyMatchPresent = true
                -- Mark board verify flag to false as board is valid
                self.shouldVerifyBoard = false
                -- reverse the swap
                self:swapTilesWithoutTween(prevTile, currentTile)
                break;
            else
                self:swapTilesWithoutTween(prevTile, currentTile)
            end
        end
    end

    return anyMatchPresent
end

--[[
    Render the message indicating board reset
]]
function PlayState:boardResetMessageRender()

    love.graphics.setColor(255, 0, 0, 200)
    love.graphics.rectangle('fill', 0, self.boardResetMessageY - 8, VIRTUAL_WIDTH, 40)
    love.graphics.setColor(255, 255, 255, 255)
    love.graphics.setFont(gFonts['medium'])
    love.graphics.printf('No Match Found. Resetting Board ', 0, self.boardResetMessageY, VIRTUAL_WIDTH, 'center')
end

--[[
    Check if mouse position is in bounds of game and the board
]]
function PlayState:mouseInBound(mouseX, mouseY)
    local inBound = true

    if mouseX == nil or mouseY == nil then
        inBound = false
    end

    -- Board Height check
    if 16 > mouseY or mouseY > 272 then
        inBound = false
    end

    -- Board Width check
    if (VIRTUAL_WIDTH - 274) > mouseX or mouseX > 494 then
        inBound = false
    end

    return inBound
end

--[[
    Check if mouse primary was clicked
]]
function PlayState:validMousePress()
    return self:mouseInBound(getMouse()) and love.mouse.wasClicked(1)
end
