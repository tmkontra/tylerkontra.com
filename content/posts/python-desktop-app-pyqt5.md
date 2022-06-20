+++ 
draft = false
date = 2020-07-15T20:11:48-07:00
title = "Making a Desktop App with Python PyQt5"
description = "How are desktop apps different from web apps?"
slug = "" 
tags = []
categories = []
+++

### Getting Outside My Comfort Zone

It'd be pretty challenging to peg me as anything other than a web developer at this point. I've built and shipped server-side applications that are precipitated by the web. It's in vogue. But there's a whole world of software development that doesn't even need the web: desktop applications.

I remember making tiny Tkinter apps when I first learned python (nearly a decade ago now). But they weren't terribly pretty nor terribly useful. So recently (stuck at home pacing back and forth), I decided to learn state-of-the-art desktop development using python in 2020.

I came to the conclusion that PtQt5 was what I wanted:

- Mature, established implementation 
- Cross-platform
- [Great tooling](https://doc.qt.io/qt-5/qtdesigner-manual.html)

[Kivy](https://kivy.org/#home) and others are sexy and promising, but seemed too nascent for my purposes: building an application quickly.

So I left behind the world of web apps, and saddled up for desktop development.

### PyMyLedger: Up and Running, Codegen with QtDesigner

I decided to build a (minimalist) spending tracker: **PyMyLedger** 

- Tracks month-by-month
- Handles two types of expenses: static (same every month) and variable (don't know how much it will be until the month is over)
    - Static expenses basically just auto-populate when you start a new month, using the previous month's value

    
I used QtDesigner to create the initial layout:

- Month selector
- New month button
- Static expense table
- Variable expense table
- Save and Load Buttons
- Month balance calculation

It looks like this:
![PyMyLedger layout](/images/pyqt5/pml-layout.png)

I save the layout files (XML) to a specific location, and use `pyuic5` to generate the PyQt5 code. I do not modify the generated code, so I can run the conversion idempotently:

```
pyuic5 resource/acc.ui -o pymyledger/ui/gen/ui_pyledger.py
```

The classes in the `gen` package are then wrapped and modified by classes in the `ui` package.

### From MVC to...something else

Handling the state and updating the presentation in a desktop app is a bit of a mindset shift from web development.

On the web, when you update the DOM, the user sees the updated data. Now, of course, you might actually construct the data on the server, but the server is still stateless, and the database is the only stateful entity. 

For a simple desktop app, I don't want to use a database, so all the application data will need to be in memory, loaded from a flat file.

Qt uses "signals", to handle state changes. The common ones are:

- clicked
- cellChanged (for table cells)
- currentTextChanged (for text editor)

These signal handlers need to be nullary functions (i.e. called with 0 arguments).

I decided to pursue separation of concerns by keeping all the application state in a "Data" class, and disseminating specific members of that data to the necessary widgets.

For instance, the list of months available is populated by the `Data.months` list, and when the "add new month" button is pressed, the specified month is appended to `Data.months` and in turn the list of months is re-rendered using the new list.

There's a lot of work that goes into making sure state doesn't mutate when it's not supposed to.


### Save Early, Save Often

Of course, with all the data being maniuplated in memory, we need a way for the user to save their progress and come back later.

I started out by just pickling/unpickling the `Data` class used by the app. This is not ideal for a few reasons:

- Prevents us from having different versions of our savefile specification
- Can be dangerous because unpickling can run arbitrary code
- Is not easily extensible (certainly not human readable).

Once I got the basic application working, I implemented a rudimentary serialization framework and implemented a `SerializerV0` which saves and loads `.json` files.

Since the `Data` class is basically a series of key-value pairs, json was well suited for the task. I was also able to add top-level keys like "version" to denote what Serializer version the file is compatible with.


### Caching for a Better Experience

I wanted to add small usability/ergonomics features to make the experience better for the end user. For instance, when you save a file then exit the application, I want to open that save file automatically the next time the application starts.

For this I implemented a basic file system cache to store information like "last save file" and other user preferences.

To be cross-platform compatible, I borrowed the "user cache directory" algorithm from [appdirs](https://pypi.org/project/appdirs/).

The application uses an `app_data.json` file that is saved and loaded when the application is started and stopped. As of now, it only has one key: `last_opened`, which is the absolute filesystem path of the most recently saved file.


### TODOs

The app is in a usable state, it's not perfect, but I am nearing a 0.1 alpha release.

I am currently working on my build and release toolchain, to build installables for mac, linux and windows. For this, I am using [PyInstaller](https://www.pyinstaller.org/). I've got the macOS application building successfully, but have some improvements to make such as logging to a file when no terminal is present, and including a custom application icon.

You can check out PyMyLedger here: [https://github.com/tmkontra/pymyledger](https://github.com/tmkontra/pymyledger)

Stay tuned for progress updates!

Until next time -

