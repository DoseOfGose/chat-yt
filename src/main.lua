#! /usr/bin/env lua

local http_request = require("http.request")
local cjson = require("cjson")
-- keep set of personal env vars in ~/.lua-env, change this for other locations:
require("dotenv").config(os.getenv("HOME") .. "/.lua-env")
local xml2lua = require("xml2lua")
local xml2lua_handler = require("xmlhandler.tree")

local flags = {
	debug = false,
	verbose = false,
	stats = true,
}
local debug_print = function(...)
	if flags.debug then
		print(...)
	end
end

local verbose_print = function(...)
	-- currently unused function, need to setup use
	if flags.verbose or flags.debug then
		print(...)
	end
end

-- TODO: improve prompt, consider additional use cases/prompts
local system_prompts = {
	default = [[
You are a helpful assistant that can provide insights, information, and context based on a video transcript.  When the user asks questions about a "video" you should refer to the transcript.
When asked to summarize a video, you should provide your answer in 5 bullet points.
]],
}

local function make_chatgpt_request(transcript, video_title, optional_model, optional_conversation)
	optional_model = optional_model or "gpt-3.5-turbo" -- consider default as "gpt-4o"
	optional_conversation = optional_conversation or {}

	local url = "https://api.openai.com/v1/chat/completions"
	local req = http_request.new_from_uri(url)

	--[[
  -- For unknown reason, when using HTTP/2 the request is not working when
  -- using a larger transcript/payload. As a workaround, setting the version
  -- to 1 bypasses this limitation and allows arbitrarily large payloads.
  --]]
	req.version = 1

	req.headers:upsert(":method", "POST")
	req.headers:upsert("content-type", "application/json")
	local token = os.env.OPENAI_API_KEY
	req.headers:upsert("authorization", "Bearer " .. token)

	local user_prompt = "Summarize this transcript into 5 bullet points.\nVideo Title: "
		.. video_title
		.. "\nTranscript:\n"
		.. transcript
	local data = {
		model = optional_model,
		stream = true,
		stream_options = {
			include_usage = true,
		},
		messages = {
			{
				role = "system",
				content = system_prompts.default,
			},
			{
				role = "user",
				content = user_prompt,
			},
		},
	}
	req:set_body(cjson.encode(data))
	debug_print("Sending ChatGPT request...")
	print("\nChatGPT Response:\n")
	local headers, stream = assert(req:go())
	for chunk in stream:each_chunk() do
		for line in chunk:gmatch("[^\r\n]+") do
			local clean_chunk_line = line:gsub("^data: ", "")
			local ok, json = pcall(cjson.decode, clean_chunk_line)
			if ok then
				if json.choices and json.choices[1] and json.choices[1].finish_reason ~= "stop" then
					io.write(json.choices[1].delta.content)
					io.flush()
				elseif json.choices and json.choices[1] and json.choices[1].finish_reason == "stop" then
				-- final "empty" chunk before usage chunk
				else -- final chunk with usage data
					return math.floor(json.usage.prompt_tokens),
						math.floor(json.usage.completion_tokens),
						math.floor(json.usage.total_tokens)
				end
			else
				if clean_chunk_line ~= "[DONE]" then
					-- Error object returns multi-line, so first check if dealing with that:
					local error_parse_ok, error_json = pcall(cjson.decode, chunk)
					if error_parse_ok then
						if error_json.error then
							print("ERROR:")
							print("\tMessage:\t" .. error_json.error.message)
							print("\tCode:\t" .. error_json.error.code)
							print("\tType:\t" .. error_json.error.type)
							if error_json.error.param ~= nil and type(error_json.error.param) ~= "userdata" then
								print("\tParam:\t" .. error_json.error.param)
							end
							return "ERROR"
						else
							debug_print("DEBUG: REC'D UNKNOWN JSON:")
							debug_print(chunk)
						end
					else
						debug_print("REC'D BAD CHUNK (LINE): ")
						debug_print(clean_chunk_line)
					end
				end
			end
		end
	end

	if headers:get(":status") ~= "200" then
		print("Request failed")
		print(headers:get(":status"))
		print(headers:get(":status-text"))
	end
end

local function scrape_youtube_html_data(youtube_video_id)
	local video_url = "https://www.youtube.com/watch?v=" .. youtube_video_id
	local req = http_request.new_from_uri(video_url)
	req.headers:upsert(":method", "GET")
	verbose_print("Making YouTube call for scraping transcript URL, video title, and channel name")
	local headers, stream = req:go()
	local body = stream:get_body_as_string()
	if headers:get(":status") == "200" then
		local video_title = body:match("<title>(.-)</title>"):gsub(" %- YouTube", "")
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

local function unescape_html_entities(text)
	local html_entities = {
		["&#38;"] = "&",
		["&amp;"] = "&",
		["&#34;"] = '"',
		["&quot;"] = '"',
		["&#39;"] = "'",
		["&apos;"] = "'",
		["&#60;"] = "<",
		["&lt;"] = "<",
		["&#62;"] = ">",
		["&gt;"] = ">",
		["&#160;"] = " ",
		["&nbsp;"] = " ",
	}

	for k, v in pairs(html_entities) do
		text = text:gsub(k, v)
	end

	return text
end

local function get_youtube_transcript(youtube_video_id)
	local transcript_url, video_title, channel_name = scrape_youtube_html_data(youtube_video_id)
	if transcript_url == nil then
		print("Unable to find transcription URL for video: " .. video_title)
		print("Please try a different video that has a transcription")
		return "ERROR"
	end
	print("Getting Transcript for: " .. video_title)
	if channel_name ~= nil then
		print("Channel name: " .. channel_name)
	end
	local req = http_request.new_from_uri(transcript_url)
	req.headers:upsert(":method", "GET")
	verbose_print("Making YT call for transcript")
	local headers, stream = req:go()
	local body = stream:get_body_as_string()
	local transcript_text = {}
	if headers:get(":status") == "200" then
		local parser = xml2lua.parser(xml2lua_handler)
		parser:parse(body)
		for k, v in pairs(xml2lua_handler.root.transcript.text) do
			table.insert(transcript_text, unescape_html_entities(v[1]))
		end
		return table.concat(transcript_text, " "), video_title
	else
		print("Request failed")
		print(headers:get(":status"))
		print(headers:get(":status-text"))
		print(body)
		return "ERROR"
	end
	-- TODO: error handling
end

local function print_stats(stats)
	if not flags.stats then
		return
	end
	print("\n\n\nSTATS:")
	print("\tPrompt Tokens Used:\t" .. stats.prompt_tokens)
	print("\tCompletion Tokens Used:\t" .. stats.completion_tokens)
	print("\tTotal Tokens Used:\t" .. stats.total_tokens)
	print("\tTranscript Time:\t" .. stats.transcript_time .. " sec")
	print("\tChatGPT Time:\t\t" .. stats.chatgpt_time .. " sec")
	print("\tTotal Time:\t\t" .. stats.total_time .. " sec")
end

local function converse_with_gpt(youtube_video_id, optional_model)
	local start_time = os.clock()
	local transcript, title = get_youtube_transcript(youtube_video_id)
	if transcript == "ERROR" then
		return
	end
	local transcript_end_time = os.clock()
	local chatgpt_start_time = os.clock()
	local prompt_tokens, completion_tokens, total_tokens = make_chatgpt_request(transcript, title, optional_model)
	local chatgpt_end_time = os.clock()
	if prompt_tokens == "ERROR" then
		-- "ERROR" returns when there was an issue with API
		return
	end
	print_stats({
		prompt_tokens = prompt_tokens,
		completion_tokens = completion_tokens,
		total_tokens = total_tokens,
		transcript_time = transcript_end_time - start_time,
		chatgpt_time = chatgpt_end_time - chatgpt_start_time,
		total_time = chatgpt_end_time - start_time,
	})
end

local function check_model(model)
	-- model is optional, so nil is valid:
	if model == nil then
		return true
	end

	-- list of current models allowed by OpenAI API:
	local valid_models = {
		"gpt-3.5-turbo",
		"gpt-4o",
		"gpt-4-turbo",
	} -- TODO: update list and see if can create a programmatic list instead of hardcoding

	-- if model matches any of from the above list, it is valid
	for k, v in pairs(valid_models) do
		if model == v then
			return true
		end
	end

	return false
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

-- For initial POC version, just handle the input and trigger the app
-- Will look into better CLI experience in next iteration:
local function cli_input_handler()
	local http_vid = arg[1]
	if http_vid == nil then
		print("Please provide a YouTube video ID or URL")
		return
	end

	local youtube_video_id = extract_youtube_id(http_vid)
	if not youtube_video_id then
		return
	end

	local optional_model = arg[2]
	local valid_model = check_model(optional_model)
	if not valid_model then
		print("Invalid model provided: " .. optional_model)
		return
	end

	converse_with_gpt(youtube_video_id, optional_model)
end

cli_input_handler() -- run the app
