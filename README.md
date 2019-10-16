# SpecialSounds

This is a plugin for [HexChat][].

It provides an `/ssound` command to use to configure the plugin to play specific sounds when specific messages are received.

# Installation

From [the releases page][releases], download the `SpecialSounds.lua` file into the HexChat `config/addons/` directory.

Then, from the HexChat text entry box, enter the following to load the plugin:

```
/lua load SpecialSounds.lua
```

The [HexChat documentation][hexchat-addons] has more instructions on installing and using plugins and addons.

The command to load this plugin can be set as one of the `Connect commands` for a server in HexChat's `Network List`:

![HexChat Network List network entry connect commands][hexchat-autoload].

This plugin was written in [Lua][] so that it could be used with the default installation of HexChat.

# Syntax

`/ssound` has the following fields:

```
/ssound [server name] #[channel name] sound [sound file] match [pattern]
```

Where any `[`_`text between braces`_`]` can be replaced to configure the plugin.

For example:

```
/ssound fuelrats #fuelrats sound H:\signal.wav match SIGNAL
```

Configures the plugin to watch the `#fuelrats` channel on the server `fuelrats`, and will play the file `H:\signal.wav` when a message  has the word `SIGNAL` in it.

HexChat has the builtin command `/splay [file]` that plays any [WAV file][wav].

This plugin simply uses that command to play to play the specified sound file every time the `[pattern]` matches a message.

The messages are HexChat `Channel Messages`, a type of [HexChat Text Event][hexchat-text-event], and are how HexChat shows messages coming from other members participating in a channel.

This means that messages you send, private messages, messages sent directly by the server, or messages outside a channel, all will not trigger a sound.

Please [open an issue][issue] if you want any of these to play unique sounds.

To match something with spaces, it must be wrapped in parenthesis:

```
(a phrase has spaces)
```

This goes for the `[server name]` and `#[channel name]` as well, as those both are treated as patterns, too.

Note that the `#` for a `[channel name]` will be on the outside of the parenthesis:

```
#(channel name)
```

This is in part because the `[server name]`, `[channel name]`, and `[pattern]` are all (usually) treated as [Lua patterns][lua-patterns].

This means that, a `[pattern]` of `word` will match any message with `word` in it, like `Oh my word, that's awesome!`.

This also has a few consequences:

Lua patterns treat `%` `(` `)` `.` `[` `]` `*` `+` `-` `?` all as special characters that do different things. Additionally, `^` is treated as special when it's at the beginning of a `[pattern`], and `$` when it's at the end.

To have Lua treat them as regular characters, put a `%` before them.

As an example, to match the text `:-) tehee (-:`, the whole thing first needs to be wrapped in parenthesis, and the `(`, `)`, and `-` inside need to be escaped with a `%`:

```
(:%-%) tehee %(%-:)
```

This can be painful, but hopefully doesn't come up much. If it does, and you want an option to treat the text as just text, and only have to worry about spaces, `(`, and `)`, please [open an issue][issue].

Also, Lua patterns are case sensitive, so the `[pattern]` `no` will match neither `NOOOOO` nor `No, stop`, but will match `That's enough!`.

Lastly, the sound file must be able to be played with HexChat's builtin `/splay` command. See [Limitations](./README.md#Limitations).

Putting this all together, the following has the plugin watch for messages containing `something's on fire!` on a server that has `fun` in the name, on a channel that has `stuff` in the name, and every time a message matches, the file `H:\fire engine.wav` plays:

```
/ssound fun #stuff sound (H:\fire engine.wav) match (something's on fire!)
```

If the command is typed into a channel, either the `[server name]`, the `[channel name]`, or both can be left out, and the plugin will use the context to fill the missing one(s) in:

```
/ssound sound H:\rain.wav match (pitter patter)
```

This is convenient, because the plugin only sees the [hostname][] (like a URL) of the specific server that's hosting the IRC channel, and not what might show up in the HexChat Network List.

As a consequence of this feature, if a `[server name]` needs to be configured as `sound` or `match`, or if it needs to begin with a `/`, it must be wrapped in parenthesis. The following will not work:

```
/ssound match #channel sound (H:\sound wave.wav) match (hearing things)
```

But the following will:

```
/ssound (match) #channel sound (H:\sound wave.wav) match (hearing things)
```

To see what settings have been configured for a server and channel, leave off the `sound` and `match`:

```
/ssound [server name] #[channel name]
```

This will match against, and print out, any settings configured for a server and channel with names matching the patterns in `[server name]` and `[channel name]`.

To list all the settings configured, use:

```
/ssound (.*) #(.*)
```

# Limitations

## Sound file isn't validated

The sound file isn't checked to make sure it's a file HexChat understands. If HexChat doesn't understand it, and a message is matched, nothing happens; no error, no sound.

Test the sound file with HexChat's built in `/splay` command first to make sure HexChat can use it. `/help splay` describes how to use the command.

## HexChat Alerts may conflict

HexChat can highlight words (by default, your IRC nick), and can also emit the Text Event named `Beep`. These settings are under `Settings -> Preferences` and then `Chatting -> Alerts`:

![HexChat preferences for Chatting -> Alerts][hexchat-alerts]

If `Beep` or `Channel Message` are configured with a sound, and this plugin matches a message that HexChat also matches, generally only one sound will play, usually the one configured by HexChat, but sometimes one will cut another off.

For best results, there should be no conflicts between the events HexChat has been configured to `Beep` for, and the messages this plugin is configured to match.

## Possible bugs in this plugin

If I've mistyped something in this plugin, any of the following could happen:

 - HexChat crashes
 - HexChat freezes
 - A Lua syntax error prints out on every message received

Things that cannot happen:

 - Send messages as you
 - Configure the rest of HexChat

Plugins can do those things, but this plugin does not have that functionality, and so any bugs it may have can't accidentally make those things happen.

# Motivation

I had a problem.

I wanted a project.

It was created mainly for [The Fuel Rats][tfr], but can certainly be used for anything.


[releases]: <https://github.com/2ndBillingCycle/specialsounds/releases/latest>
[hexchat-addons]: <https://hexchat.readthedocs.io/en/latest/addons.html>
[hexchat-autoload]: <https://i.imgur.com/sD1CvOw.png>
[lua]: <https://www.lua.org/about.html>
[hexchat]: <https://hexchat.github.io/>
[wav]: <https://en.wikipedia.org/wiki/WAV>
[hexchat-text-event]: <https://hexchat.readthedocs.io/en/latest/appearance.html#text-events>
[issue]: <https://github.com/2ndBillingCycle/specialsounds/issues/new>
[lua-patterns]: <https://www.lua.org/pil/20.2.html>
[hostname]: <https://en.wikipedia.org/wiki/Hostname>
[hexchat-alerts]: <https://i.imgur.com/NgLpUBR.png>
[tfr]: <https://fuelrats.com/>