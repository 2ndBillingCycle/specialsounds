# Testing

All of these should `/parse`, and should not need the `/<action>`. Run all through and in order, they should delete all the settings they add

- /SSOUND /add server #channel sound H:\sound.wav match (matc%(h pattern)
- /SSOUND /add server #channel sound H:\sound.wav
- /SSOUND /add server #channel match pattern
- /SSOUND /add server match pattern
- /SSOUND /add server sound sound
- /SSOUND /add #channel match word
- /SSOUND /add #channel sound sound.wav
- /SSOUND /add match (pitter patter)
- /SSOUND /add sound rain.wav
- /SSOUND /add (match) match match sound sound
- /SSOUND /show server #channel
- /SSOUND /show server
- /SSOUND /show #channel
- /SSOUND /show (match)
- /SSOUND /show 
- /SSOUND /delete server #channel 2
- /SSOUND /delete server #channel 1
- /SSOUND /delete server 1
- /SSOUND /delete #channel 1
- /SSOUND /delete (match) 1
- /SSOUND /delete 1
