+++ 
draft = false
date = 2023-11-10T19:00:10-08:00
title = "How to make Closeable Flash Messages without Javascript (CSS-Only)"
description = "Progressive enhancement means starting with something to be enhanced"
slug = "css-only-closeable-toast" 
tags = ["html", "css", "web development"]
categories = ["programming"]
+++

Recently, I was working on an HTML frontend for a server-rendered application.

Naturally, I want to display temporary ("flash") messages to the user. For example when confirming a form submission, or indicating an error. My first instinct is to turn to javascript. With javascript, this is a no-brainer. But I was trying to follow a "progressive enhancement" approach, which means I need to first implement *without javascript*.

# Finding a Solution

So at this point, I turn to google:

> how to close a div without javascript

The first result is actually quite helpful:

https://stackoverflow.com/questions/19170781/show-hide-divs-on-click-in-html-and-css-without-jquery

But, as is often the case, the *accepted answer* here is not quite the *best* answer.

Rather, the [second answer](https://stackoverflow.com/a/19170816) is really what I was looking for.

```css
input[type=checkbox]:checked + p {
    display: none;
}
```

That css snippet is referring to two *adjacent* siblings: an `input` and a `p`, and when the `input` is **checked**, the `p` will be hidden.

This is the exact behavior I wanted, but I needed to adapt it slightly...


# CSS Selectors

When flashing the message, it is a div with some text and close button. Swapping in a checkbox for the button, it looks something like this:

```html
<div id="flash-container"> 
    <p>Flash message here!</p>
    <input hidden type="checkbox" id="this-checkbox">
    <label for="this-checkbox">
        X
    </label>
</div>
```

Now, I want `#this-checkbox` to hide `#flash-container`. However, there is in fact no CSS selector for "the parent element". Basically, `#this-checkbox` can't affect the styling of `#flash-container` -- they'd have to be *siblings* of some kind. 

At this point, I started to think what I wanted just wasn't possible.

# HTML Flexibility

Luckily, to my surprise, I discover an input and its label **do not have to be adjacent, nor be under the same parent.**

So I can define my flash like so:
even
    <label for="this-checkbox">
        X
    </label>
</div>
```

Now, when clicking on the `label`, `#this-checkbox` will change to the `checked` state, and we can make our CSS hide `#flash-container` when that happens:

```css
input[type=checkbox]:checked + #flash-container {
    display: none;
}
```

Checkboxes can serve as CSS-only toggles! The input goes adjacent to the element to modify, and the clickable label can go anywhere!

You can even "componentize" this concept by using a class (like `.close-on-check`) instead of an id. Here's a fiddle as an example:

https://jsfiddle.net/o47efsk9/53/

