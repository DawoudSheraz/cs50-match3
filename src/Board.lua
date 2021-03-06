--[[
    GD50
    Match-3 Remake

    -- Board Class --

    Author: Colton Ogden
    cogden@cs50.harvard.edu

    The Board is our arrangement of Tiles with which we must try to find matching
    sets of three horizontally or vertically.
]]

Board = Class{}

function Board:init(x, y, level)
    self.x = x
    self.y = y

    -- Level to determine the variety of tiles generated
    self.level = level
    self.matches = {}

    self:initializeTiles()
end

function Board:initializeTiles()
    self.tiles = {}

    for tileY = 1, 8 do
        
        -- empty table that will serve as a new row
        table.insert(self.tiles, {})

        for tileX = 1, 8 do
            
            -- Randomize the tile variety based on the level
            local tileVariety = math.random(math.min(6, math.ceil(self.level/2)))
            local isShiny = (math.random(32) == 10 and true) or false
            -- create a new tile at X,Y with a random color and variety
            table.insert(self.tiles[tileY], Tile(tileX, tileY, math.random(18), tileVariety, isShiny))
        end
    end

    while self:calculateMatches(1, 8, 1, 8) do
        
        -- recursively initialize if matches were returned so we always have
        -- a matchless board on start
        self:initializeTiles()
    end
end

--[[
    Goes left to right, top to bottom in the board, calculating matches by counting consecutive
    tiles of the same color. Doesn't need to check the last tile in every row or column if the 
    last two haven't been a match.
]]
function Board:calculateMatches(yStart, yEnd, xStart, xEnd)
    local matches = {}

    local horizontalMatches = self:horizontalMatchCalculation(yStart, yEnd)
    local verticalMatches = self:verticalMatchCalculation(xStart, xEnd)

    for k, v in pairs(horizontalMatches) do
        table.insert(matches, v)
    end

    for k, v in pairs(verticalMatches) do
        table.insert(matches, v)
    end

    -- store matches for later reference
    self.matches = matches

    -- return matches table if > 0, else just return false
    return #self.matches > 0 and self.matches or false
end

--[[
    Check if there are any matches inside the given rows and column
]]
function Board:isMatchPresent(yStart, yEnd, xStart, xEnd)

    local horizontalMatches = self:horizontalMatchCalculation(yStart, yEnd)
    local verticalMatches = self:verticalMatchCalculation(xStart, xEnd)

    return #horizontalMatches > 0 or #verticalMatches > 0
end

--[[
    Remove the matches from the Board by just setting the Tile slots within
    them to nil, then setting self.matches to nil.
]]
function Board:removeMatches()
    for k, match in pairs(self.matches) do
        for k, tile in pairs(match) do
            self.tiles[tile.gridY][tile.gridX] = nil
        end
    end

    self.matches = nil
end

--[[
    Shifts down all of the tiles that now have spaces below them, then returns a table that
    contains tweening information for these new tiles.
]]
function Board:getFallingTiles()
    -- tween table, with tiles as keys and their x and y as the to values
    local tweens = {}

    -- for each column, go up tile by tile till we hit a space
    for x = 1, 8 do
        local space = false
        local spaceY = 0

        local y = 8
        while y >= 1 do
            
            -- if our last tile was a space...
            local tile = self.tiles[y][x]
            
            if space then
                
                -- if the current tile is *not* a space, bring this down to the lowest space
                if tile then
                    
                    -- put the tile in the correct spot in the board and fix its grid positions
                    self.tiles[spaceY][x] = tile
                    tile.gridY = spaceY

                    -- set its prior position to nil
                    self.tiles[y][x] = nil

                    -- tween the Y position to 32 x its grid position
                    tweens[tile] = {
                        y = (tile.gridY - 1) * 32
                    }

                    -- set Y to spaceY so we start back from here again
                    space = false
                    y = spaceY

                    -- set this back to 0 so we know we don't have an active space
                    spaceY = 0
                end
            elseif tile == nil then
                space = true
                
                -- if we haven't assigned a space yet, set this to it
                if spaceY == 0 then
                    spaceY = y
                end
            end

            y = y - 1
        end
    end

    -- create replacement tiles at the top of the screen
    for x = 1, 8 do
        for y = 8, 1, -1 do
            local tile = self.tiles[y][x]

            -- if the tile is nil, we need to add a new one
            if not tile then

                -- new tile with random color and variety
                local tileVariety = math.random(math.min(6, math.ceil(self.level/2)))
                local isShiny = (math.random(32) == 10 and true) or false
                local tile = Tile(x, y, math.random(18), tileVariety, isShiny)
                tile.y = -32
                self.tiles[y][x] = tile

                -- create a new tween to return for this tile to fall down
                tweens[tile] = {
                    y = (tile.gridY - 1) * 32
                }
            end
        end
    end

    return tweens
end

function Board:render()
    for y = 1, #self.tiles do
        for x = 1, #self.tiles[1] do
            self.tiles[y][x]:render(self.x, self.y)
        end
    end
end

--[[
    Calculate and return the horizontal matches b/w given start and end positions
]]
function Board:horizontalMatchCalculation(startPos, endPos)
    local matches = {}

    -- how many of the same color blocks in a row we've found
    local matchNum = 1
    -- horizontal matches 
    for y = startPos, endPos do
        local colorToMatch = self.tiles[y][1].color

        -- To check if the current row has any shiny tile
        local isShinyPresent = false

        matchNum = 1
        
        -- every horizontal tile
        for x = 2, 8 do
            
            local currentTile = self.tiles[y][x]
            local counter = x
            -- if this is the same color as the one we're trying to match...
            if currentTile.color == colorToMatch then
                matchNum = matchNum + 1

                -- Set the flag to true if any shiny tile is encountered during match
                if not isShinyPresent and currentTile.shiny then
                    isShinyPresent = true
                end
            else
                -- set this as the new color we want to watch for
                colorToMatch = currentTile.color

                -- if we have a match of 3 or more up to now, add it to our matches table
                if matchNum >= 3 then
                    local match = {}
                    
                    -- If shiny tile present and matches found then
                    -- all the tiles in the rows should be cleared
                    if isShinyPresent then
                        counter = 9
                        matchNum = 8
                    end


                    -- go backwards from here by matchNum
                    for x2 = counter - 1, counter - matchNum, -1 do
                        -- add each tile to the match that's in that match
                        table.insert(match, self.tiles[y][x2])
                    end

                    -- add this match to our total matches table
                    table.insert(matches, match)

                    if isShinyPresent then
                        break
                    end
                end

                matchNum = 1
                isShinyPresent = false

                -- don't need to check last two if they won't be in a match
                if x >= 7 then
                    break
                end
            end
        end

        -- account for the last row ending with a match
        if matchNum >= 3 then
            local match = {}
            
            if isShinyPresent then
                matchNum = 8
            end

            -- go backwards from end of last row by matchNum
            for x = 8, 8 - matchNum + 1, -1 do
                table.insert(match, self.tiles[y][x])
            end

            table.insert(matches, match)
        end
    end

    return matches
end

--[[
    Calculate and return vertical matches between given start and end positions
]]
function Board:verticalMatchCalculation(startPos, endPos)

    local matches = {}

    -- how many of the same color blocks in a row we've found
    local matchNum = 1
    -- vertical matches
    for x = startPos, endPos do
        local colorToMatch = self.tiles[1][x].color
        
        local isShinyPresent = false

        matchNum = 1

        -- every vertical tile
        for y = 2, 8 do
            
            local currentTile = self.tiles[y][x]
            local counter = y

            if currentTile.color == colorToMatch then
                matchNum = matchNum + 1

                -- Set the flag to true if any shiny tile is encountered during match
                if not isShinyPresent and currentTile.shiny then
                    isShinyPresent = true
                end
            else
                colorToMatch = currentTile.color

                if matchNum >= 3 then
                    local match = {}

                    if isShinyPresent then
                        counter = 9
                        matchNum = 8
                    end

                    for y2 = counter - 1, counter - matchNum, -1 do
                        table.insert(match, self.tiles[y2][x])
                    end

                    table.insert(matches, match)
                    if isShinyPresent then
                        break
                    end
                end

                matchNum = 1
                isShinyPresent = false

                -- don't need to check last two if they won't be in a match
                if y >= 7 then
                    break
                end
            end
        end

        -- account for the last column ending with a match
        if matchNum >= 3 then
            local match = {}
            
            if isShinyPresent then
                matchNum = 8
            end
            -- go backwards from end of last row by matchNum
            for y = 8, 8 - matchNum + 1, -1 do
                table.insert(match, self.tiles[y][x])
            end

            table.insert(matches, match)
        end
    end

    return matches
end