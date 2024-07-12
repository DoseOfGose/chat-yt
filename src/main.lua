#! /usr/bin/env lua

local utils = require("src/utils")
local youtube = require("src/youtube")
local openai = require("src/openai")

local function converse_with_gpt(youtube_video_id, optional_model)
	local start_time = os.clock()
	local transcript, title = youtube.get_youtube_transcript(youtube_video_id)
	if transcript == "ERROR" then
		return
	end
	local transcript_end_time = os.clock()
	local chatgpt_start_time = os.clock()
	local prompt_tokens, completion_tokens, total_tokens =
		openai.make_chatgpt_request(transcript, title, optional_model)
	local chatgpt_end_time = os.clock()
	if prompt_tokens == "ERROR" then
		-- "ERROR" returns when there was an issue with API
		return
	end
	utils.print_stats({
		prompt_tokens = prompt_tokens,
		completion_tokens = completion_tokens,
		total_tokens = total_tokens,
		transcript_time = transcript_end_time - start_time,
		chatgpt_time = chatgpt_end_time - chatgpt_start_time,
		total_time = chatgpt_end_time - start_time,
	})
end

-- For initial POC version, just handle the input and trigger the app
-- Will look into better CLI experience in next iteration:
local function cli_input_handler()
	local http_vid = arg[1]
	if http_vid == nil then
		print("Please provide a YouTube video ID or URL")
		return
	end

	local youtube_video_id = youtube.extract_youtube_id(http_vid)
	if not youtube_video_id then
		return
	end

	local optional_model = arg[2]
	local valid_model = openai.check_model(optional_model)
	if not valid_model then
		print("Invalid model provided: " .. optional_model)
		return
	end

	converse_with_gpt(youtube_video_id, optional_model)
end

cli_input_handler() -- run the app
