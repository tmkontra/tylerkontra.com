+++ 
draft = true
date = 2020-07-05T18:36:45-07:00
title = "Deploying Elixir Phoenix with Docker Compose"
description = "Using the power of docker-compose to simplify Phoenix deployments"
slug = "" 
tags = []
categories = []
+++

I'm in the process of improving my personal cloud deployments; as I previously wrote about, I recently [converted my server configuration]({{< relref "ansible-personal-vps.md" >}}) from ad-hoc scripts to Ansible playbooks. Today I'm writing about the next step in that journey: converting "banker", an Elixir Phoenix app ([poker.tylerkontra.com](http://poker.tylerkontra.com)), to a docker-compose deployment.


### The Old Way

Banker is a fairly simple 3 tier web application, a phoenix backend, some static front-end assets, and a PostgreSQL database. Before I started dockerizing it, banker was deployed on a Linux VPS, using the basic Phoenix server command directly on the machine:

```
PORT=4001 MIX_ENV=prod elixir --erl "-detached" -S mix phx.server
```

This meant I need to build the app on the server before starting it, using a bash script that you can [see here](https://github.com/ttymck/bullion/blob/0.1.0/deploy.sh). This was both tedious and uninteresting (in my humble opinion); I love using Docker, I think it's table stakes for any cloud deployments in 2020 -- let's see how it can be used with Phoenix.


### The New Way

#### Buildtime Configuration

The Phoenix framework relies on the "Mix" build tool. Mix builds your application using config files, [like this one](https://github.com/ttymck/bullion/blob/0.1.0/bullion/config/prod.secret.exs). But there's a drawback to putting configuration in these `.exs` files: enviroment variables are captured at build time, not run time. So environment variables like:

```
secret_key_base =
  System.get_env("SECRET_KEY_BASE") ||
    raise """
    environment variable SECRET_KEY_BASE is missing.
    You can generate one by calling: mix phx.gen.secret
    """
```

are evaluated when you build your appliation (`mix compile`) and not when you start the server (`mix phx.server`). This poses an issue for building a single docker image, and using it for local development _and_ production. There are a number of configuration differences between local/testing and production:

1. `DATABASE_URL`, our database connection string
2. `SECRET_KEY_BASE`, a secret string for application security
3. `config.url`, the server url, used by Phoenix to generate links (i.e. `localhost:4000` locally and `http://poker.tylerkontra.com` in production)

...and more

So it's clear we will need to be mindful of how we define our build toolchain, and make it flexible enough to accomodate Phoenix's unique constraints.

#### Runtime Database URL

I started by converting the database URL to runtime evaluation -- it was the only config value I had a simple solution for.

Instead of evaluating `DATABASE_URL` in a `.exs` script, I moved it to the [`Bullion.Repo.init/2`](https://github.com/ttymck/bullion/blob/master/bullion/lib/bullion/repo.ex#L6) method call, which can modify the compiled config.

#### Docker Build

Next up, I decided to add the more stubborn build parameters to the `docker build` step, so at least we can use docker images as our build artifact consistently across development and production, but parameterize the image build.

I abstracted the `MIX_ENV` and `SECRET_KEY_BASE` environment variables, and parameterized the `mix deps.get` build step to take an optional argument, which is `--only prod` when building a production image (meaning, only install the production dependencies -- i.e. no hot reloading).

### Docker Compose


#### Local Dev

I was now able to define a `docker-compose.yaml` that fully specifies the stack:


```
version: "3"

services:
  web:
    build: 
      context: .
      args:
        mix_env: dev
    image: "bullion:0.1.0.dev"
    ports:
      - "4000:4000"
    environment:
      - PORT=4000
      - DATABASE_URL=postgresql://postgres:postgres@db/bullion
  db:
    image: "postgres:12"
    container_name: "bullion-db"
    environment:
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=postgres
      - POSTGRES_DB=bullion
    expose:
      - "5432"
```

The above file is sufficient for local development, and will be overriden for production builds.

The only build arg we need to set is `mix_env` because 

1. `SECRET_KEY_BASE` is hard coded in `config.dev.exs`
2. we don't want to pass `--only prod` to the dependency installation step (since we will want hot reloading in dev).

#### Production

Now, the great thing about Docker Compose is the ability to set overrides for a `docker-compose.yaml`, which I do in `docker-compose.prod.yaml`:

```
version: "3"

services:
  web:
    build: 
      args:
        mix_env: prod
        secret_key: ${SECRET_KEY}
        deps_postfix: "--only prod"
    image: "bullion:0.1.0"
    ports:
      - "4001:4001"
    environment:
      - PORT=4001
      - DATABASE_URL=postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@db/${POSTGRES_DB}
  db:
    environment:
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - POSTGRES_DB=${POSTGRES_DB}
    volumes:
      - bullion-db:/var/lib/postgresql/data
volumes:
  bullion-db:
    driver: local
```

The key points:

1. All three build args are specified
2. `SECRET_KEY` is pulled in from the environment of the `docker-compose` shell at build time, so I just put it in a `.env` file, and `docker-compose` does the rest. 
    - The same pattern is used for `DATABASE_URL` which is constructed from the environment variables that the postgres container uses to configure itself.
4. The `db` service now has a volume specified: `bullion-db`. This is the beautiful feature of docker that supports stateful applications: `bullion-db` will be saved to the host filesystem and will persist between container restarts.

The development (base) `docker-compose.yaml` also builds tags web image as `X.Y.Z.dev`, to avoid collisions when building the production image.


### Deploying

To build a production image, I can now run the following command on any machine (with an environment containing `SECRET_KEY`):

```
docker-compose -f docker-compose.yaml -f docker-compose.prod.yaml build
```

Using a docker registry (Docker Hub) is overkill for this project, and would be ill-advised since the image contains secrets (`$SECRET_KEY`). So I choose to upload the image directly to my server:

```
docker save bullion:0.1.0 | bzip2 | pv | ssh tylerkontra.com 'bunzip2 | docker load'
```

This is a great way to avoid using registries, but **be warned**: using `docker save` is almost always _much_ slower than using `docker push` because it cannot take advantage of layer caching -- it always saves the whole image, resulting in a much more data to transfer.

Now that the production image is available on the server, all that's left to do is fire it up. For this I'll need the docker-compose*.yamls, and the .env file.

I rsync those up to the server:

```
rsync --files-from=rsync-files.txt . tylerkontra.com:~/bullion/
```

(`--files-from` is a useful option I learned about today, it let's me send just the three files I need, which are listed in [`rsync-files.txt`](https://github.com/ttymck/bullion/blob/0.1.0/rsync-files.txt))

Now on the server:

```
tmck@tylerkontra-com ~/bullion » docker-compose -f docker-compose.yaml -f docker-compose.prod.yaml up -d
```

And the app is running! 

But there's still one more thing left to do.

Since the original deployment was using a postgres database installed directly on the machine, but the docker deployment defined it's own data volume, the app data from before the docker deployment would be lost. The quick fix for this is:

```
pg_dump $POSTGRES_DB > banker-$(date +"%y-%m-%d").sql
```

And with the dockerized postgres instance exposed available at port 54320:

```
psql -U $POSTGRES_USER -W -h 127.0.0.1 -p 54320 $POSTGRES_DB < banker-YY-MM-DD.sql
```

Now the application is fully migrated to docker. 

### TODOs

So I accomplished (most of) what I set out to accomplish: when you visit [poker.tylerkontra.com](http://poker.tylerkontra.com) you're now interacting with a Docker Compose stack.

But there are a few key improvements I will want to make:

1. Expose the static assets in the `web` container as a docker volume, and add an `nginx` reverse proxy that will serve files directly from that volume -- reducing unecessary load on the erlang VM which should be handling application logic, not serving static files.

2. Spin up a private docker registry on my `tylerkontra.com` server so I can `push` and `pull` the production images, taking advantage of layer caching for faster transfers, while avoiding security concerns of Docker Hub.

Not to mention the numerous [application features and UI improvements](https://github.com/ttymck/bullion/tree/0.1.0#roadmap) I want to make.

Thanks for reading. Until next time --
