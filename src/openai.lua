local http_request = require("http.request")
local cjson = require("cjson")
local utils = require("src/utils")
-- keep set of personal env vars in ~/.lua-env, change this for other locations:
require("dotenv").config(os.getenv("HOME") .. "/.lua-env")

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
	utils.debug_print("Sending ChatGPT request...")
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
							utils.debug_print("DEBUG: REC'D UNKNOWN JSON:")
							utils.debug_print(chunk)
						end
					else
						utils.debug_print("REC'D BAD CHUNK (LINE): ")
						utils.debug_print(clean_chunk_line)
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

return {
	system_prompts = system_prompts,
	make_chatgpt_request = make_chatgpt_request,
	check_model = check_model,
}
