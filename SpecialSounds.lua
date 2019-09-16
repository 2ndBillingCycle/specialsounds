--[[
    Goal: Provide a new command, /SSOUND, that:
     - Remembers an association of a sound file with a server+channel
     - Remembers a Lua pattern associated with a server+channel
     - Plays the sound file when a message is received that matches that regexp

    API examples:
    /SSOUND freenode #irc sound C:\Users\Public\Music\my_friend.wav
    > Server freenode channel #irc
    > Sound: C:\Users\Public\Music\my_friend.wav
    > Match: ()
    /SSOUND freenode #irc match friends_nick
    > Server freenode channel #irc
    > Sound: C:\Users\Public\Music\my_friend.wav
    > Match: friends_nick
    /SSOUND freenode sound C:\Users\Public\Music\slam_dunk.wav match (got dunked on)
    > Server freenode channel #(.*)
    > Sound: C:\Users\Public\Music\slam_dunk.wav
    > Match: (got dunked on)
    /SSOUND (.*node.*) #(irc%-.+) sound H:\crickets.wav match (very strange)
    > Server (.*node.*) channel #(irc%-.+)
    > Sound: H:\crickets.wav
    > Match: (very strange)
        /SSOUND freenode
    > Server freenode channel #irc
    > Sound: C:\Users\Public\Music\my_friend.wav
    > Match: friends_nick
    > Server freenode channel #(.*)
    > Sound: C:\Users\Public\Music\slam_dunk.wav
    > Match: (got dunked on)
    /SSOUND freenod
    > No settings found for server "freenod"
    /SSOUND (.*.*)
    > No settings found for server "(.*.*)"
    /SSOUND (.*)
    > Server freenode channel #irc
    > Sound: C:\Users\Public\Music\my_friend.wav
    > Match: friends_nick
    > Server freenode channel #(.*)
    > Sound: C:\Users\Public\Music\slam_dunk.wav
    > Match: (got dunked on)
    > Server (.*node.*) channel #(irc%-.+)
    > Sound: H:\crickets.wav
    > Match: (very strange)
    /SSOUND sound H:\rand.wav match (.*)
    > Server (.*) channel #(.*)
    > Sound: H:\rand.wav
    > Match: (.*)
    /SSOUND match ()

    This is starting to look like I'm forcing myself into writing a parser
    I think a greatly simplified parser is in order, but one without such a broad grammar.
    Solution is error messages:
    /SSOUND #(irc%-.+) sound H:\crickets.wav match (very strange)
    > Error: No server name
    /SSOUND #(irc%-.+) sound H:\crickets.wav match (very strange)
    > Error: No channel name

    Format something like:
     - All of server name, channel name, and match are all Lua patterns, and if they only
       have [a-zA-Z_] they don't have to be wrapped in parenthesis
     - Channel names are prefaced by a #
     - The name is taken literally, and can be a pattern, but the pattern will be treated
       as a literal string for the purpose of comparing against other names
     - Actions are sound and match
     - sound must be wrapped in parenthesis if the file name has spaces
     - Each command is either setting or getting
     - Set commands need a server followed by a channel and then one or both actions, 
    /SSOUND (server name) #(channel name) sound (sound file) match (Lua pattern)
     - I don't yet know how we would deal with things like
    /SSOUND #(channel name) (server name) match sound
    /SSOUND match #sound sound sound wav
     - I'm imagining the parser breaking things up into
       {server name} {channel name} {sound file} {match}
       and just passing those to a simpler function that does the things
     - get commands can have one or both of server name and channel name

    Then, another function does the message matching by hooking to a server [and channel],
    and matches on message content, then issues the SPLAY command with file name to HexChat.

    I think the fancy parsing should be left to last.
--]]