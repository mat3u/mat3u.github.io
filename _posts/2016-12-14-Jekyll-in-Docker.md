---
title: "Jekyll in Docker"
categories: [Jekyll, Docker]
date: 2016-12-14 19:23
---

I honestly hate when my operating system is bloated with tons of unnecessary stuff. I was always scared to look at the list of installed apps on the brand new laptop. One of the apps that I was installing all the time and used it only rarely for blogging was Ruby and Jekyll. I'm not a Ruby developer and I'm not using it for anything else than blogging so I've decided to not installing it but still being able to write some posts (even if it is two in a year ;).

I've decided to use [Docker](https://www.docker.com/) to solve my problem. If you don't know what Docker actually is there is a great introduction in official documentation.

<!--more-->

I'm using [Jekyll](https://jekyllrb.com/) to compile and serve it in my local environment. So there are basically two problems to solve:

* Compile - I have to deliver sources to running docker
* Serve - I have to have access to port exposed by Jekyll

Both problems can be easily solved using docker. First of all, I had to run Jekyll inside of the docker and there are two paths to solve such issue. In first approach, I can create `Dockerfile` by myself on top of some existing image and install Ruby, Jekyll, Nodejs, Python (for older versions I guess) and other stuff. The second approach is to use docker image prepared by someone else. Luckily, Jekyll's maintainers are providing such image. It is build on top of [alpine image](https://hub.docker.com/_/alpine/) which is a minimal docker image that weights only 5MB and this is cool. I know that Ruby and other stuff will take a lot of megs but still is better to start with 5MB than 200MB.

Having this [docker image](https://hub.docker.com/r/jekyll/jekyll/) we can compile blog inside of it. To do this we need to run following command:

```bash
docker run -v /home/mat3u/Blog:/srv/jekyll jekyll/jekyll
```

This command should run docker with Jekyll and blog mounted where it should be. The parameter `-v /home/mat3u/Blog:/srv/jekyll` means that I want to mount my local directory `/home/mat3u/Blog` inside of running container at `/srv/jekyll` path. This `/srv/jekyll` path was arbitrary chosen work directory by the creators of this image. It can be changed when running container.

![Docker running](/assets/posts/Docker_Jekyll/01.png)

As you can see I did some changes in the post and Jekyll automatically regenerated content, so I guess everything is working as expected. But when I'll try to access `http://localhost:4000` I'll get information that no one is listening on this port. This is because this port is exposed on running container on my machine. As every running docker container obtains their own IP address and we can use it to access served page. To check the IP you can use the following command:

```bash
{% raw %}
docker inspect -f "{{ .NetworkSettings.IPAddress }}" <ContainerID>
{% endraw %}
```

But this is very inconvenient, so it is simpler to bind the port from docker to `localhost`. To do so we need to modify slightly the original command:

```bash
docker run -p 8000:4000 -v /home/mat3u/Blog:/srv/jekyll jekyll/jekyll
```

This `-p 8000:4000` means that I want my local port 8000 to points to port 4000 of the running container. After executing this command we should be able to open [`http://localhost:8000`](http://localhost:8000).

Basically, that is all that is needed to effectively work with Jekyll without bloating our system. To simplify my life and not write this command every time I'm working on my blog (even if it is not very often) I'll wrap it up into the script and put it in `~/.bin/jekyll`. Here is the script:

```bash
#!/usr/bin/env bash

PORT=${PORT:-8000}
WORKDIR=${WORKDIR:-`pwd`}

trap 'docker rm -f jekyll' SIGINT
docker run --name jekyll -p ${PORT}:4000 -v ${WORKDIR}:/srv/jekyll jekyll/jekyll
```

I've added the name for the running docker so I'll be able to clean it up with `SIGINT`.

In described way, you can remove from your system many unnecessary applications and dependencies (including graphical ones).
