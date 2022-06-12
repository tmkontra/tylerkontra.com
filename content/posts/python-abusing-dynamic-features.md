---
draft: true
date: 2022-06-11T05:15:32-07:00
title: "compatlib: Going overboard with dynamic Python, and the dangers of sharing your code with the world"
description: "Just because we can, doesn't mean we should."
slug: "compatlib-python-dynamic" 
tags: ["python", "open source"]
categories: ["programming"]
---

# Coding Across Python Versions

The `asyncio` library in Python is not very old, relative to the language: it was introduced in Python 3.4. But even during its short lifetime, `asyncio` has undergone numerous API changes. One important example is the lineage of the [asyncio.run](https://docs.python.org/3/library/asyncio-task.html#asyncio.run) function. Introduced in Python 3.7, `asyncio.run` is a high-level API to the older [asyncio.loop.run_until_complete](https://docs.python.org/3/library/asyncio-eventloop.html#asyncio.loop.run_until_complete) method. 

So if code runs under Python 3.7+ then it can make use of `run`, otherwise it needs to rely on `asyncio.get_event_loop().run_until_complete`.

This isn't a problem if you are writing an application, since you'll probabl run that application under a well-known version of Python -- the version you choose.

But if you are writing a library, you would need to support Python <=3.6 and Python3.7+. The code might look something like this:

```py
# code courtesy of @mark-nick-o on mypy issue #12331: https://github.com/python/mypy/issues/12331
if (sys.version_info.major == 3 and sys.version_info.minor >= 7):
    asyncio.run(main())
elif (sys.version_info.major == 3 and sys.version_info.minor <= 6) and (sys.version_info.major == 3 and sys.version_info.minor >= 5):
    loop = asyncio.get_event_loop()
    loop.run_until_complete(asyncio.wait(main()))
else:
    print("you currently need to have python 3.5 at least")
```

That code isn't too bad, but can we make it _better_?

# compatlib

This is the reason I decided to write [compatlib](https://github.com/tmkontra/compatlib).

Instead of branching if-else statements, `compatlib` lets you perform method overloading based on the version of the python interpreter:

```py
# my_module.py

import asyncio
from compatlib import compat

@compat.after(3, 4)
def main() -> None:
    asyncio.get_event_loop().run_until_complete(coro())
    return 3.4

@compat.after(3, 7)
def main() -> None:
    asyncio.run(coro())
    return 3.7
```

This means that invoking `my_module.main()` on a Python 3.6 interpreter will return `3.4`, while running it on Python 3.7 will return `3.7`.


To my eyes, the `compatlib` implementation is much more readable: instead of grokking `sys.version_info` checks, you can clearly see `(major, minor)` version tuples and the associated code. But that doesn't make the `compatlib` code better than the first example -- and it definitely doesn't make `compatlib` a _good idea_.


It wasn't until I shared `compatlib` with the world that I realized how dangerous it is. 

I understood `compatlib` to be a fun novelty. I decided to share it with the Hacker News community, to see what kind of reaction it got. I could not have been more surprised.

The conversation that ensued was far more incisive and interesting than I could have imagined. Folks were discussing the merits and prevalence of librarires supporting multiple Python versions, the quickest and easiest ways to reproduce certain subsets of `compatlib` features, the parallels with `awk`'s `BEGIN` blocks, the absence of macros in Python. 


And one comment stood out to me -- far beyond the rest, because it succinctly captured my thoughts on `compatlib`: don't use this. 

It's amazing to see what the Python community accepts and rejects; what goes into and out of vogue. Hopefully, `compatlib` stays out of vogue, in favor of simpler, less magical alternatives.

<!-- # Dynamic Python

Python is a dynamic language.

We often make that statement without understanding what it really means. I'm certainly guilty. 

Usually, we are referring to the fact that [type checking only occurs at runtime](https://realpython.com/lessons/dynamic-vs-static/), and not before-hand via a compiler. 

So when I say that I "abuse the dynamic nature of python", I'm not even certain that is entirely accurate. What I do know is that python allows you to do some things very easily, things that would otherwise be exceedingly difficult or ugly to implement in a more static language, like Java ("reflection" is the "dynamic toolkit" of Java). -->

