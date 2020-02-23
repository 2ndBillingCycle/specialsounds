[![CI/CD Badge](https://github.com/2ndBillingCycle/specialsounds/workflows/Building%20and%20Testing/badge.svg)](https://github.com/2ndBillingCycle/specialsounds/actions) [![CodeCov coverage badge](https://codecov.io/gh/2ndBillingCycle/specialsounds/branch/refactor/graphs/badge.svg)](https://codecov.io/gh/2ndBillingCycle/specialsounds/branch/refactor)

# SpecialSounds

This is a plugin for [HexChat][].

It provides the `/ssound` command to play unique sounds when specific messages are received.

## Requirements

The plugin is written in [Lua][]. On Windows, the normal installation of HexChat includes [Lua][].

![HexChat normal installation](https://i.imgur.com/SJ70WuY.png)

On Linux, HexChat may require a separate package to be installed (e.g. on Debian, the [`hexchat-lua`][hexchat-deb] package is required).

## Installation

From [the releases page][releases], click on the assets dropdown and download the `SpecialSounds.lua` file into the HexChat `config/addons/` directory, the location of which is described in [the HexChat documentation][hexchat-settings].

If HexChat was installed as a portable app, the `config/` directory is located in the same place HexChat is installed.

Then, from the HexChat text entry box, enter the following to load the plugin:

```
/lua load SpecialSounds.lua
```

This command is interpreted by HexChat, and will not be sent as a message, as long as `/` is the first character. Putting anything befor `/` , including a space, will send the command as a message to the current channel.

The [HexChat documentation][hexchat-addons] has more instructions on installing and using plugins and addons.

The command to load this plugin can be set as a `Connect command` for a server in HexChat's `Network List`:

![Connect Command set for an entry in Network List](https://i.imgur.com/sD1CvOw.png).

This runs the command when connecting to the server, loading the plugin.


## Setup

`/ssound` has the following fields:

```
/ssound [server name] #[channel name] sound <sound file> match <pattern>
```

Where any `[`_`text between braces`_`]` and `<`_`text between angle brackets`_`>` is to be replaced with an actual value, the `[]` indication an optional part that can be ommitted, and the `<>` indicating a required part. The `[` `]` `<` `>` are left out when entering the command.

For example:

```
/ssound fuelrats #fuelrats sound H:\signal.wav match SIGNAL
```

This configures the plugin to watch the `#fuelrats` channel on the server `fuelrats`, and will play the file `H:\signal.wav` when a message has the word `SIGNAL` in it. Note that sound files must be `.wav` on Windows. See the [details below](#sound-files).

The word `SIGNAL` can appear anywhere in any message from that channel (even in the middle of words, e.g. `My name is fkjnkSIGNALffkj` would match), and each time a message is matched, the sound file will be played.

If the `[server name]`, `#[channel name]`, `<sound file>`, or `<pattern>` have spaces, they must be wrapped in parentheses. For example:

```
(a phrase has spaces)
```

This is because the `[server name]`, `#[channel name]`, and `<pattern>` are all (usually) treated as [Lua patterns][lua-patterns], which are explained in more detail [below](#lua-patterns).

Note that the `#` for a `#[channel name]` _must_ be on the outside of the parentheses:

```
#(channel name)
```

Putting this all together, the following has the plugin watch for messages containing `something's on fire!` on a server that has `fun` in the name, on a channel that has `stuff` in the name, and every time a message matches, the file `H:\fire engine.wav` plays:

```
/ssound fun #stuff sound (H:\fire engine.wav) match (something's on fire!)
```

If the command is typed into a channel, either the `[server name]`, the `#[channel name]`, or both can be left out, and the plugin will use the context to fill the missing one(s) in:

```
/ssound sound H:\rain.wav match (pitter patter)
```

This is convenient, because the plugin only sees the [hostname][] (see [Hostnames](./README.md#Hostnames) for more information) of the specific server that's hosting the IRC channel, and not what might show up in the HexChat Network List.

As a consequence of this feature, if a `[server name]` has the words `sound` or `match` in it, or if it needs to begin with a `/`, it must be wrapped in parentheses. The following will not work:

```
/ssound match #channel sound (H:\rustling noise.wav) match (hearing things)
```

And the following error message will result:

```
Parser error: Unexpected text
/SSOUND match #channel sound (H:\rustling noise.wav) match (hearing things)
               ^

Sorry, could not understand command
```

But the following will work:

```
/ssound (match) #channel sound (H:\rustling noise.wav) match (hearing things)
```

```
Server:  (match)
Channel: #channel
Sound:   (H:\rustling noise.wav)
Match:   (hearing things)
```

To see what settings have been configured for a server and channel, put just the `[server name]` and `#[channel name]`:

```
/ssound [server name] #[channel name]
```

When searching, the `[server name]` and `#[channel name]` patterns will match against all names the plugin is configured for.

This can be used to list all the settings configured for every server and channel:

```
/ssound (.*) #(.*)
```

Alternatively, the auto-filling feature can be used to list all the `sound` and `match` pairs configured for the current server and channel:

```
/ssound
```

Matching settings are printed out in groups, with one `sound` and `match` printed per group, along with a `Number:` line.

This number can be used to delete that setting. Use the same command as for searching, and add the number at the end:

```
/ssound freenode #chat sound H:\example.wav match test
```

```
Set settings for: freenode #chat

Server:  freenode
Channel: #chat
Sound:   H:\example.wav
Match:   test
```

```
/ssound freenode #chat
```

```
Get settings for: freenode #chat

Server:  freenode
Channel: #chat
Sound:   H:\example.wav
Match:   test
Number:  1
```

```
/ssound freenode #chat 1
```

```
Deleting setting:
Server:  freenode
Channel: #chat
Sound:   H:\example.wav
Match:   test
Number:  1
```

To stop the plugin without closing HexChat, unload the plugin:

```
/lua unload SpecialSounds.lua
```

### [Lua Patterns][lua-patterns]

The use of [Lua patterns][lua-patterns] has a few consequences:

Lua patterns treat `%` `(` `)` `.` `[` `]` `*` `+` `-` `?` all as special characters that do different things. Additionally, `^` is treated as special when it's at the beginning of a `<pattern>`, and `$` when it's at the end.

To have Lua treat any of these as regular characters, put a `%` before them.

As an example, to match the text `I have a %! :-)`, it first needs to be wrapped in parentheses, and the `%`, `)`, and `-` that are part of the original text each need to be escaped with a `%`:

```
(I have a %%! :%-%))
```

This can be tedious, but hopefully doesn't come up much. If it does, and you want an option to treat the text as just text, and only have to worry about spaces, `(`, and `)`, please [open an issue][issue].

Also, Lua patterns are case sensitive, so the `<pattern>` of `no` will _not_ match `NOOOOO` or `No, stop`, but _will_ match `That's enough!`.

### Sound Files

To play the sound files, this plugin takes advantage of the built-in HexChat `/splay <soundfile>` command, triggering it with the given sound file every time a message with `<pattern>` is received.

HexChat supports [different sound file formats on different platforms](./REAMDE.md#only-wav-files-are-playable-on-windows), so test out the sound file with `/splay` before using it in a configuration, to make sure it can be played.

## Limitations

### Available Message Types

The only messages this plugin responds to are HexChat `Channel Messages` (a type of [HexChat Text Event][hexchat-text-event]) which are how HexChat shows messages coming from other members participating in a channel.

This means that the following will not trigger a sound:

* Messages sent by you
* Private messages
* Messages sent directly by the server (not other people)
* Messages outside of a channel

Please [open an issue][issue] if you want any other text events to play unique sounds.

### Only WAV Files Are Playable on Windows

HexChat officially supports Linux and Windows, and uses different mechanisms to play sound files on each platform.

On Windows, HexChat calls [`PlaySound`][PlaySound], which can process some kinds of [WAV][] files.

[Audacity][] can be used to [import audio][import-audio], and then [export the audio][export-audio] in one of the following formats understood by [`PlaySound`][PlaySound]:

* Signed 16-bit PCM
* Signed 24-bit PCM
* Signed 32-bit PCM
* 32-bit float
* μ-Law
* A-Law
* IMA ADPCM
* Microsoft ADPCM

![PlaySound acceptable file formats](https://i.imgur.com/CpN7X44.png)

[IMA ADPCM][ima-adpcm] produces the smallest file size with acceptable audio quality for speech.

On Linux, HexChat uses [libcanberra][], which can use ALSA, PulseAudio, OSS and GStreamer to play sound files. Most formats should be playable.

### Sound File Format Is Not Validated

The sound file isn't checked to make sure it's a file HexChat understands. If HexChat doesn't understand it, and a message is matched, nothing happens; no error, no sound.

Test the sound file with HexChat's built in `/splay` command first to make sure HexChat can use it. `/help splay` describes how to use the command.

### Sounds Cannot Overlap

HexChat can highlight words (by default, your IRC nick), and can also emit the Text Event named `Beep`. These settings are under `Settings -> Preferences` and then `Chatting -> Alerts`:

![HexChat preferences for Chatting -> Alerts](https://i.imgur.com/NgLpUBR.png)

If `Beep` or `Channel Message` are configured with a sound, and this plugin matches a message that HexChat also matches, generally only one sound will play, usually the one configured by HexChat, but sometimes one will cut another off.

For best results, there should be no conflicts between the events HexChat has been configured to `Beep` for, and the messages this plugin is configured to match.

Also, if a message matches multiple configured `<patterns>`s, only the first one will be played. With the following configuration:

```
/ssound sound H:\attention.wav match ATTENTION
```

```
Set settings for: irc.example.com #test

Server:  irc.example.com
Channel: #test
Sound:   H:\attention.wav
Match:   ATTENTION
```

```
/ssound sound H:\meeting.wav match meeting
```

```
Set settings for: irc.example.com #test

Server:  irc.example.com
Channel: #test
Sound:   H:\meeting.wav
Match:   meeting
```

If a `Channel message` is received that reads `ATTENTION: All staff report to Sam's office for a brief meeting`, only `H:\attention.wav` is played.

### Settings Are Not Synced Across Multiple HexChat Clients

If HexChat is started more than once, and this plugin is loaded in each instance, settings set in any HexChat window are saved, but those changes aren't picked up by the other clients.

Reload the plugin to update that window:

```
/lua reload specialsounds.lua
```

Use a different file name if this plugin was not installed to HexChat's `config/addons/` folder.

A better solution is to start HexChat once, and pop out the different channels and servers into different windows.

### Possible Bugs

If I've mistyped something in this plugin, any of the following could happen:

 - HexChat crashes
 - HexChat freezes
 - A Lua syntax error prints out on every message received

Things that cannot happen:

 - Send messages as you
 - Configure the rest of HexChat

This plugin does not have that functionality, and so any bugs it may have can't accidentally make those things happen.

## Hostnames

A server *hostname*, such as `irc.example.com`, is the name that a particular server can be reached at.
Hostnames are like the main part of a URL, for example, `https://example.com/login` includes the hostname of `example.com` as the server you want to connect to (in this case, for normal web browsing).

HexChat very rarely shows hostnames, instead preferring user-assigned labels, but the server hostname is critical to the inner workings of HexChat and this plugin.

Note that once connected to a server, it will report it's own hostname, and *that* is what HexChat uses.
For most purposes, the name you connect to and the name reported should be pretty close to identical, but they can differ.
If they do, it's the *server reported* name that is acted upon by HexChat.

As a concrete example:

Say you want to connect to `irc.example.com`.
There are actually two servers in `irc.example.com`, one is `na.irc.example.com` and the other is `eu.irc.example.com`.

Despite saying "Connect to `irc.example.com`," This plugin will report for either `na.irc.example.com` or `eu.irc.example.com`, depending on which one actually connected.
This brings up the possibility of a sound configured in one not playing in the other, which can be solved by using patterns to match the common portion (`irc.example.com`) of the server hostname, instead of matching exactly.

## Motivation

I had a problem.

I wanted a project.

It was created mainly for [The Fuel Rats][tfr], but can certainly be used for anything.


[releases]: <https://github.com/2ndBillingCycle/specialsounds/releases/latest>
[hexchat-settings]: <https://hexchat.readthedocs.io/en/latest/settings.html>
[hexchat-addons]: <https://hexchat.readthedocs.io/en/latest/addons.html>
[lua]: <https://www.lua.org/about.html>
[ima-adpcm]: <https://en.wikipedia.org/wiki/Adaptive_differential_pulse-code_modulation>
[libcanberra]: <https://salsa.debian.org/gnome-team/libcanberra>
[hexchat-deb]: <https://packages.debian.org/buster/hexchat-lua>
[audacity]: <https://www.audacityteam.org/>
[import-audio]: <https://manual.audacityteam.org/man/importing_audio.html#formats>
[export-audio]: <https://manual.audacityteam.org/man/file_export_dialog.html>
[PlaySound]: <https://docs.microsoft.com/en-us/previous-versions/dd743680(v%3Dvs.85)>
[hexchat]: <https://hexchat.github.io/>
[wav]: <https://en.wikipedia.org/wiki/WAV>
[hexchat-text-event]: <https://hexchat.readthedocs.io/en/latest/appearance.html#text-events>
[issue]: <https://github.com/2ndBillingCycle/specialsounds/issues/new>
[lua-patterns]: <https://www.lua.org/pil/20.2.html>
[hostname]: <https://en.wikipedia.org/wiki/Hostname>
[tfr]: <https://fuelrats.com/>
