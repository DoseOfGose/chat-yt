local utils = require("src/utils")
local youtube = require("src/youtube")
local openai = require("src/openai")

local print_banner = function()
	print([[
_________ .__            __            _____.___.___________
\_   ___ \|  |__ _____ _/  |_          \__  |   |\__    ___/
/    \  \/|  |  \\__  \\   __\  ______  /   |   |  |    |
\     \___|   Y  \/ __ \|  |   /_____/  \____   |  |    |
 \______  /___|  (____  /__|            / ______|  |____|
        \/     \/     \/                \/
  ]])
end

local print_video_link_instructions = function()
	print([[

Enter "QUIT" or "Q" to exit the program. 

Please provide a YouTube video URL or video ID to get a summary by ChatGPT:
]])
end

local print_conversation_instructions = function()
	print([[

What else would you like to ask?
Enter "QUIT" or "Q" to exit the program. 
]])
	io.write("You: ")
end

local print_conversation_header = function(title, channel)
	print([[

Starting conversation with ChatGPT.

To begin, we'll summarize the video transcript into 5 bullet points.
]])
	print("Video Name: " .. title)
	print("Channel: " .. channel .. "\n\n")
end

local handle_youtube = function(video_id)
	local transcript, title, channel
	repeat
		local transcript_url
		transcript_url, title, channel = youtube.scrape_youtube_html_data(video_id)
		transcript = youtube.fetch_youtube_transcript(transcript_url)
		if transcript == "ERROR" then
			print([[
Error fetching transcript.  This could be due to a network error, and invalid video ID, or a video without a transcript.  Please try again.
      ]])
		end
	until transcript ~= "ERROR"
	return transcript, title, channel
end

local get_input = function()
	local user_input = io.read()
	if user_input == "QUIT" or user_input == "Q" then
		os.exit(0)
	end
	return user_input
end

local interactive_app_run = function()
	print_banner()
	local video_id, transcript, title, channel
	repeat
		repeat
			print_video_link_instructions()
			local user_input = get_input()
			video_id = youtube.extract_youtube_id(user_input)
			utils.debug_print("video_id: ", video_id)
		until video_id ~= nil
		transcript, title, channel = handle_youtube(video_id)
	until transcript ~= "ERROR"

	print_conversation_header(title, channel)

	local messages = openai.start_chat_with_video_summary(transcript, title)
	repeat
		print_conversation_instructions()
		local user_input = get_input()
		messages = openai.continue_conversation(messages, user_input)
	until false
end

return {
	interactive_app_run = interactive_app_run,
}
