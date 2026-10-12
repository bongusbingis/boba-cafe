--[[
    Module: MusicService
    Description: Drives the background music playlist.

    Playback runs on the existing SoundService.Music.Background Sound, which replicates,
    so the server owns "what is playing" and clients only own volume — the Music
    SoundGroup is muted per-player by the MusicEnabled setting (see SettingsConfig).
    That split means muting never desyncs a player from the playlist.

    The queue is shuffled once per cycle rather than picking randomly each time, so a
    track cannot repeat back-to-back.
--]]

---> services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

---> dependencies
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packages = ReplicatedStorage:WaitForChild("Packages")

local Knit = require(Packages.Knit)
local MusicConfig = require(Shared.Configuration.MusicConfig)
local RankUtil = require(Shared.Utility.RankUtil)

---> module declaration
local MusicService = Knit.CreateService({
    Name = "MusicService",
    Client = {
        --- Fired whenever the track changes, so the UI can show what is playing.
        NowPlaying = Knit.CreateSignal(),
    },
})

---> state

local currentTrack: { SongId: string, Name: string?, Artist: string? }? = nil
local queue: { { SongId: string } } = {}
local skipRequested = false
local blacklisted: { [string]: boolean } = {}

for _, id in MusicConfig.Blacklist do
    blacklisted[id] = true
end

---> private

local function getSound(): Sound?
    local musicGroup = SoundService:FindFirstChild("Music")
    local sound = musicGroup and musicGroup:FindFirstChild("Background")

    if sound and sound:IsA("Sound") then
        return sound
    end

    return nil
end

--- Fisher-Yates. Shuffling the whole playlist per cycle avoids the immediate repeats
--- that random-per-track selection produces.
local function refillQueue()
    queue = table.clone(MusicConfig.getActivePlaylist())

    for i = #queue, 2, -1 do
        local j = math.random(1, i)
        queue[i], queue[j] = queue[j], queue[i]
    end
end

local function nextTrack()
    if #queue == 0 then
        refillQueue()
    end

    while #queue > 0 do
        local track = table.remove(queue, 1)
        if track and not blacklisted[track.SongId] then
            return track
        end
    end

    return nil
end

--- Plays a track and waits out its duration, returning early if skipped.
function MusicService:_playTrack(track)
    local sound = getSound()
    if not sound then
        return
    end

    currentTrack = track
    skipRequested = false

    sound.SoundId = `rbxassetid://{track.SongId}`
    sound.Looped = false
    sound:Play()

    self.Client.NowPlaying:FireAll({
        SongId = track.SongId,
        Name = track.Name,
        Artist = track.Artist,
    })

    -- TimeLength is 0 until the asset loads, and stays 0 for ids that fail to load.
    local waited = 0
    while sound.TimeLength == 0 and waited < MusicConfig.TRACK_LOAD_TIMEOUT do
        task.wait(0.25)
        waited += 0.25

        if skipRequested then
            return
        end
    end

    local length = if sound.TimeLength > 0 then sound.TimeLength else MusicConfig.DEFAULT_TRACK_LENGTH

    local elapsed = 0
    while elapsed < length do
        task.wait(0.5)
        elapsed += 0.5

        if skipRequested then
            return
        end
    end
end

---> public

--- The track currently playing, or nil before playback starts.
function MusicService:GetCurrentTrack()
    return currentTrack
end

--- Skips the current track. Returns false when the caller lacks the rank.
function MusicService:Skip(player: Player?): boolean
    if player and RankUtil:GetRankAsync(player) < MusicConfig.SKIP_MIN_RANK then
        return false
    end

    skipRequested = true
    return true
end

--- Prevents a track from playing again this session.
function MusicService:Blacklist(songId: string)
    blacklisted[tostring(songId)] = true

    if currentTrack and currentTrack.SongId == tostring(songId) then
        skipRequested = true
    end
end

---> client

function MusicService.Client:GetCurrentTrack()
    return self.Server:GetCurrentTrack()
end

function MusicService.Client:Skip(player: Player): boolean
    return self.Server:Skip(player)
end

---> lifecycle

function MusicService:KnitStart()
    if not getSound() then
        warn("[MusicService] No SoundService.Music.Background sound — music disabled.")
        return
    end

    task.spawn(function()
        while true do
            local track = nextTrack()

            if not track then
                -- Empty or fully blacklisted playlist; wait rather than spinning.
                task.wait(5)
                continue
            end

            self:_playTrack(track)
            task.wait(0.5)
        end
    end)
end

return MusicService
