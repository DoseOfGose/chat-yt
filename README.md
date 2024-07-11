```text
_________ .__            __            _____.___.___________
\_   ___ \|  |__ _____ _/  |_          \__  |   |\__    ___/
/    \  \/|  |  \\__  \\   __\  ______  /   |   |  |    |
\     \___|   Y  \/ __ \|  |   /_____/  \____   |  |    |
 \______  /___|  (____  /__|            / ______|  |____|
        \/     \/     \/                \/
         a youtube+chatgpt "conversation" tool by doseofgose
```

![](https://github.com/DoseOfGose/gpt-yt-lua-cli/blob/main/media/chat-yt-example.gif)

# Chat-YT

`chat-yt` is a command line tool written in Lua that lets you specify a YouTube video and a ChatGPT model to have a "conversation" with the video's chat. The tool uses the YouTube API to fetch the chat messages and the OpenAI API to generate responses. The tool is designed to be a fun and interactive way to explore the capabilities of the ChatGPT model, and to "converse" with a YouTube video's content before dedicating the time to watching the video.

To use, simply [follow the installation steps](#install) and run it in your shell.

## Active Development

Note: This is an early proof of concept and still needs plenty of TLC to be anything resembling a functional tool!

## Usage

```bash
lua src/main.lua <youtube-video-url>|<youtube-video-id>
```

## Features

## Dependencies

Lua (TODO: Version and link)
Luarocks (TODO: Link)

TODO: Add other dependencies

## Install

**Install from source:**

1. Install dependencies. See [Dependencies](#dependencies) for details.
2. Clone this repo to your local file system:

```bash
git clone <URL here>
cd <repo-name>
```

3. Install project dependencies:

TODO: Finish adding steps

## TODO Items / Wishlist

Lots of wishlist items and pending work left before this can be considered "complete":

1. Finish writing the README 😅
2. Update the rockspec file with dependencies
3. Investigate why HTTP 2 is unreliable, but HTTP 1 works consistently (Possibly look into other libraries that support chunk responses?)
4. Cleanup functions, logic and reorganize code into logical files
5. Add more robust error handling and logging
6. Introduce CLI tool for more interactive use cases
7. Options/flags for: model selection, debug mode, toggle stats, verbose/quiet mode (e.g. to pipe results or reduce noise)
8. Add continuous conversation mode for additional back-and-forth (while still preserving simple CLI command)
