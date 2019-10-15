# Installation

[The releases page][releases] has a file that can be downloaded into the HexChat `config/addons/` directory.

Then, from the HexChat text entry box, the following can be entered to load the plugin:

```
/lua load SpecialSounds.lua
```

There are [more instructions on installing and using plugins and addons in the HexChat documentation][hexchat-addons].

The command to load this plugin can be given as one of the Coonect commands for a server in HexChat's Network List:

![HexChat Network List network entry connect commands][hexchat-autoload].

Because this is written in [Lua][], HexChat does not need to be installed with Python support.

# What is it?

This is a plugin for [HexChat][] that provides the `/ssound` command to configure the plugin to play specific sounds when specific messages are received.

# How is it used?

The basic way to use the command `/ssound` this plugin provides looks like this:

```
/ssound [server name] #[channel name] sound [sound file] match [pattern]
```

Where anything `[`_`between braces`_`]` can be replaced with text, braces and all, to configure the plugin.

For example:

```
/ssound fuelrats #fuelrats sound H:\signal.wav match SIGNAL
```

The plugin scans every HexChat `Channel Message`, which is [a HexChat Text Event][hexchat-text-event] that generates the messages seen as coming from other members participating in a channel.

This means that your messages, private messages, messages directly from the server, or messages outside a channel all do not get scanned.

Please [open an issue][issue] if you need any of these to play unique sounds.

If that text has spaces, it must be wrapped in parenthesis, and if the text itself has parenthesis, those parenthesis must have a `%` in front of each of them. Also note that the `#` for a `[channel name]` will be on the outside of the parenthesis (e.g. `#(channel name)`).

This is in part because `[server name]`, `[channel name]`, and `[pattern]` are all (usually) treated as [Lua patterns][lua-patterns].

This means that, a `[pattern]` of `word` will match any Channel Message with `word` in it, like `My word, that's awesome!`.

This also has a few consequences.

Lua patterns treat `%` `(` `)` `.` `[` `]` `*` `+` `-` `?` as special characters that do different things. To have Lua treat them as regular characters, put a `%` before them.

As an example, if the text to be matched was `:-) tehee (-:`, then the whole thing needs to be wrapped in parenthesis, and the parenthesis inside need to be escaped with a `%`, so we get `(:-%) tehee %(-:)`. Then, the special characters need to be escaped, including the escaping `%` we just inserted, so we get `:%-%%) tehee %%(%-:`.

This can be painful, but hopefully doesn't come up much. If it does, and you want an option to treat the text as just text, and only have to worry about spaces, `(` and `)`, [open and issue][issue].

Also, Lua patterns are case sensitive, so the `[pattern]` `(no)` will match neither `NOOOOO` nor `No, stop`, but will match `That's enough!`.

Lastly, the sound file must be able to be played with HexChat's builtin `/splay` command. See [Limitations](./README.md#Limitations).

Putting this all together, to have the plugin watch for messages containing `something's on fire!` on a server that has `fun` in the name, on a channel that has `stuff` in the name, and play the file `H:\fire engine.wav`, the following can be given.

```
/ssound fun #stuff sound (H:\fire engine.wav) match (something's on fire!)
```

If the command is typed into a channel, either the `[server name]`, the `[channel name]`, or both can be left out, and the plugin will use the context to autofill those.

This is convenient, because the plugin only sees the [hostname][] (like the URL of the specific server that's hosting the IRC channel) of the server, and not what might show up in the HexChat Network List.

To see what settings have been configured for a server and channel, leave off the `sound` and `match`:

```
/ssound [server name] #[channel name]
```

Finally, if a `[server name]` needs to be configured as `sound` or `match`, or needs to begin with a `/`, it must be wrapped in parenthesis. The following will not work:

```
/ssound match sound H:\sound.wav match word
```

But the following will:

```
/ssound (match) sound H:\sound.wav match word
```

# Limitations

## Sound file isn't validated

The sound file isn't checked to make sure it's a file HexChat understands. If HexChat doesn't understand it, nothing happens; no error, no sound.

Test the sound file with HexChat's built in `/splay` command first to make sure HexChat can use it. `/help splay` describes how to use the command.

## HexChat Alerts may conflict

HexChat can highlight words (by default, your name), and can also emit the Text Even named Beep. These settings are under `Settings -> Preferences` and then `Chatting -> Alerts`, as shown in this screen shot:

![HexChat preferences for Chatting -> Alerts][hexchat-alerts]

If Beep or Channel Message are configured with a sound, and this plugin matches a message that HexChat also matches, generally only one sound will play, usually the one configured by HexChat, but sometimes one will cut another off.

For best results, there should be no conflicts between the events HexChat has been configured to Beep on, and the messages this plugin is configured to match on.

## Possible bugs in this plugin

If I've mistyped something writing this plugin, it can:

 - Crash HexChat
 - Freeze HexChat
 - Print out a Lua syntax error on every message received

It cannot:

 - Send messages as you
 - Configure the rest of HexChat

# Motivation

I had a problem.

I wanted a project.

It was created mainly for [The Fuel Rats][tfr], but can certainly be used for anything.


[releases]: <https://github.com/2ndBillingCycle/specialsounds/releases/latest>
[hexchat-addons]: <https://hexchat.readthedocs.io/en/latest/addons.html>
[hexchat-autoload]: <https://i.imgur.com/sD1CvOw.png>
[lua]: <https://www.lua.org/about.html>
[hexchat]: <https://hexchat.github.io/>
[hexchat-text-event]: <https://hexchat.readthedocs.io/en/latest/appearance.html#text-events>
[issue]: <https://github.com/2ndBillingCycle/specialsounds/issues/new>
[lua-patterns]: <https://i.imgur.com/NgLpUBR.png>
[hostname]: <https://en.wikipedia.org/wiki/Hostname>
[hexchat-alerts]: <https://i.imgur.com/NgLpUBR.png>
[tfr]: <https://fuelrats.com/>