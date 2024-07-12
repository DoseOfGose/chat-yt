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

return {
	flags = flags,
	debug_print = debug_print,
	verbose_print = verbose_print,
	print_stats = print_stats,
	unescape_html_entities = unescape_html_entities,
}
