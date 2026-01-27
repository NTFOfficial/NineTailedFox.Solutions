local SupportedGames = {
    [113217312262185] = "SCP%20retroBreach" -- 8773050457
}

local Start = "https://raw.githubusercontent.com/NTFOfficial/NineTailedFox.Solutions/refs/heads/main/"
local Game = SupportedGames[game.PlaceId]

if Game then
    loadstring(game:HttpGet(Start .. Game .. ".lua"))()
end
