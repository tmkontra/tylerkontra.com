+++ 
draft = false
date = 2020-07-26T19:07:45-07:00
title = "Deploy A Private Docker Registry"
description = "Using Cloudflare for HTTPS"
slug = "" 
tags = []
categories = []
+++


As I previously mentioned in my post on [deploying with docker-compose](/posts/elixir-phoenix-docker-compose/#deploying): I don't want to push my docker images to public DockerHub repos. My images aren't intended for public consumption and I don't want to worry about keeping secrets out of my images.

I finally got around to deploying a private docker registry, and luckily, the Docker development team has made it so incredibly easy. Deployment is so simple, because the registry server itself is actually a docker container. Talk about self-hosted.

Digital Ocean has an [excellent tutorial](https://www.digitalocean.com/community/tutorials/how-to-set-up-a-private-docker-registry-on-ubuntu-18-04) on deploying a docker registry, secured with HTTPS via Let's Encrypt. I deploy most of my applications on Ubuntu droplets (which the tutorial targets), but the steps should easily translate to any major Linux distribution.

It's nearly as simple as:

1. Create `/opt/docker-registry`
2. Create the `data` subdirectory
3. `docker-compose up -d` on the provided docker-compose.yaml
4. Reverse proxy the domain to the localhost port (nginx)
5. Add a docker login account using `htpasswd` from `apache2-utils`

### A Single Hiccup

The one issue I _did_ have was using Cloudflare for HTTPS, instead of Let's Encrypt/certbot.

After following the tutorial, I was able to log in just fine: 

```
docker login https://my.registry.com
```

No problem.

But when I tried pushing my first image to the registry, I got a cryptic error:

```
$ docker push my.registry.com/my-image
The push refers to repository [my.registry.com/my-image]
91a6f9ebe82c: Pushing  3.584kB
8a90669ee51d: Retrying in 3 seconds 
37ea6c8b75fa: Pushing  3.584kB
14f687b6870a: Pushing  4.096kB
a638f39e4bbd: Pushing  3.072kB
4f8672401053: Waiting 
3e207b409db3: Waiting 
unknown blob
```

After doing some digging (googling) I found a [stackoverflow answer](https://stackoverflow.com/questions/51508146/blob-unknown-when-pushing-to-custom-registry-through-apache-proxy) (praise be!) that pinned the issue on the nginx proxy configuration.

I changed this line:

```
proxy_set_header  X-Forwarded-Proto $scheme;
```

To this:

```
proxy_set_header  X-Forwarded-Proto https;
```

Since I use the "Flexible" Cloudflare encryption, I suspect the request nginx recieves is actually an http request, which was causing the docker registry service to reject the request. By hard-coding the `X-Forwarded-Proto` as https, I circumvent the issue.

Is it a security concern? Perhaps, but I'll accept that risk for now. Cloudflare is just so damn convenient.

**UPDATE - July 27:**

I managed to deploy SSL certificates to my nginx server -- I didn't realize Cloudflare let's you generate (non-root) CA Certs for your domains, or I would have done this much sooner! I just uploaded the `.pem` files and updated the nginx config: now all traffic on port 80 is `301` Redirected to `https`. I'm now using `Strict` SSL for my Cloudflare domains.


