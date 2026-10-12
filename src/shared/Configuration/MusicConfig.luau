--[[
    Module: MusicConfig
    Description: Background music playlists.

    V3 kept bare id arrays and V3's MusicService:Start() was hardcoded to the Christmas
    list — a seasonal change that was never reverted. Playlists are named and selected
    explicitly here so that cannot happen silently again.

    Track entries carry Name/Artist where known (V4's shape) so the UI can show what is
    playing; seasonal tracks came from V3 as ids only.
--]]

local MusicConfig = {}

--- Which playlist to use. Set to a key of MusicConfig.Playlists, or "Auto" to pick by
--- calendar month (October = Halloween, December = Christmas, otherwise Default).
MusicConfig.ACTIVE_PLAYLIST = "Auto"

--- Minimum group rank allowed to skip the current track.
MusicConfig.SKIP_MIN_RANK = 11

--- Seconds to wait before giving up on a track that never reports a length.
MusicConfig.TRACK_LOAD_TIMEOUT = 10

--- Fallback length when a track's TimeLength never resolves.
MusicConfig.DEFAULT_TRACK_LENGTH = 180

local function idsToTracks(ids: { string }): { { SongId: string } }
	local tracks = {}
	for _, id in ids do
		table.insert(tracks, { SongId = id })
	end
	return tracks
end

MusicConfig.Playlists = {
	Default = {
		{ SongId = "7024183256", Name = "Balance", Artist = "Martin Graff" },
		{ SongId = "5410083549", Name = "Let's Talk", Artist = "Rogue" },
		{ SongId = "5409836121", Name = "Medusa", Artist = "Aiobahn & Cozi Zuehlsdorff" },
		{ SongId = "7029005367", Name = "Hold On (feat. Q'AILA)", Artist = "Summer Was Fun" },
		{ SongId = "1841805750" },
		{ SongId = "1841922827" },
		{ SongId = "1841736343" },
		{ SongId = "1842137210" },
		{ SongId = "1841615606" },
		{ SongId = "1846384516" },
		{ SongId = "1840534623" },
		{ SongId = "9047059790" },
		{ SongId = "1837879082" },
		{ SongId = "1838597659" },
		{ SongId = "1843397729" },
		{ SongId = "1837999349" },
		{ SongId = "1845554017" },
		{ SongId = "1843404009" },
		{ SongId = "1838028467" },
		{ SongId = "5409360995" },
		{ SongId = "1837324500" },
		{ SongId = "7028856935" },
	},

	Halloween = idsToTracks({
		"1847313950",
		"1836009626",
		"1838592691",
		"1841602884",
		"1838591268",
		"1837467234",
		"1837467198",
		"1837467285",
		"1841274055",
		"1836009678",
		"1837467364",
	}),

	Christmas = idsToTracks({
		"1839945406",
		"1838667168",
		"1841342574",
		"1838667680",
		"1841238992",
		"1838667039",
		"9046740497",
		"1838667764",
		"1846627694",
		"1841446876",
		"1841545954",
		"1838776390",
		"1835649208",
		"9038476117",
		"1842092578",
		"1842092851",
		"9041725815",
		"1839286325",
		"1841240661",
		"1838666946",
		"1838776351",
		"1843918021",
	}),
}

--- Tracks that must never play, by id. Populated at runtime by moderators; entries here
--- are permanent.
MusicConfig.Blacklist = {}

--- Resolves ACTIVE_PLAYLIST to a track list.
function MusicConfig.getActivePlaylist(): { { SongId: string, Name: string?, Artist: string? } }
	local key = MusicConfig.ACTIVE_PLAYLIST

	if key == "Auto" then
		local month = tonumber(os.date("!%m"))
		if month == 10 then
			key = "Halloween"
		elseif month == 12 then
			key = "Christmas"
		else
			key = "Default"
		end
	end

	return MusicConfig.Playlists[key] or MusicConfig.Playlists.Default
end

return MusicConfig
