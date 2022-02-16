---
title: "Repeatable VPS Configuration with Ansible"
description: "Treating your servers like cattle, not pets, with automation"
date: 2020-07-02T20:28:24-07:00
draft: false
---

I host a number of websites, applications and other projects on the web: for example, this blog you're reading (Hugo), [keyringnow.com](keyringnow.com) (a Flask app) and [poker.tylerkontra.com](https://poker.tylerkontra.com/) (Elixir Phoenix app) are all hosted on the same server. For these sorts of things, I prefer to use a virtual private server (VPS), which gives me a full Linux installation to configure however I wish. My preferred hosting provider is [Digital Ocean](https://m.do.co/c/f5e9f6a309a8) (referral link); their web interface is slick and intuitive, and their feature set and pricing is excellent (even though I only use their Droplets product -- VPS's).

Configuring applications on my server can range from setting up an NGINX virtual host to installing a new postgres instance. I usually manage these configurations by hand. In the interest of moving towards ["servers as cattle, not pets"](https://devops.stackexchange.com/questions/653/what-is-the-definition-of-cattle-not-pets), I decided to migrate my existing server setup to Ansible, a declarative server configuration management tool designed to make server setup reproducible and automated.

I started by remembering what my "initial setup" for an Ubuntu server is. I settled on the following tasks:

1. 	Create my `tmck` user with `sudo` acces
2. Add my SSH identity to `tmck`'s authorized keys.
3. Update and Upgrade all packages
4. Install and start the NGINX service
5. Install vim and git
6. Install zsh (and oh-my-zsh)
7. Install Hugo

### The Ansible Control Node

To use Ansible, you need a control node. This might usually be a sort of "bastion host" or operations node in your virtual private cloud, but for me, it's just my laptop.

After running `pipenv install ansible`, I have a local ansible workspace ready to go!

I create my Ansible inventory file, which is laughably small (and redacted):

```yaml
# ./inventory
[tylerkontra.com]
****.***.***.**
```

Then I start my playbooks directory with a short `ping` playbook.

```yaml
# ./playbooks/ping.yaml
---
- hosts: all
  become: false
  gather_facts: false

  tasks:
  - name: ping all hosts
    ping:
```

And then I can run the ping playbook to test connectivity:

```bash
ansible-playbook ./playbooks/ping.yaml -i inventory
```

And see the results!

```sh
PLAY [all] **********************************************************

TASK [ping all hosts] ***********************************************
ok: [192.241.160.72]

PLAY RECAP **********************************************************
192.241.160.72 : ok=1    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
```

### The Provision Playbook

Now that we know we're able to run playbooks against our inventory, let's build an "initial server setup" playbook: `provision.yaml`.

It'll look something like this:

```yaml
# ./playbooks/provision.yaml
---
- hosts: all
  become: false
  gather_facts: false
  remote_user: root
  vars:
    remote_password: "{{ lookup('env','REMOTE_PASS') | password_hash('sha512') }}"
    ssh_identity: "{{ lookup('file', lookup('env', 'IDENTITY') }}"
  tasks:
  - name: Disable password authentication for root
    lineinfile:
      path: /etc/ssh/sshd_config
      state: present
      regexp: '^#?PermitRootLogin'
      line: 'PermitRootLogin prohibit-password'
  - name: Install the `sudo` package
    package:
      name: sudo
      state: latest
  - name: Ensure wheel group is present
    group:
      name: wheel
      state: present
  - name: Ensure wheel group has sudo privileges
    lineinfile:
      dest: /etc/sudoers
      state: present
      regexp: "^%wheel"
      line: "%wheel ALL=(ALL:ALL) ALL"
      validate: "/usr/sbin/visudo -cf %s"
  - name: Create the non-root user account
    user:
      name: tmck
      password: "{{ remote_password }}"
      shell: /bin/bash
      update_password: on_create
      groups: wheel
      append: yes
  - name: Set authorized key for remote user
    authorized_key:
      user: "tmck"
      state: present
      key: "{{ ssh_identity }}"
  - name: Upgrading all packages
    apt:
      update_cache: yes
      upgrade: dist
  - name: ensure nginx is at the latest version
    apt: name=nginx state=latest
  - name: start nginx
    service:
        name: nginx
        state: started
  - name: Install a few more packages
    package:
      name: "{{item}}"
      state: present
    with_items:
    - vim
    - git
    - zsh
  - name: Check if hugo is installed
    command: dpkg-query -W hugo
    register: hugo_check_deb
    failed_when: hugo_check_deb.rc > 1
    changed_when: hugo_check_deb.rc == 1
  - name: Download hugo
    get_url: 
      url="https://github.com/gohugoio/hugo/releases/download/v0.73.0/hugo_extended_0.73.0_Linux-64bit.deb"
      dest="/var/tmp/hugo-0.73.0.deb"
    when: hugo_check_deb.rc == 1
  - name: Install hugo
    apt: deb="/var/tmp/hugo-0.73.0.deb"
    when: hugo_check_deb.rc == 1
```

(Don't forget to replace `tmck` with your desired remote user name)

Then all you have to do is run:

```bash
REMOTE_PASS=mypassword IDENTITY=~/.ssh/my_identity_file ansible-playbook ./playbooks/provision.yaml -i inventory
```

This will encrypt whatever password you set as `REMOTE_PASS` and use the SSH Identity File located at `IDENTITY`.

Some things to note:

1. This requires you have already configured ssh access to the remote hosts in your inventory. I recommend doing this via your `~/.ssh/config` file. DigitalOcean lets me specify an SSH credential when creating a VPS, any wortwhile cloud provider should do the same.
2. This disables password login for the root user (which in my opinion is just good security practice).
3. `sudo` privilege is allocated via the `wheel` group.
4. This playbook specifies a hard-coded Hugo version of [v0.73.0](https://github.com/gohugoio/hugo/releases/tag/v0.73.0) (the latest release at the time of writing).


### TODOs

That (relatively) simple playbook gets me a server ready to be accessed with my `tmck` identity and install whatever applications I wish! This will make it so much easier to spin up new Droplets (as I add more applications, I will want to spread the load across multiple instances). It will also make it easy to switch cloud providers, if I want to try VPSs from another vendor, because Ansible is vendor-agnostic -- this playbook will work on any Ubuntu/Deban machine I have access to!

However, I will want to improve on this playbook, primarily by utilizing "roles".

"Roles" are Ansible's way of grouping related tasks with their variables. For instance the sudo, wheel, and create user steps should be grouped into a `create_user` role, with a "username" and "password" variable scoped only to the role. 

Hugo will also get it's own role, likely with a "hugo-version" or "deb-url" variable to make the version parameterizable.

I will also want to start migrating my existing deployments to docker containers. Right now, my Python and Elixir apps are installed directly into the server's userspace. Even postgres is installed locally on the machine (I don't have enough traffic to require a managed postgres instance). Moving these to docker will make installations much simpler, and docker-compose will let me manage services without having to remember which process they were started with (systemctl? supervisor? nohup? screen?).

I'm looking forward to using Ansible to make all these changes immutably and in a repeatable fashion!





