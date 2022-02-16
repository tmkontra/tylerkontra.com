---
title: "No Nonsense Python Dependency Management In 2020"
subtitle: "The simplest way to develop multiple Python applications at once"
date: 2020-06-15T17:57:48-07:00
draft: false
---


### Untangling The Web of Python

Surely by now, if you've worked with python 3 at all, you've seen [this](https://xkcd.com/1987/) xkcd.

![](https://imgs.xkcd.com/comics/python_environment.png)

That comic may be from [2018](https://www.explainxkcd.com/wiki/index.php/List_of_all_comics_(1501-2000)) but it feels as though the python community has fit a decades' worth of improvement in the intervening 2 years.

Unmentioned in the comic are the heavyweights [pyenv](https://github.com/pyenv/pyenv), [pipenv](https://pipenv.pypa.io/en/latest/), and [poetry](https://python-poetry.org/). Not to mention niche offerings like [hatch](https://github.com/ofek/hatch), [pew](https://github.com/berdario/pew), and [pipx](https://github.com/pipxproject/pipx), among others.

When newcomers arrive at the python-promised-land, they often come to me saying: 

> "Tyler! What is going on?? pyenv? pipenv? poetry? virtualenv? virtualenvwrapper? What are all these things. Why can't I just use pip?"

And more often than not my response is the **no-nonsense** version of what **you *need* to know** about python environments.

### Dependency Management vs Package Publishing

First let's talk about the two major tasks involved in building a python application. 

#### Dependencies

First, there's **dependency management**. This is the task (read: art) of selecting and importing published libraries/packages into your own python project. A common example of this is the [requests](https://requests.readthedocs.io/en/master/) package. You may want to import requests and use it in your own code, like so:

{{< highlight python >}}
# my-awesome-app.py
import requests

def my_useful_function():
  response = requests.get("https://useful-website.com/api/data")
  return response.json()
{{< / highlight >}}

This means `requests` is now a _dependency_ of your application.

#### Publishing

Maybe your python application is meant to be installed by users. In this case, you want to make it available on pypi so anyone can download it from there using the tools we're discussing today. You could say you want to **publish** your app.

Publishing is the task of _packaging_ your project and creating a _distribution_. What that looks like is unfortunately *not* the subject of today's discussion. If you're interested, the [official docs](https://packaging.python.org/tutorials/packaging-projects/) are the best place to get started, and maybe I'll wrote a post about it in the future -- let me know if you'd like to see that!

### The Crux of Dependency Management

**NOTE**: If you know what virtual environments are, and why you need them, feel free to skip to the next section. If you're curious, continue reading.

Now that we know what dependency management is what we want to do, you may be asking -- why is it hard? "Can't I just `pip install` all my packages?". 

You _could_. But here's why that gets messy.

Say you are working on one project, and you need Django 3.0.7. You just `pip install django` and it gives you the latest version, no problem!

{{< highlight bash >}}
[20:00:20] tmck:my-app $ python -c "import django; print(django.__version__)"
3.0.7
{{< / highlight >}}

But now your friend shares their python project with you, and it requires Django 2.0.5! So you try installing that version:

{{< highlight bash >}}
[20:00:24] tmck:joes-app $ pip install django==2.0.5
Collecting django==2.0.5
  Downloading https://files.pythonhosted.org/packages/23/91/2245462e57798e9251de87c88b2b8f996d10ddcb68206a8a020561ef7bd3/Django-2.0.5-py3-none-any.whl (7.1MB)
     |████████████████████████████████| 7.1MB 3.2MB/s 
Installing collected packages: django
  Found existing installation: Django 3.0.7
    Uninstalling Django-3.0.7:
      Successfully uninstalled Django-3.0.7
Successfully installed django-2.0.5
[20:00:44] tmck:joes-app $
{{< / highlight >}}

Uh oh! You've just uninstalled 3.0.7 for 2.0.5 -- every time you want to work on one project or the other, you need to re-install the correct Django version! That could get messy!

This is where [virtual environments](https://docs.python.org/3/tutorial/venv.html) come in. We'll use a similar example in the following sections to illustrate the common task of dependency management.


### Down to Business

So you need to manage dependencies? Let's say you're working on 2 projects right now:

1. A library built for python 3.7+, using requests 2.23.0 (latest)
2. A command line application built for python3.5+, using requests 1.2.3 (an old version)

You'll of course want to run your tests against the proper python version and dependency (requests) version, and you want to have them all installed on your personal machine at the same time. How to do this, you ask?

You don't need to get bogged down in pip vs virtualenv vs pipenv vs poetry. Let's be reasonable. We need to:

1. install python3.5 and python3.7 in separate locations
2. install two versions of requests in separate locations
3. point each project at the right combination of both

Luckily, there's only two tools we need:

pyenv & pipenv

pipenv is [endorsed by](https://packaging.python.org/guides/tool-recommendations/) the PyPA (Python Packaging Authority) and pyenv is transitively endorsed by pipenv (because it works cooperatively when both are installed, as we will see later).

### pyenv

pyenv let's you install _any_ (and I mean ***any***) version of python, and install multiple on the same machine at the same time, and let's you swap between them on the fly.

For ruby users, the equivalent is [rbenv](https://github.com/rbenv/rbenv), and JVM users may have used [jEnv](https://www.jenv.be/).

The best way to install pyenv is through the [official installer](https://github.com/pyenv/pyenv-installer). 

Once it's installed, all you have to do is run 

```bash
pyenv install 3.7.7
```

Now the patch version here **is important**. You need to fully specify the version you want. Luckily, pyenv can quickly tell you all the versions that are available using 

```bash
pyenv install --list
```

There are A LOT of versions! We are currently only interested in CPython (the python you are probably familiar with). You can filter down to just those with this:

```bash
pyenv install --list | grep -e "^\s*[0-9]"
```

Now we have pyenv ready to go, let's move on to pipenv, and see how they work together!

### pipenv

Pipenv is a dependency manager for python. It does the work of `pip`, `virtualenv` (and `virtualenvwrapper`), and can even use `pyenv` behind the scenes.

The best way to install pipenv is simply by using pip, which should be available already if you have any python version installed.

```bash
pip install --user pipenv
```

Let's start with setting up our first project, a library using python3.7.

We'll make sure we are in the project root:

```bash
[19:18:47] tmck:devel $ cd my-py-library
```
Then we initialize this project's virtual environment:

```bash
[19:18:49] tmck:my-py-library $ pipenv install --python 3.7 requests==2.23.0
```

This tells pipenv both with _python_ version we need, and our _depdendency_ (requests) with a manually specified version (2.23.0)!

You should see output like the following:

```bash
[19:18:49] tmck:my-py-library $ pipenv install --python=3.7 requests==2.23.0
Creating a Pipfile for this project…
Installing requests==2.23.0…
Adding requests to Pipfile's [packages]…
✔ Installation Succeeded 
Pipfile.lock not found, creating…
Locking [dev-packages] dependencies…
Locking [packages] dependencies…
Building requirements...
Resolving dependencies...
✔ Success! 
Updated Pipfile.lock (21871e)!
Installing dependencies from Pipfile.lock (21871e)…
  🐍   ▉▉▉▉▉▉▉▉▉▉▉▉▉▉▉▉▉▉▉▉▉▉▉▉▉▉▉▉▉▉▉▉ 5/5 — 00:00:
```

And you'll have a Pipfile in your working directory that looks like:

```bash
[19:19:45] tmck:my-py-library $ cat Pipfile
[[source]]
name = "pypi"
url = "https://pypi.org/simple"
verify_ssl = true

[dev-packages]

[packages]
requests = "==2.23.0"

[requires]
python_version = "3.7"
```

Now, you can run your project using the correct versions of both python and your dependencies. 

You can either enter a shell session in the virtual environment pipenv has created: 

```bash
[19:24:04] tmck:my-py-library $ pipenv shell
Launching subshell in virtual environment…
 . /Users/tmck/.local/share/virtualenvs/my-py-library-QTe9bKSB/bin/activate
[19:24:06] tmck:my-py-library $  . /Users/tmck/.local/share/virtualenvs/my-py-library-QTe9bKSB/bin/activate
(my-py-library) [19:24:06] tmck:my-py-library $
```

Or you can run specific commands using `pipenv run`:

```bash
[19:22:07] tmck:my-py-library $ pipenv run python -c "import requests; print(requests.__version__)"
2.23.0
```

Let's move on to our second project, to see where lies the real value of this tooling.

#### The Power of Virtualenvs!

So now we try to initialize our second project:

```bash
[19:39:20] tmck:my-py-cli $ pipenv install --python 3.5 requests==1.2.3
Warning: Python 3.5 was not found on your system…
Would you like us to install CPython 3.5.9 with Pyenv? [Y/n]: Y
```

And look at that! Pipenv couldn't find the right python interpreter, so it offered to install it for us using pyenv!

Enter `Y` and you should see:

```bash
Installing CPython 3.5.9 with /usr/local/bin/pyenv (this may take a few minutes)…
⠋ Installing python...
```

Which may take a while (30+ minutes depending on your individual machine performance). 

Once it's done, it will follow up by installing requests:

```bash
Installing CPython 3.5.9 with /usr/local/bin/pyenv (this may take a few minutes)…
✔ Success! 
python-build: use openssl@1.1 from homebrew
python-build: use readline from homebrew
Downloading Python-3.5.9.tar.xz...
-> https://www.python.org/ftp/python/3.5.9/Python-3.5.9.tar.xz
Installing Python-3.5.9...
python-build: use readline from homebrew
python-build: use zlib from xcode sdk
Installed Python-3.5.9 to /Users/tmck/.pyenv/versions/3.5.9


Creating a virtualenv for this project…
Pipfile: /Users/tmck/devel/my-py-cli/Pipfile
Using /Users/tmck/.pyenv/versions/3.5.9/bin/python3.5m (3.5.9) to create virtualenv…
⠋ Creating virtual environment...created virtual environment CPython3.5.9.final.0-64 in 658ms
...

✔ Successfully created virtual environment! 
Virtualenv location: /Users/tmck/.local/share/virtualenvs/my-py-cli-VX8_6dRy
...
Installing requests==1.2.3…
Adding requests to Pipfile's [packages]…
✔ Installation Succeeded 
Pipfile.lock (a65489) out of date, updating to (018790)…
Locking [dev-packages] dependencies…
Locking [packages] dependencies…
Building requirements...
Resolving dependencies...
✔ Success! 
Updated Pipfile.lock (018790)!
Installing dependencies from Pipfile.lock (018790)…
  🐍   ▉▉▉▉▉▉▉▉▉▉▉▉▉▉▉▉▉▉▉▉▉▉▉▉▉▉▉▉▉▉▉▉ 0/0 — 00:00:00
To activate this project's virtualenv, run pipenv shell.
Alternatively, run a command inside the virtualenv with pipenv run.
```

And you're all set!

```bash
[19:50:52] tmck:my-py-cli $ pipenv run python -c 'import sys, requests; print("python", sys.version); print("requests", requests.__version__)'
python 3.5.9 (default, Jun 15 2020, 19:40:59) 
[GCC 4.2.1 Compatible Apple LLVM 10.0.1 (clang-1001.0.46.4)]
requests 1.2.3
```

### Keeping It Simple

That's all it takes to have highly-usable, highly-flexible python dependency management. You can share your projects with others, and when they cd into the project root, where the `Pipfile` is located, all they have to do is run `pipenv install` and pyenv + pipenv will take care of the rest.

pyenv + pipenv are my _official_ recommendations for python tooling in 2020, which should be no surprise, since it's also the official combination recommended by the PyPA. But it's easy to get lost and confused among many conflicting suggestions and opinions! If you just need to keep it simple and get down to business, you can't go wrong with pyenv + pipenv. 
