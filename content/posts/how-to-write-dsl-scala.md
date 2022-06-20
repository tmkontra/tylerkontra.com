---
title: "How to Write A DSL in Scala"
date: 2020-06-17T19:26:41-07:00
draft: false
---

DSL -- domain specific language. DSLs are often touted as the silver bullet to let "users write their own business rules". They're even *more* often used when they shouldn't be, and just end up complicating things. But they _are_ fun. And used correctly, they can be a really powerful, highly expressive tool.

A well-known example, and one of my personal favorites, is of course the [ScalaTest](https://www.scalatest.org/) spec/assertion dsl. It lets you write highly expressive assertions like:

```bash
myBooleanResult should be (true)
```

And, when you see that for the first time, you might ask

1. How the heck does that work?
2. Isn't that just `myBoolean == true` ?

To which I'd answer:

1. Scala supports [infix notation](https://docs.scala-lang.org/style/method-invocation.html)
2. Not even close.

### Packing a Punch

There's a multitude of reasons why `should be` is far superior to `==`. Right now I'll hit the highlights and get on to teaching you to write you own, similar, dsl.

The combination of `should be` creates a layering of classes that allow us to compare `myBooleanResult` and `true`, but get natural language success and error messages, i.e.:

```bash
SUCCESS: myBooleanResult was true
FAILURE: myBooleanResult should have been true
```

instead of:

```bash
SUCCESS: myBooleanResult == true
FAILURE: myBooleanResult != true
```

This is just one (trivial) example of why ScalaTest is so great, but it should give you an idea of how dsl's look and feel in Scala.

### What's In a DSL

Let's start from the abstract. If we want to write code that looks like natural sentences, let's start by examining natural sentence structure.

```bash
Juliet visits Grandma.
```

A mundane enough sentence, wouldn't you say? Let's break it down.

We have:

1. "Juliet" -- our subject
2. "visits" -- our verb
3. "Grandma" -- our direct object

So that means we'd need an API that cpatures those concepts. In regular old code it might look like:

```scala
class Subject () { def visits(obj: DirectObject): Unit = ??? }
class Visitable extends DirectObject
val Juliet = new Subject
val Grandma = new Visitable

Juliet.visits(Grandma)
```

Which is just fine but there's just something special about writing:

```scala
Juliet visits Grandma
```

_in_ our source code.

A generalized/stubbed API might look like this:

```scala
package dsl

object Abstract {

  class SubjectWord {
    def verb(obj: DirectObject): Any = ???
  }

  class DirectObject

  val mySubject = new SubjectWord()

  val myObject = new DirectObject()

  mySubject verb myObject
}
```

### Serving It Up

Let's try creating a dsl to do something (semi-) useful!

We'll write an API that lets us simulate a catering business or restaurant.

It will have:

1. Guests (people) organized into parties
2. Guest's food preferences
3. Servers who bring food to parties of guests

Servers will serve food on a First-Come-First-Serve basis to anyone with preference for that food (I didn't say it was a competent catering business!)

Let's start with defining our "service" interface, i.e. the business logic... aptly named `Server` in our domain!

This server will:

1. be assigned to a party (group of people)
2. serve food to the party as it becomes ready, based on the rules we described above.

We'll take a stab at writing our `Server` with our ideal dsl, then we'll go about implementing it!

```scala
  class Server(party: Seq[Person]) {
    def serves(food: Food): Unit =
      party.collectFirst {
        case person if person hasPreferenceFor food => person
      } match {
        case Some(person) => person gets food
      }
  }
```

We see:

1. We'll need a way to check someone's preference (`hasPreferenceFor`)
2. We'll need a way for a person to receive food (`gets`)

Let's start on our person implementation:

```scala
  class Person() {
    def hasPreferenceFor(food: Food): Boolean = ???

    def gets(food: Food): Unit = ()
  }
```

Simple enough? Just two 1-Arity methods that we can call with infix notation.

But how do we implement `hasPreferenceFor`? With more dsl of course!

```scala
  class Person() {
    private var preference: Option[Food] = None

    def prefers(food: Food) =
      preference = Some(food)

    def hasPreferenceFor(food: Food): Boolean =
      preference.contains(food)
    ...
  }
```

We add some state (`preference`) to our Person, which starts out as `None` (i.e. prefers no food). We have a `prefers` method that will set the Person's preference (in Java, it might be called `setPreference`). And `hasPreferenceFor` simply checks equality of the incoming food against the Person's preference, and when `preference == None` they will _not_ prefer _any_ incoming food.

What do our food(s) look like? They can be as simple or complex as your implementation needs them to be. For this tutorial, we'll just use a couple of `case objects`: 

```scala
  trait Food

  case object Pizza extends Food
  case object Salad extends Food
```

And that's it! Now we can use our dsl!

```scala
val John = new Person()
val Sarah = new Person()

val johnAndSarah = Seq(John, Sarah)

val Martin = new Server(johnAndSarah)

John prefers Salad
Sarah prefers Pizza

Martin serves Pizza // Sara gets Pizza!
Martin serves Salad // John gets Salad!

John prefers None

Martin serves Salad // No one gets Salad!
```

No `.` or `()` to clutter our code! Now you're ready to write readable, natural code.


### Exercises

Some exercises that are left to the reader:

1. How to add [indirect objects](https://examples.yourdictionary.com/indirect-object-examples.html)?
2. In a group of many people, servers would be serving the same person over and over again! How can you improve the `Server` so that once a person has received food, the people further down the line get served once that food comes around again?
3. Furthermore from (2) -- can you make it so people eventually finish eating their food? And after they finish, they can receive a second helping of their food-of-preference.
4. Once (3) is done, the Server will definitely want to keep track of who had what, and in what quantities! Can you itemize a bill?
