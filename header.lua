local rock = {}

rock.version = "9"

if hexchat then
    hexchat.register(
      "SpecialSounds",
      rock.version,
      "Set special sound to play on message"
    )
end

return rock