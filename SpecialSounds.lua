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

hexchat.register(
  "SpecialSounds",
  "0.0.1",
  "Set special sound to play on message"
)

local function set_sound (server_name, channel_name, sound_file, match)
  print("Hello")
end

---[===[
-- Debugging
local function print_hook_args (...)
  local arg = {...}
  for i,val in ipairs(arg) do
    print("arg "..tostring(i))
    for subi,subval in ipairs(val) do
      print("item "..tostring(subi).." val: "..subval)
    end
  end
  return hexchat.EAT_HEXCHAT
end
--]===]

hexchat.hook_command("SSOUND", print_hook_args, [[
DESCRIPTION

Watch for message matching [match] in specific server and channel, and play sound with /SPLAY on match
/SSOUND [server name] #[channel name] sound [sound file] match [match]

If any of [server name], [channel name], [sound file], or [match] have spaces, they must be wrapped in parenthesis.
Note that the channel name will have the # on the outside of the parenthesis.

The [match] must be a Lua pattern: https://www.lua.org/pil/20.2.html

EXAMPLES

Play sound from D:\friend.wav when your friends name is mentioned:
/SSOUND freenode #irc sound D:\friend.wav match friends_nick

Show all sounds set for server freenode channel #irc:
/SSOUND freenode #irc

Set the sound file to (D:\attention attention.wav) for any channel with "help" in the name:
/SSOUND #(.*help.*) sound (D:\attention attention.wav)
Note, this will not play the sound, as no match has been specified yet:
/SSOUND #(.*help.*) match (%?)
Now it will match anything with a question mark in it.
]])