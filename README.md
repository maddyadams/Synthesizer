# Synthesizer
As a computer scientist, hobbyist composer, and avid video game fan, video game music is this very fulfilling intersection of music and technology. Unfortunately, most of the existing tools I have for working with music are geared towards "traditional" music, leaving little room for experimenting with the timbre or waveforms of instruments. 

While still a work in progress, this project allows me to write music in a (somewhat unwieldy) text-based format and then create custom instruments by combining sine, square, triangle, and sawtooth waves. I can also apply traditional effects like changing dynamics and tempo (and even changing the tuning system if desired), as well as more "electronic" effects like an echo or an ADSR envelope to adjust the attack and release of notes. 

[Audio file example](https://www.dropbox.com/s/wc0lg6fki7zv4tw/song1.wav?dl=0)

First, change the file path in main.swift. Then, when you run the project, it should render a song and write it to that file path. \
You can change which song is rendered in the Synthesizer.makeSoundData() method in Synthesizer.main. Change the song1() method to song2, song3, song4, or write your own song and render it. You can also change or create new instruments in Synthesizer.main. \
MiscHelpers.swift contains some miscellaneous helper methods. \
MathHelpers.swift contains some math function helper methods. \
MusicHelpers.swift contains the Echo and ADSR effects. The Event struct is vaguely analogous to an event in MIDI, representing either a note, rest, or command. The Command enum represents commands to change the ADSR, echo, instrument, tempo, dynamics, or global cent offset for microtuning. The Line class represents a "voice" that has a line of notes and commands that are naturally grouped together. 

The text notation for songs is briefly described here: \
Commands are specified using ```(COMMAND=a;b;c)```, where semicolons separate different parameters. The semicolon is omitted for commands with a single parameter. The parameter to an instrument command must exactly match the name of the Instrument enum. Individual notes are specified with a capital letter name (A-G) followed by an optional accidental (bb, b, #, x), followed by a digit (0-9) specifying the octave, followed by an optional tuning modifier (+ or -, then a one or two digit integer, specifying the offset in cents). Chords are specified by ```[NOTENOTENOTE]```. Rests are specified by ```r```. To have a note or rest have a duration other than 1, use ```{NUM/DENOM}```, where NUM and DENOM are positive integers or floating point numbers. If the denominator is 1, the ```/1``` can be omitted.\
The ADSR parameters are as follows: The maximum amplitude of the attack, relative to the sustain, the duration of the attack in frames, the duration of the decay in frames, the duration of the release in frames. \
The Echo parameters are as follows: The amplitude of the echo, relative to the initial signal, the delay of the echo, in beats. 
