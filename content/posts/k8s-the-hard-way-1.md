---
title: "[draft] Kubernetes The Hard Way - Part 1"
subtitle: "Labs 1-3"
date: 2019-10-21T15:45:02-07:00
draft: true
---

# Building a Kubernetes Cluster From Scratch

## Why the Hard Way?

"Kubernetes the hard way? But Tyler, there's [EKS](https://aws.amazon.com/eks/), [GKE](https://cloud.google.com/kubernetes-engine/), [Digital Ocean](https://www.digitalocean.com/products/kubernetes/) and a myriad of other options to get up and running with Kubernetes!"

You my friend are correct: anyone can spin up an EKS cluster. But Kubernetes is so valuable because it hides _so_ **much** _**complexity**_. That's what we're after here.

Kubernetes hides a gnarly web of compute, storage, scheduling, configuration and most nebulously: **networking**.

And when I came across [Kelsey Hightower's](https://github.com/kelseyhightower) _[Kubernetes The Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way)_ packaged all neat and tidy in a git clone-able tutorial format, I knew I had to throw down the gauntlet, as it were.

## Roadmap To Success

Hightower presents us with an approachable lesson plan of 14 "labs":

1. Prerequisites
1. Installing the Client Tools
1. Provisioning Compute Resources
1. Provisioning the CA and Generating TLS Certificates
1. Generating Kubernetes Configuration Files for Authentication
1. Generating the Data Encryption Config and Key
1. Bootstrapping the etcd Cluster
1. Bootstrapping the Kubernetes Control Plane
1. Bootstrapping the Kubernetes Worker Nodes
1. Configuring kubectl for Remote Access
1. Provisioning Pod Network Routes
1. Deploying the DNS Cluster Add-on
1. Smoke Test
1. Cleaning Up

In the first part of this series, we'll cover the first 3 labs.

## Up and Running: Labs 1 and 2

#### GCloud SDK
First step was to make sure my google cloud CLI was up to date. I should've known nothing would be so simple...

Running 
`gcloud version` 
showed I had version `257` installed. After wrestling with `apt-get` for a bit, I had gcloud version `267` ready to go.

#### GCP Project

It's not mentioned in the lab, but I went ahead and created a blank GCP project, calling it `k8s-thw`.

![GCP - Project](/images/k8s-thw-p1/gcp-project.png)


#### CLI Tools

After installing `cfssl[json]` via the tutorial links and kubectl via `apt-get`, I was ready to start spinning up GCP resources.


## Provisioning Compute Resources: Lab 3

The next step was to get my terminal pointed at the right GCP project and region. A quick invocation of `gcloud init` took care of it.

### VPC

The tutorial instructs one to create a VPC like so

`gcloud compute networks create kubernetes-the-hard-way --subnet-mode custom`

which would create a VPC having the cumbersome name `kubernetes-the-hard-way`. I chose to be a bit more concise, and a bit more specific name of `k8s-vpc-1`. For the uninitiated, ["k8s" is the "i18n" version of k(ubernete)s.](https://medium.com/@rothgar/why-kubernetes-is-abbreviated-k8s-905289405a3c)

### Subnet

In the previous step, we selected `custom` subnet mode for our vpc.

Now we establish said subnet. We're instructed to name the subnet, you guessed it: `kubernetes-the-hard-way`. This time I chose to use, `k8s-subnet-1` (I hope you're seeing a pattern).

We're also instructed to provision the subnet as `10.240.0.0/24`. This [CIDR](https://en.wikipedia.org/wiki/Classless_Inter-Domain_Routing) leaves an 8 bit subnet, for a maximum of 254 hosts. 

Now, I realize this is all an exercise in "let's do this because it's difficult" and not "let's build a production kubernetes cluster", but if I am going to get my personal cluster up-and-running, I want the ability to scale it up and down. Bottom line, 254 hosts didn't excite me.

I chose to provision `10.0.0.0/16`, for a capacious maximum 65,536+ host limit. Far more instances than I ever anticipate I could afford to provision for more than a few minutes.

### Firewalls

#### Internal Traffic

The next step is to poke the right holes in our VPC firewall.

We allow TCP, UDP and ICMP (for `ping`, as far as I know) from any address internal to the network. 

```
tmck-debian devel/kubernetes-the-hard-way ‹master*› » gcloud compute firewall-rules create k8s-allow-internal --allow tcp,udp,icmp --network k8s-vpc-1 --source-ranges 10.0.0.0/16         
Creating firewall...⠹Created [https://www.googleapis.com/compute/v1/projects/<redacted>/global/firewalls/k8s-allow-internal].
Creating firewall...done.                                                                        
NAME                NETWORK    DIRECTION  PRIORITY  ALLOW         DENY  DISABLED
k8s-allow-internal  k8s-vpc-1  INGRESS    1000      tcp,udp,icmp        False
```

Curiously, Hightower declares two `source-ranges`: the subnet we declared prior, and this second `10.200.0.0/16` range. It's not clear at this point what this source range is referring to, so I left it out...

#### External Traffic

Next we allow SSH (tcp 22), HTTPS (tcp...6443?...), and ICMP from *all* external hosts. 

```
tmck-debian devel/kubernetes-the-hard-way ‹master*› » gcloud compute firewall-rules create k8s-allow-external --allow tcp:22,tcp:6443,icmp --network k8s-vpc-1 --source-ranges 0.0.0.0/0
Creating firewall...⠛Created [https://www.googleapis.com/compute/v1/projects/<redacted>/global/firewalls/k8s-allow-external].
Creating firewall...done.                                                                        
NAME                NETWORK    DIRECTION  PRIORITY  ALLOW                 DENY  DISABLED
k8s-allow-external  k8s-vpc-1  INGRESS    1000      tcp:22,tcp:6443,icmp        False
```

![GCP Console - Firewalls](/images/k8s-thw-p1/firewalls-screencap.png)

### Load Balancer IP

We'll need an external IP address for an internet gateway: `k8s-ip-1`, assigned by google.

```
tmck-debian devel/kubernetes-the-hard-way ‹master*› » gcloud compute addresses create k8s-ip-1 --region $(gcloud config get-value compute/region)
Created [https://www.googleapis.com/compute/v1/projects/<redacted>.
```

and list it back:

```
tmck-debian devel/kubernetes-the-hard-way ‹master*› » gcloud compute addresses list --filter="name=('k8s-ip-1')" 
NAME      ADDRESS/RANGE  TYPE      PURPOSE  NETWORK  REGION    SUBNET  STATUS
k8s-ip-1  <redacted>     EXTERNAL                    us-west1          RESERVED
```

### Instances

### Control Plane

The lab continues with our first taste of kubernetes proper: VM instance provisioning.

We start with the kubernetes controllers, three of them. Hightower uses the term `controllers`, but I chose to use `master`, as prescribed by the [official kubernetes docs](https://kubernetes.io/docs/concepts/overview/components/#master-components).

In any case, I quickly mulled over what operating system to use. Should I go with the suggested Ubuntu 18 LTS? Or something sexier, like CoreOS or RancherOS. I reached a quick decision, opting for familiarity in Ubuntu 18 LTS.

It was also at this point that I got to decide how to use my plentiful subnet real estate! I chose to deploy the control plane to `10.0.1.0/24`. In fact, I tried to start with `10.0.0.0/24`, but was bitten by reserved IP addressed `10.0.0.1-2`, which surfaced as `master-0` and `master-1` failing to create!

```
tmck-debian devel/kubernetes-the-hard-way ‹master*› » source create-controllers.sh
...
tmck-debian devel/kubernetes-the-hard-way ‹master*› » gcloud compute operations describe https://www.googleapis.com/compute/v1/projects/<redacted>
endTime: '2019-10-17T18:29:00.274-07:00'
error:
  errors:
  - code: IP_IN_USE_BY_ANOTHER_RESOURCE
    message: "IP '10.0.0.0' is already being used by another 
...
```

After quickly debugging (`gcloud compute operations describe` above), I deployed to the next 8 bit CIDR range, and everything looked rosy in the console.

### Worker Plane

Now we get to provision the [nodes](https://kubernetes.io/docs/concepts/architecture/nodes/).!

It's here that we are made aware of the purpose of the secondary firewall CIDR (given in the tutorial as `10.200.0.0/16`.

This CIDR is Hightower's "cluster CIDR", the IP range for all the **pod** subnets: the containers that are spawned by our applications (docker containers). The lab informs us that a 16 bit cluster subnet (above) can support 254 pod subnets (suggesting 8 bit subnets).

My cluster CIDR is `10.1.0.0/16` which is the next sequential 16 bit subnet, completely avoiding the instance subnet address space, but having the tidy attribute of being sequential to it!

When creating a node, the pod subnet is given by the `--metadata pod-cidr={cidr}` flag.

For the actual *node* IP addresses: I started with the next sequential 24 bit mask: `10.0.2.0/24`.

Using the same physical octet for master and node addresses, but using the _tens_ place of that octet felt ugly and untidy. Using separate CIDRs satisfied my OCD nicely.

Checking the console, we can see all our instances listed!

![GCP Console - Compute Instances](/images/k8s-thw-p1/compute-instances.png)

## Up Next: A Taste of TLS

That takes care of our compute! Our next step will be to set up our own certificate authority to distribute TLS certificates.

We'll also tackle kubernetes configuration files (kubeconfigs) to get our cluster talking to each other.

But that's for another day. This is the hard way, not the fast way; see you next time!
