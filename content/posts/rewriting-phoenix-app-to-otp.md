---
draft: false
date: 2021-10-14T20:15:32-07:00
title: "Rewriting A Phoenix App to Really Learn OTP"
description: "From a stateless web application to a true OTP app: functional core with persistence at the edge."
slug: "rewriting-a-phoenix-app-to-learn-otp" 
tags: ["phoenix", "elixir", "web development"]
categories: ["programming"]
---

# The Phoenix Framework

If you're not familiar with [Phoenix](https://www.phoenixframework.org/), I highly recommend giving it at least a cursory look. Frankly, I learned Elixir by learning Phoenix. I don't _really_ know Elixir, but I am productive in Phoenix. I can rapidly prototype web applications and be confident in the performance (thanks to the BEAM VM and OTP, as we'll see). Phoenix is to me what I imagine Django was for developers 10 years ago. 

# The 'Bullion' App

Bullion (sometimes referred to as 'Banker') is a simple web app I built to track chips at a poker table. I originally built it in a single weekend, as a challenge to myself, to see just how productive I could be in Elixir.

# The Rewrite

I recently rewrote 'Bullion', nearly from scratch. The first version of the application was traditional stateless web app code. It was tightly coupled to Phoenix, and offloaded all state to the database. To conduct business logic, it would look up the current state, compute the new state, and persist it. This probably all sounds very familiar. And it was! It worked just fine, it was easy (and fun) to develop. But I didn't feel like I gained any expertise with OTP. 

After reading [Functional Web Development with Elixir, OTP, and Phoenix](https://pragprog.com/titles/lhelph/functional-web-development-with-elixir-otp-and-phoenix/) I was inspired to write a "real" OTP app, with Phoenix simply playing the role of delivery mechanism, and the database relegated to the boundary.

# OTP Essentials

The OTP is a toolkit for building resilient and scalable distributed systems. Many [others can explain](https://serokell.io/blog/elixir-otp-guide) it in detail better than I could. Think of it as a runtime consisting of processes (green threads), servers (processes with private state and a message queue) and supervision trees (that manage starting, restarting and stopping processes). Elixir Processes are incredibly lightweight, and the OTP encourages spinning up as many of them as you need (no more, no less!): thousands would be fairly unremarkable.

The GenServer (Generic Server) is the canonical implementation of a server in OTP. It holds some state, and processes messages sequentially. They are great for managing the isolated entities in a stateful system. Perfect for say, a poker table! Each table is only concerned with its players and how many chips they have, right? (Let's assume these are home games, so "leaving a table" means cashing out; you don't show up to another table with chips, like you could in a casino)

# A Functional Core

The original application had models (structs) that mapped directly to database tables:

- `Player`, for a single game, with their buyin count for that game 
- `Cashout`, a specific cashout for a player, with number of chips cashed-out 
- `Game`, a table, that encompassed all players, their buyins, and their cashouts. 

This relational model was queried and manipulated (UPDATE or INSERT) by request handlers. These structs were inextricably linked to database rows.

The new application would be built on a "fully functional core". These would be plain structs (with no relational mapping or ORM integration). In fact, these structs and their business logic would be entirely separate from the Phoenix web application, and could be run on its own, or even used as a library! 

There are only two structs in this new application:
1. Table
2. Player

A `Player` would have only one attribute, their name. The player's id would be generated when they are added to a game (the id would only be unique _within_ a game).

To start a `Table`, you must specify the "buyin amount" (i.e. dollars) and "buyin chips" (number of chips). This defines the ratio of chips-per-dollar. The `Table` will accumulate the list of players. It will also maintain a mapping of "buyins" (an integer count) and "cashouts" (a list of chip counts) for the players.

The table struct defines all the operations for conducting a game:

 - add_player(name): Table
 - buy_in(player_id): Table
 - cashout(player_id, chip_count): Table

 All these methods operate on a `Table`, and return the updated `Table`.

Since Elixir is a purely functional language, the `Table` struct doesn't really have methods, but rather the `Table` module has static methods that take a table instance as the first argument. A unit test of the `Table` looks like this:


```elixir
  test "cashouts should update balance" do
    {plid, table} = Table.new(%{name: "my great game", buyin_dollars: 20, buyin_chips: 100})
      |> Table.add_player("Tyler")
    {_player, table} = Table.buyin(table, plid)
    {_player, table} = Table.cashout(table, plid, 22)
    {player_chips, player_value} = Table.player_balance(table, plid)
    assert(player_chips == table.buyin_chips - 22)
    assert(player_value < table.buyin_dollars)
  end
```

You'll notice each mutation of the table requires the caller to keep track of the updated table (i.e. the `table` variable on the left-hand-side of the variable assignments.). Immutability means once you modify a table, all the references to it are outdated. This is where the stateful `GenServer` comes in.

# A Table Server

Elixir is an immutable language. To implement mutable state, you need a `GenServer`. 

A `GenServer` basically provides a way to say, "here is some data, hold on to it for me, and give me your phone number so I can call you and tell you what to do with it".

Our `GenServer` will take a `Table` (most likely a freshly created table), and give us back an identifier for that `Table`. All we need is a reference to the `GenServer` (which never changes). Think of it like a "dealer", we ask for their phone number, and they keep track of the table based on the instructions we give them.

A `GenServer` can be stateful because it is a _process_. It's a living, running thing, like a thread. It essentially polls its mailbox, waiting for a message, then processes it, stores the new state, and goes back to sleep. One of those message handlers (a `call` for a "buyin") looks like this:

```elixir
  def handle_call({:buyin, player_id}, _from, %Table{id: table_id} = state) do
    {player, state} = state |> Table.buyin(player_id)
    BullionCore.save_buyin(table_id, player_id)
    {:reply, :ok, state}
  end
```


So when we start a server for a `Table`, we get an Elixir PID (process id -- again, not an OS process) that corresponds to the server _managing_ the table. If the server crashes (maybe we didn't implement input validation, and we try to add a string to an integer), we may want to restart it with the last known good state and let the user try again. This begs for something to _supervise_ the servers: a `Supervisor`. 

# Table Supervision

So now, we introduce an abstraction over all the table servers: a Supervisor. Think of the supervisor like a Pit Boss. Now we only need to know who the pit boss is, and give them the PID of the table server, then they will find the dealer responsible and give them the instructions.

Now, you may be confused about the table id <> PID dichotomy. The OTP developers have you covered. `GenServer` supports the concept of a `Registry`, which maintains the mapping of some identifier (in our case, a unique random string) to PID. So now, we can give the Supervisor a PID _or_ a table id, and they will find the table for us either way.

This is possible because an Elixir PID is its own type, so we can pattern match like so:

```elixir
  def view_table(table_id) when is_binary(table_id) do
    pid = via(table_id)
    view_table(pid)
  end

  def view_table(table_pid) when is_pid(table_pid) do
    TableServer.view_table(table_pid)
  end
```

The supervisor implements the interface to table instructions like so:

```elixir
  def add_player(table_id, player_name) do
    ...
  end

  def player_buyin(table_id, player_id) when is_binary(player_id) do
    ...
  end

  def player_cashout(table_id, player_id, chip_count) do
    ...
  end
```

It looks up the table pid via the registry, then delegates to the table's server process to handle the instruction.

# The Application Interface

To wrap up our core application, we define an `Application` module conforming to the OTP Application interface which starts our supervisor:

```elixir
defmodule BullionCore.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Starts a worker by calling: BullionCore.Worker.start_link(arg)
      # {BullionCore.Worker, arg}
      {Registry, keys: :unique, name: Registry.Table},
      BullionCore.TableSupervisor
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: BullionCore.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

```

Now we have an OTP app: a supervision tree consisting of a table supervisor and its child processes (tables), all managing fully functional table structs at the core.

# The Web Interface

Since Phoenix is itself an OTP app (like nearly all Elixir packages), we can simply import and integrate the `bullion-core` app we built.

We add it to our deps:

```elixir
  {:bullion_core, path: "../bullion-core"},
```

and make our Phoenix app manage it (Phoenix is a supervisor itself, and it can manage _our_ supervisor):

```elixir
config :bullion, BullionWeb.Endpoint,
  ...
  reloadable_apps: [:bullion_core]
```

Now we write a controller to expose our table interface as HTTP endpoints:

```elixir
defmodule BullionWeb.V2Controller do
  use BullionWeb, :controller

  alias BullionCore.{TableSupervisor, Table}

  def index(conn, _params) do
    render(conn, "index.html")
  end

  def start_game(conn, %{"name" => name, "buyin_chips" => buyin_chips, "buyin_dollars" => buyin_dollars}) do
    with {buyin_chips, _err} <- Integer.parse(buyin_chips),
         {buyin_dollars, _err} <- Integer.parse(buyin_dollars),
         {:ok, pid} <- TableSupervisor.start_table({name, buyin_chips, buyin_dollars}),
         {:ok, table} <- TableSupervisor.view_table(pid)
    do
      conn
      |> redirect(to: Routes.v2_path(conn, :view_game, table.id))
    end
  end

  def view_game(conn, %{"game_id" => game_id}) do
    with {:ok, table} <- TableSupervisor.view_table(game_id) do
      conn
      |> render("view.html", table: table)
    else
      _err -> conn
      |> put_flash(:error, "No table found!")
      |> redirect(to: Routes.v2_path(conn, :index))
    end
  end

  def add_player(conn, %{"game_id" => game_id, "player" => %{"name" => name}}) do
    ...
  end

  def add_buyin(conn, %{"game_id" => game_id, "player_id" => player_id}) do
    ...
  end

  def cashout(conn, %{"game_id" => game_id, "player_id" => player_id, "chip_count" => chip_count}) do
    ...
  end
end
```

As you can see, we just pass the HTTP request parameters (path, query or form parameters) to the `TableSupervisor` method interfaces. 

Now when we submit a "Start Game" request, it starts a table process. And when we add a player, it updates the in memory state. 

Our rewrite is complete! We've implemented a fully functional OTP app and wrapped it in a Phoenix web app. 

But, you might realize that all of our state will be lost if we restart the app (i.e. every time you deploy), or if the app crashes or the server reboots.

It's time to talk persistence.

# Persistence at the Edge

The application is fully functional as is, and we want to introduce persistence in a way that does not conflict with either the stateless nature of the webserver nor the stateful-and-purely-functional nature of the core OTP app. 

What if we _inject_ persistence? We can optionally inject _callbacks_ into our server processes to handle persistence of each action.

For instance, creating a new table would go from this:

```elixir
# table_server.ex
  def init({table_id, table_name, buyin_chips, buyin_dollars}) do
    table = Table.new(%{id: table_id, name: table_name, buyin_dollars: buyin_dollars, buyin_chips: buyin_chips})
    {:ok, table}
  end
```

to this:

```elixir
# table_server.ex
  def init({table_id, table_name, buyin_chips, buyin_dollars}) do
    table = Table.new(%{id: table_id, name: table_name, buyin_dollars: buyin_dollars, buyin_chips: buyin_chips})
    BullionCore.save_new_table(table)
    {:ok, table}
  end
```

We add a single call, `BullionCore.save_new_table(table)`, that does whatever it means to "save_new_table". It could be writing to a file, or saving a row to a database.

How to define this callback?

`BullionCore` looks like this:

```elixir
defmodule BullionCore do
  alias BullionCore.Table

  @save_new_table_fn Application.fetch_env!(:bullion_core, :save_new_table_fn)

  def save_new_table(%Table{} = table, save_fn \\ @save_new_table_fn) do
    save_fn.(table)
  end
...
```

This is Elixir-speak for passing around functions as values.

`@save_new_table_fn` is a module attribute, in this case it's used to define a constant. This is retrieved from the "application environment", i.e. the configuration for `:bullion_core`, specifically the `:save_new_table_fn` configuration key.

The `save_new_table/2` function turns this method constant into the `BullionCore.save_new_table(table)` callback we used above. The `save_fn` parameter is optional, defaulting to the module constant.

We implement the other callbacks the same way:

- table_lookup(table_id)
- save_player(table, player)
- save_buyin(table_id, player_id)
- save_cashout(table_id, player_id, chip_count)

The implementation of these callbacks for our Phoenix app relies on Ecto, and look like so:

```elixir
  def save_new_table(%Core.Table{} = table) do
    %{
      table_id: table.id,
      name: table.name,
      buyin_chips: table.buyin_chips,
      buyin_dollars: table.buyin_dollars
    }
    |> Table.changeset()
    |> Repo.insert!
    table
  end

  def lookup_table(table_id) do
    Table
    |> Repo.get_by(table_id: table_id)
    |> Repo.preload([players: [:buyins, :cashouts]])
    |> case do
      nil -> nil
      record -> record_to_table(record)
    end
  end

  def save_player(table_id, %Core.Player{name: name, id: player_id} = _player) when is_binary(table_id) do
    Table
    |> Repo.get_by!(table_id: table_id)
    |> Ecto.build_assoc(:players, %{name: name, player_id: to_string(player_id)})
    |> Repo.insert!
  end

  def save_buyin(table_id, player_id) when table_player(table_id, player_id) do
    with {:ok, player, table} <- find_player_at_table(table_id, player_id) do
      player
      |> Ecto.build_assoc(:buyins)
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.put_assoc(:table, table)
      |> Repo.insert!
    end
  end
```

They translate the `Core` structs to `Ecto` structs that live in our Phoenix app, then build the queries required to persist the desired update. The queries mostly just insert records: an append-only persistence model complements our fully-functional core quite nicely. They do a bit of stateful relation mapping (e.g. lookup a player's database row before adding a child `cashout` row), but transactional isolation isn't much of a concern: because updates are processed sequentially for each table server, persistence callbacks won't run concurrently for any single table.

Now we inject our callbacks into the `Core` via `config.exs`:

```elixir
config :bullion_core,
  table_lookup_fn: &Bullion.TableV2.lookup_table/1,
  save_new_table_fn: &Bullion.TableV2.save_new_table/1,
  save_new_player_fn: &Bullion.TableV2.save_player/2,
  save_buyin_fn: &Bullion.TableV2.save_buyin/2,
  save_cashout_fn: &Bullion.TableV2.save_cashout/3
```

We have persistence!

# Recovering State

What we have not covered yet is how the server reloads its state (or "rehydrates") after a restart.

As implemented, **the application does not perform any rehydration upon start-up**.

The discerning reader might realize that this introduces a bit of a rough edge to our application. Consider the following:

1. I start a table (maybe I add players and buyins and cashouts, whatever)
2. Time passes, the server restarts
3. I attempt to record a buyin for a player at the table

(3) will result in an error in the application. The running supervisor has no server process managing the game from (1), _even though_ it exists in the database! The error is something like this:

![Table Process Not Running Error](/images/rewrite-phoenix/table-process-not-running.png)

In order to remediate this bug, we would have to add a "check if table record exists" query before _every_ operation on a table. But wait! We can rely on the specific design of our application to simplify the implementation: because our app is a web app (and not, say, a JSON API), we can assume the user has to actually _view_ the game before issuing a command. This means we only need to rehydrate the table for a "view" request! Once we receive a "buyin" or "cashout" command, the table must already be running!

Now we can modify the method to view a table in our `TableSupervisor`:

```elixir
  def view_table(table_id) when is_binary(table_id) do
    with exists? <- via(table_id) |> table_process_exists?(),
         {:ok, table} <- create_table_process_if_record_exists(exists?, table_id) do
      TableServer.view_table(table)
    else
      _ -> {:error, :not_found}
    end
  end

  defp create_table_process_if_record_exists({running?, pid} = process_already_exists?, table_id) do
    IO.puts "table already running? #{running?}"
    case process_already_exists? do
      {false, nil} ->
        case BullionCore.table_lookup(table_id) do
          nil -> {:error, "Table #{table_id} not found"}
          table ->
            IO.puts "Found table #{table_id}!"
            start_table(table)
        end
      {true, pid} -> {:ok, pid}
    end
  end
```

This may look complicated, but it performs a few simple operations. Let's trace the behavior:

1. `view_table(table_id)`
    - we are attempting to view the table by its id
2. `exists? <- via(table_id) |> table_process_exists?()`
    - `via(table_id)` looks up the PID in the registry
    - `table_process_exists?()` checks if there is a `GenServer` actually running at that PID
    - `exists?` is a tuple of {running?, pid} where running is a boolean
3. `create_table_process_if_record_exists({running?, pid} = process_already_exists?, table_id)`
    - This method takes the tuple (from above) and the table id
    - Now, if `process_already_exists? == true`, we can just return the PID and go look up the table server
    - But, if the process did not exist, **we want to check if the table is in the database** (our edge case from above!)
    - `table_lookup` is the persistence method we injected, if it returns a row, we have our table! We can start a server process with it, just like if we were given a brand new table struct to create fresh!
        - NOTE: if there is no row, then we know for sure the game never existed

That's it! So we've accomplished state recovery, and we implemented it in such a way that:

1. It imposes no overhead on application startup
    - Basically, we lazy load tables as they are requested
2. It minimizes the proliferation of persistence methods, by relying on the fact that you have to _view_ a game before doing anything to it.
    - NOTE: if a user did manage to issue an "add player" command to a table that crashed, it would return an internal server error. To fix that, we could either:
      1. Inject the "get-or-create" behavior before *every* action handler in the core.
      2. Return a redirect to the `view_game` page, which would either:
          - start the game if it *does* exist (and we could flash a message to try again)
          - return a true 404 if the game really never existed
      
      (2.) has the nice property of keeping our persistence out of the core as much as possible.
    

# V2 In Production

Rewriting this small application is probably one of the most satisfying coding projects I've ever completed. The OTP is so incredibly powerful, and my comfort level with `GenServer` is much better than before. I have a better understanding of how Phoenix works, and what it means to define things like "child spec", or a "supervision strategy".

With that said, I want to acknowledge that an application like this really has _no need_ to be a "true" OTP application. The v1 and v2 applications work just as well, and this little hobby project will never see anything close to "internet scale" traffic. I was also able to implement v1 in about half the time it took to write v2. This was a learning exercise, and I hope it might help others feel more confident approaching OTP.

Bullion is available for all to use!

- Try it out here: https://poker.tylerkontra.com
- You can also try v1 here: https://poker.tylerkontra.com/legacy
- It's also open source! https://github.com/ttymck/bullion

### Acknowledgement

I also want to highlight the book I mentioned above: [Functional Web Development with Elixir, OTP, and Phoenix](https://pragprog.com/titles/lhelph/functional-web-development-with-elixir-otp-and-phoenix/). I really think it's an excellent bridge to take you from "Phoenix is your application" to the world of "[Phoenix is not your application](https://elixirforum.com/t/what-do-they-actually-mean-when-they-say-phoenix-is-not-your-application/11743)". This post is basically a summary of my journey reading that book and "translating" its instructions to rewrite my own application.

I should also clarify that I've tossed around the term "true OTP" app, which is not a real thing as far as I know. I simply mean an app that makes use of Supervision trees and `GenServer` to manage its state. Please interpret my use of "true OTP" as a kludge, or -- if you prefer -- as tongue in cheek. I don't claim that Bullion represents any sort of ideal application (not in architecture, performance, etc.).

As always, if there's something that stood out to you in this post, or something you'd like to see me write about next, I'd love to hear about it: [tyler@tylerkontra.com](mailto:tyler@tylerkontra.com) -- definitely let me know if you use the app for one of your poker nights! Keep in mind it doesn't come with a warranty ;)

Thanks for reading. Until next time -





