---
title: "How to control Pioneer amplifier with Telnet?"
categories: [Home, Hacking]
date: 2018-07-08 20:01
---

I don't like when someone is removing nice features in hardware I bought. And this is the exactly situation my father had with Pioneer VSX-528 amplifier, after two years of using it with Spotify Connect the feature has been disabled permamently without any explanation. It was nice feature and was used frequentely, so I decieded to make something with it. To make it working as original feature I had to hack the amplifier a little bit ;)

<!--more-->

Adding Spotify Connect feature to the amplifier was the easy part, just find in the drawer and old Raspberry Pi B, write Raspbian to SD card and install [Raspotify](https://github.com/dtcooper/raspotify), change configuration and it is working. Really! Working, without any problems!. They are advertising themselfs: "Spotify Connect client for the Raspberry Pi that Just Works™" and the every word is true! This is the smoothest installation/integration of the open source tool I ever had. It worked out of the box, much better (in terms of discoverability of device) than original Spotify Connect in amplifier (not only in this one).

The problem was that the experience was not exactly the same as with original feature. There were need to manually change the input to the Raspberry Pi. Just one click, but irritating one. Especially when typically, to change Spotify device you are using Spotify on smartphone or PC, not remote control from amplifier.

I've decieded to make something with this issue. My first idea was to use some heavy DLNA control feature (XML and stuff...), but then I found [this blog post](https://raymondjulin.com/blog/remote-control-your-pioneer-vsx-receiver-over-telnet). This idea seem to be much simpler in usage, so I gave a try.

According to this article I should type `telnet pioneer.local` and I'll be able to control the amplifier, but there was nothing listening on Telnet port in amplifier :( Fortunatelly, I had an `nmap` on my computer ;), so it told me that there is a couple ports opened for this IP. By testing one-by-one I found that port `8102` was the one I'm looking for. Bingo!

I've started sending the commands to the amplifier:

```
>21FN
R
>25FN
R
>?V
1V
```

Each command that changes the input was returningi an error (I guess), but asking for volume resulted with "something". It seems that in this model, the inputs are named differentely than in described in article. So I've asked amplifier which input is enabled:

```
>?F
FN49
>FN49
R
>49FN
FN49
```
It seemed weird, but the response was "inverted" and the input name formatted as in article has been working correctly.
So I have a name and port. I have just send it to the amplifier:

```
echo "49FN" | nc pioneer.local 8102
```

And no results :( The solution was obvious, but I was sad that I've not started with it:

```
print "49FN\r\n" | nc pioneer.local 8102
```

And.....yes! It's alive! Just connect it to Spotify and we're done!

### How to detect if Spotify was activated?

The `raspotify` is build on top of `librespot` project, which offers an `--onevent` parameter that takes the command that should be executed when Spotify event occurs. The details of the event are passed as envirionment variables, so it is possible to use actually anything to run particual piece of code.

I ended with script that looked like this:

```bash
#!/bin/bash

HOST=pioneer.local
PORT=8102
if [$PLAYER_EVENT = "start"]; then
    printf "49FN\r\n" | nc $HOST $PORT
fi
```

and with additional line in `raspotify` configuration:

```
OPTIONS="--onevent /raspotify/select_input.sh"
```

And this is the whole story. I really like when my skills are helping someone in real world! In this case the Raspotify works much better than original feature (no problems with discovering device) while mimics original behaviour.
