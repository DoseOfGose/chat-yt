local xml2lua = require("xml2lua")
local xml2lua_handler = require("xmlhandler.tree")
local http_request = require("http.request")
local utils = require("src/utils")

local function scrape_youtube_html_data(youtube_video_id)
	local video_url = "https://www.youtube.com/watch?v=" .. youtube_video_id
	local req = http_request.new_from_uri(video_url)
	req.headers:upsert(":method", "GET")
	utils.verbose_print("Making YouTube call for scraping transcript URL, video title, and channel name")
	local headers, stream = req:go()
	local body = stream:get_body_as_string()
	if headers:get(":status") == "200" then
		local video_title = body:match("<title>(.-)</title>"):gsub(" %- YouTube", "")
		video_title = utils.unescape_html_entities(video_title)
		local channel_name = body:match('"ownerChannelName":%w?"(.-)"')
		local transcript_url_raw = body:match('"(https://www.youtube.com/api/timedtext%?.-)"')
		local transcript_url
		if transcript_url_raw then
			transcript_url = transcript_url_raw:gsub("\\u0026", "&")
		end
		return transcript_url, video_title, channel_name
	else
		print("Request failed")
		print(headers:get(":status"))
		print(headers:get(":status-text"))
		print(body)
	end

	-- TODO: error handling and language checking, also would like to check if transcript is generated
end

local function fetch_youtube_transcript(transcript_url)
	local req = http_request.new_from_uri(transcript_url)
	req.headers:upsert(":method", "GET")
	utils.verbose_print("Making YT call for transcript")
	local headers, stream = req:go()
	local body = stream:get_body_as_string()
	local transcript_text = {}
	if headers:get(":status") == "200" then
		local parser = xml2lua.parser(xml2lua_handler)
		parser:parse(body)
		for k, v in pairs(xml2lua_handler.root.transcript.text) do
			table.insert(transcript_text, utils.unescape_html_entities(v[1]))
		end
		return table.concat(transcript_text, " ")
	else
		print("Request failed")
		print(headers:get(":status"))
		print(headers:get(":status-text"))
		print(body)
		return "ERROR"
	end
	-- TODO: error handling
end

local function get_youtube_transcript(youtube_video_id)
	local transcript_url, video_title, channel_name = scrape_youtube_html_data(youtube_video_id)
	if transcript_url == nil then
		print("Unable to find transcription URL for video: " .. video_title)
		print("Please try a different video that has a transcription")
		return "ERROR"
	end
	video_title = utils.unescape_html_entities(video_title)
	print("Getting Transcript for: " .. video_title)
	if channel_name ~= nil then
		print("Channel name: " .. channel_name)
	end
	local transcript = fetch_youtube_transcript(transcript_url)
	return transcript, video_title
end
local function extract_youtube_id(video)
	if video:match("youtube.com/watch") then
		return video:match("v=([%w-]+)")
	elseif video:match("youtu.be") then
		return video:match("youtu.be/([%w-]+)")
	end

	if video:match("") ~= nil then
		return video
	end

	return nil
end

return {
	scrape_youtube_html_data = scrape_youtube_html_data,
	extract_youtube_id = extract_youtube_id,
	get_youtube_transcript = get_youtube_transcript,
	fetch_youtube_transcript = fetch_youtube_transcript,
}
