+++ 
draft = false
date = 2023-07-23T21:11:57-07:00
title = "Programmatic Customization of KDE Settings"
description = "Repeatable configuration for your Plasma desktop"
slug = "programmatic-kde-customization" 
tags = ["kde", "fedora", "plasma"]
categories = ["linux"]
+++

I cycle through linux distros pretty often. Not as often as I used to, but still every once in a while.

I recently built a mini-ITX workstation to serve as my dedicated development machine, which allowed me to disentangle an existing dual-boot Windows/Ubuntu desktop.

For the new workstation, I decided to migrate from Ubuntu to Fedora. I used Fedora for a number of years, and decided it was time to go back. This time, I decided to roll with the KDE Plasma desktop.


After booting up Fedora, the first thing I decided to do was modify the keyboard layout and shortcut keybindings to be "MacOS-like". Most of my daily computing is done on MacOS, so I like to have consistency across machines (cmd-tab, cmd-c/v, etc.)

Luckily, I found this [helpful tutorial](https://kasikcz.medium.com/en-macos-keyboard-shortcuts-in-kde-linux-b40299d5cff5) from Martin Kaše on how to perform such a customization. But, after so many years of distro-hopping (and knowing I very well might FUBAR this installation and need to re-install it) I thought I should make this process into a script so I could do it in 1-click instead of a dozen the next time around.

## Tracking down the configs

KDE, like any full-featured desktop environment, has a mind-boggling array of customization options. The GUI does a great job of making them all discoverable, but I wanted to avoid a point-and-click routine in the future. Since this is linux, I knew there must be a programmatic way to modify these configurations.

KDE's configuration files aren't exhaustively documented, but it is well-known that [kwriteconfig5 can be used to modify the configurations](https://www.reddit.com/r/kde/comments/t3iks7/automate_kde_configuration/). This put me on the right track to learn that the KDE config files live in `~/.config`.

Now it was just a question of _which_ config file my target settings live in, and _what_ the exact setting keys and the desired values would be. I know what the _GUI_ says, but it doesn't readily tell you what it's doing behind the scenes.

[inotifywait](https://linux.die.net/man/1/inotifywait) is an invaluable tool, it just watches files and reports events on them (open, close, modify, etc.).  In this case, I can use it to identify which config file a setting belongs to.

```
$ inotifywait -m -r ~/.config
Setting up watches.  Beware: since -r was given, this may take a while!
Watches established.
```

Now `inotifywait` will print out all events on files under `~/.config`. Of course, many apps use this directory, so I closed all other applications, and only opened the System Settings app.

![KDE Keyboard Layout Customization](/images/kde-customization/kde-keyboard-layout-2.png)

Now I make the desired selections, and once I click `Apply`, `inotifywait` prints out the file that is modified.

```
$ inotifywait -m -r ~/.config
Setting up watches.  Beware: since -r was given, this may take a while!
Watches established.
.config/ CREATE kxkbrc.lock
.config/ OPEN kxkbrc.lock
.config/ MODIFY kxkbrc.lock
.config/ OPEN kxkbrc
.config/ ACCESS kxkbrc
.config/ CLOSE_NOWRITE,CLOSE kxkbrc
.config/ OPEN #221860
.config/ ATTRIB #221860
.config/ MODIFY #221860
.config/ CREATE kxkbrc.GSdapf
.config/ CLOSE_WRITE,CLOSE #221860
.config/ MOVED_FROM kxkbrc.GSdapf
.config/ MOVED_TO kxkbrc
.config/ ATTRIB kxkbrc
.config/ CLOSE_WRITE,CLOSE kxkbrc.lock
.config/ DELETE kxkbrc.lock
.config/ OPEN kxkbrc
.config/ ACCESS kxkbrc
.config/ CLOSE_NOWRITE,CLOSE kxkbrc
```

Clearly, `kxkbrc` (something like "KDE X keyboard rc" file) contains the Keyboard Layout customization configs.

Now it's just a matter of identifying the right key-value pair(s).

To do that, I can take a "clean copy" of the config file(s), apply my desired changes via GUI, and then compute the diff.

```
$ cp ~/kxkbrc.bak ~/.config/kxkbrc 
...
$ diff -U5 ~/.config/kxkbrc ~/kxkbrc.bak
--- ~/kxkbrc.bak
+++ /home/tmck/.config/kxkbrc
@@ -1,5 +1,6 @@
 [$Version]
 update_info=kxkb.upd:remove-empty-lists,kxkb.upd:add-back-resetoptions,kxkb_variants.upd:split-variants
 
 [Layout]
+Options=ctrl:swap_lwin_lctl
 ResetOldOptions=true 
```

`Options=ctrl:swap_lwin_lctl` -- that's it! So, in KDE-settings-speak: I need to set the key `Options` under the `Layout` group in `xkbrc` to a value of `ctrl:swap_lwin_lctl`.

# Now a script

The `kwriteconfig5` utility can now do exactly what I need:

```
$ kwriteconfig5 --file kxkbrc --group Layout --key Options ctrl:swap_lwin_lctl
```

If you want to make a numerous changes, you can put a sequence of these commands in a bash script. `kwriteconfig5` takes care of injecting the right text into the right location in the right file, and the outcome is the same as making changes via the GUI.

# Maybe as an overlay?

Of course, KDE's configuration files are very powerful, and support ["cascading configuration"](https://userbase.kde.org/KDE_System_Administration/Configuration_Files#Configuration). It merges config files (by filename) on a key-by-key basis for all groups.

Theoretically, instead of a script, you could store configuration overrides as configuration files, and simply copy them into your `$KDEHOME` directory after a fresh install.

Unfortunately, my Fedora KDE spin doesn't have a `$KDEHOME` set, so I didn't feel like mucking around with it, and the `kwriteconfig5` approach worked well enough in my case.


It would have been great if every setting was fully documented, but it just goes to show that even when there are rough edges in the Linux experience, tools are readily available to dig under the hood and hack together your own solution. There is a nice upper-bound on complexity when "everything is a file".
