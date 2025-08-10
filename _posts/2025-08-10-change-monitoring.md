---
layout: post
title:  "Quick and Dirty Website Change Monitoring"
categories: generic
author: julian
published: true
---

Let's say, you need to monitor a website for changes and you really
don't have a lot of time to set things up. Also solving the problem
with money using services, such as
[changedetection.io](https://changedetection.io/) or
[visualping.io](https://visualping.io/), have failed you, because
their accesses are probably filtered out.

I've come up with the following scrappy solution. First, I want to get
push notifications to my phone. So I installed
[simplepush](https://simplepush.io/) on my phone. There are a couple
of these services, this was just the first I found and it works well.

I have a couple of Linux servers. So I just logged in to one,
installed [ntfy](https://github.com/dschep/ntfy) and the [Links
text-based web
browser](https://en.wikipedia.org/wiki/Links_%28web_browser%29)
(probably `links2` in your package manager).

Configure `ntfy` with your simplepush key:

```yaml
# ~/.config/ntfy/ntfy.yml 
backends:
  - simplepush
simplepush:
  key: 12345
```

Afterwards, you can just dump the website to a text file with Links
and send a push notification to your phone when something changes:

```sh
#!/usr/bin/env bash

# By starting without old.txt, we get a notification when we start the script
rm -f old.txt

# Let's be polite here and not hammer the site.
POLL_FREQ_MIN=15

URL="https://example.com/"

while true; do
    touch old.txt
    links -dump "$URL" > new.txt

    if ! diff -u old.txt new.txt > diff.txt; then
		# It's hard to condense the changes (diff.txt) into something readable,
		# so we just send the URL to easily click on on the phone.
        ntfy send "Check $URL"
    fi

    mv new.txt old.txt

    sleep $(($POLL_FREQ_MIN * 60))
done
```

This only works for simple websites and there is a lot left to be
desired. But it is doable in the 10 minutes of productivity a newborn
baby gives you and it works to get appointments at government offices
in Spain. 😉

PS. This blog post was written in another 10-minute productivity
window.
