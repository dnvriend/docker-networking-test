# docker-networking-test
A small project to understand [docker networking](https://docs.docker.com/engine/userguide/networking/dockernetworks/) that 
has been added in [Docker v1.9](https://github.com/docker/docker/blob/master/CHANGELOG.md#190-2015-11-03)

# Networking vs links
When we used links previously using docker, the only option to link containers together was to use links, but it has 
the following shortcomings:

1. Disrupting the link when a container is stopped, started or restarted,
2. Unable to link containers together across different hosts,
3. No need to use the 'ambassador' pattern to link containers together.

Let's get started.

# Installing docker, machine and compose
I use [brew](http://brew.sh/) on the mac to install docker, machine and compose. Just type the following to install them:

```bash
$ brew update && brew upgrade --all
$ brew install docker docker-machine docker-compose
```

Be sure to have the following minimum versions:

- docker: v1.9.0
- docker-machine: v0.5.0
- docker-compose: v1.5.0

# Single host networking example
When you have installed `docker v1.9`, for example using [brew](http://brew.sh/) you can get started right away using 
the new `docker-networking` feature with the new `docker network` command.

Let's create a new network `linux` with the command:

```bash
$ docker network create linux
```

This command creates a new network called `linux`. Let's inspect the network:

```bash
$ docker network inspect linux
[
    {
        "Name": "linux",
        "Id": "ca11e2f032bfbb262efc0ef9c759d8a6b13c02cdfd225d09b85e9d7e7ab64c9f",
        "Scope": "local",
        "Driver": "bridge",
        "IPAM": {
            "Driver": "default",
            "Config": [
                {}
            ]
        },
        "Containers": {},
        "Options": {}
    }
]
```

We can see it uses the `bridge` strategy and no `containers` are part of that network. Let's fix that. 

## Launching containers
We will launch two ubuntu containers and make them part of the `linux` network:

```bash
$ docker run -it --net=linux --name=ubuntu1 ubuntu
$ docker run -it --net=linux --name=ubuntu2 ubuntu
```

We have two running containers, let's inspect the network now:

```bash
$ docker network inspect linux
[
    {
        "Name": "linux",
        "Id": "ca11e2f032bfbb262efc0ef9c759d8a6b13c02cdfd225d09b85e9d7e7ab64c9f",
        "Scope": "local",
        "Driver": "bridge",
        "IPAM": {
            "Driver": "default",
            "Config": [
                {}
            ]
        },
        "Containers": {
            "87e89c70a74628585316ca99bc13d412dac2f24c892bfd376dcac89b0a27d429": {
                "EndpointID": "02e1297e65db1db80b275df53ebccb3871eb0fc1aff6ee5443b3bda843a07636",
                "MacAddress": "02:42:ac:12:00:02",
                "IPv4Address": "172.18.0.2/16",
                "IPv6Address": ""
            },
            "e388fa26947f9e0422b568a5fa649907b089ad7418482d65c671dcb3c0f4462a": {
                "EndpointID": "fd3e7343f0f475297fa9ba459e3182cb941be33683c0c80843d11b9233ccf7c3",
                "MacAddress": "02:42:ac:12:00:03",
                "IPv4Address": "172.18.0.3/16",
                "IPv6Address": ""
            }
        },
        "Options": {}
    }
]
```

When we cat `/etc/hosts` (the hosts file) on `ubuntu1` we see the following contents:

```bash
172.18.0.3	ubuntu2
172.18.0.3	ubuntu2.linux
```

and on `ubuntu2`:

```bash
172.18.0.2	ubuntu1
172.18.0.2	ubuntu1.linux
```

## Pinging the hosts
Let's ping `ubuntu2.linux` from `ubuntu1` and ping `ubuntu1.linux` from `ubuntu2` using the `ping ubuntu1.linux` 
and `ping ubuntu2.linux` command. 

We have created the following:

![Two containers and one network](https://github.com/dnvriend/docker-networking-test/blob/master/yed/local-two-containers.png)

Now lets add a new container `ubuntu3` to the network `linux` and cat the hosts file:

```bash
$ docker run -it --net=linux --name=ubuntu3 ubuntu
$ cat /etc/hosts
172.18.0.3	ubuntu2.linux
172.18.0.2	ubuntu1
172.18.0.2	ubuntu1.linux
172.18.0.3	ubuntu2
```

As you can see, the new container knows about the other ones, moreover, docker dynamically added the new container
to the hosts file of all other containers that are member of the network `linux`, and so when you cat the `/etc/hosts` 
file on the other containers, they also know about container `ubuntu3`. Let's ping `ubuntu3.linux` from `ubuntu1`. 

## Creating another network
Lets add another network `frontend` and launch an `ubuntu` container in that network:

```bash
$ docker network create frontend
$ docker run -it --net=frontend --name=ubuntu4 ubuntu
```

When you now inpect the network `linux` you only see 3 containers, that's because the fourth container is running in 
another network called `frontend`. When you cat the hosts file of container `ubuntu4`, you won't see the hosts from the 
`linux` network. You could try to ping `ubuntu4.frontend` but it won't work because the host is unknown. This is great, 
because we have complete isolation between the networks!

But say that we want to connect the `ubuntu4` container that is running in the `frontend` network to the `linux` network, 
how to we do that? Well, docker has the `docker network connect` command for that.  The purpose of the `connect` command 
is to connect a running `container` to another `network`, effectively making the container member of potentially multiple 
networks, let's try it:

```bash
$ docker network connect linux ubuntu4
```

When we now inspect the `linux` network with the command `docker network inspect linux`, we see that four containers are 
part of the `linux` network, and when we inspect the `frontend` network we see that only one container is part of the 
`frontend` network. Also note that the new container has been added to all hosts files of the containers that are member
of the `linux` network, so we can now ping the `ubuntu4.linux` host with the command `ping ubuntu4.linux` from eg. 
container `ubuntu1`, it works!

Note that we cannot do the following: `ping ubuntu4.frontend` because of a couple of reasons, the first and most obvious one, 
the hostname is not present in the hosts file of all containers that are member of the `linux` network, 
so that host name will be unknown. Secondly, the concept is that the `container` will be connected to a network, so `ubuntu4` 
is connected to `linux` and so the hostname is `ubuntu4.linux`. The `frontend` network is still fully isolated from any 
other networks, and that is what we want.

Lets add an `nginx` container to the `frontend` network:

```bash
$ docker run -itd --net=frontend --name=web nginx
```

When we inspect the `frontend` and `linux` networks, we see that we have `four` containers in the `linux` network and 
`two` containers in the `frontend` network. When we inspect the hosts file of container `ubuntu4` we see the following:

```
172.18.0.4	ubuntu3.linux
172.18.0.2	ubuntu1
172.18.0.2	ubuntu1.linux
172.18.0.3	ubuntu2
172.18.0.3	ubuntu2.linux
172.18.0.4	ubuntu3
172.19.0.3	web
172.19.0.3	web.frontend
```

The `ubuntu4` container can connect to all hosts because it is a member of both the `linux` and the `frontend` network. 

## Recap
We have created the following:

![two-networks-single-host](https://github.com/dnvriend/docker-networking-test/blob/master/yed/two-networks-single-host.png)

# Single host networking with docker-compose
Can we translate the configuration above to a docker-compose? Well, not exactly. There are a couple of things we must take into account:

1. Read [Networking in Compose](https://github.com/docker/compose/blob/master/docs/networking.md)
2. Launch docker-compose with the `--x-networking` flag, because docker networking is still an experimental feature.
3. Compose sets up a single default network for your app. The name of the network defaults to the directory name the compose file exists in. 
   Each container for a service joins the default network and is both reachable by other containers on that network, and discoverable by them at a hostname identical to the container name.
   The container name can be set with the `container_name` property if you don't want to use the default 
4. Compose uses the `bridge` driver when creating the app’s network by default. The Docker Engine provides one other driver out-of-the-box: `overlay`, which implements secure communication 
   between containers on different hosts. Use the `--x-network-driver` flag to specify which driver to use. 
   
The example `single-host-networking.yml` shows how to launch three ubuntu containers, force compose to name them `ubuntu1` to `ubuntu3`.
When compose is started with the appropriate flags, a docker network will be created and *all* containers, without exception
will be made a member of the network that has the name of the project directory. Let's take a look at how to launch compose and 
how the hosts file looks like:

```bash
$ docker-compose -f single-host-networking.yml --x-networking up
# cat /etc/hosts 
172.18.0.3	ubuntu2.dockernetworkingtest
172.18.0.2	ubuntu1
172.18.0.2	ubuntu1.dockernetworkingtest
172.18.0.3	ubuntu2
```

## Recap
Because the project directory is called `docker-networking-test` the network name will be normalized to `dockernetworkingtest`
and all containers will become a member of that network. This means that there is (still) no option to make containers members of 
another network, but for now this works.

We have created the following:

![docker-compose-single-host](https://github.com/dnvriend/docker-networking-test/blob/master/yed/docker-compose-single-host.png)

# Multi host networking example
Docker network also works across multiple hosts aka. [multi-host docker networking](https://blog.docker.com/2015/11/docker-multi-host-networking-ga/). 
In our example, each host will be a local instance created by `docker-machine`, which is both safe (we don't have to worry about setting up security) 
and free (most cloud providers charge for their services) and you don't have to fiddle with API keys, but it should also work with cloud providers.

Each new host will be provisioned by docker-machine with a docker service. Each docker service that work together must share 
information about its configuration, running containers, docker network configuration and such to a globally accessible 
configuration store. Such a sysem is called [service discovery](https://www.digitalocean.com/community/tutorials/the-docker-ecosystem-service-discovery-and-distributed-configuration-stores). 
Docker [supports](https://github.com/docker/docker/tree/master/pkg/discovery) the following configuration 
stores: [etcd](https://coreos.com/etcd/), [consul](https://www.consul.io/) and [zookeeper](https://zookeeper.apache.org/). For this
example we will be using `consul`, which has some nice advanced features including configurable health checks, ACL functionality, HAProxy configuration,
and has a web ui to boot!

So we will create the following:

![multihost-local](https://github.com/dnvriend/docker-networking-test/blob/master/yed/multihost-local.png)

The script `multihost-local.sh` will create three virtual machines using `docker-machine`:

1. __mhl-consul:__ This docker host will run the [progrium/consul](https://hub.docker.com/r/progrium/consul/) container that will 
 run a consul agent which is available on port 8500. The docker service will not take part sharing its configuration to other docker 
 services so it runs stand-alone and will not know about other docker hosts. It will only run the consul key/value service that 
 that the other docker hosts will use. It will be used by the `docker-network` service to share docker network configuration.
2. __mhl-demo0:__ A docker host that will share its configuration. At creation time, we supply the Engine daemon with the cluster-store option. 
 This option tells the Engine the location of the key-value store for the overlay network. The bash expansion $(docker-machine ip mhl-consul) resolves 
 to the IP address of the Consul server you created. The cluster-advertise option advertises the machine on the network.
3. __mhl-demo1:__ Another docker host that will share its configuration the same way as `mhl-demo0`.

After running the script and querying `docker-machine ls`, I get the following config:

```bash
NAME         ACTIVE   DRIVER       STATE     URL                         SWARM
mhl-consul   -        virtualbox   Running   tcp://192.168.99.100:2376
mhl-demo0    -        virtualbox   Running   tcp://192.168.99.101:2376
mhl-demo1    -        virtualbox   Running   tcp://192.168.99.102:2376
```

When you logon to the consul web ui (available at http://192.168.99.100:8500/ui/#/dc1/kv/docker/nodes/), you will 
see that there are 2 docker nodes that share this consul store. 

# Creating a network
Let's create a multi-host network! Note that we must specify a driver to use. Between hosts we must use the 
`overlay` driver and not the default `bridge` driver, so we must specify the driver to use below:

```bash
$ docker $(docker-machine config mhl-demo0) network create --driver=overlay linux
$ docker $(docker-machine config mhl-demo1) network ls
NETWORK ID          NAME                DRIVER
083908576ea3        linux               overlay
752439daf1ea        bridge              bridge
b299d1090469        none                null
31051f446f4b        host                host
```
 
This command creates a new network called `linux` using the `overlay` networking driver. The command has been executed
on the host `mhl-demo0` but the other host `mhl-demo1` instantly knows about the network as you can see.

## Launching the hosts
Let's launch a couple of ubuntu instances and check if we can ping:

```
$ docker $(docker-machine config mhl-demo0) run -it --net=linux --name=ubuntu1 ubuntu
$ docker $(docker-machine config mhl-demo1) run -it --net=linux --name=ubuntu2 ubuntu
```

The host file of `ubuntu1` looks like:

```bash
10.0.0.3	ubuntu2
10.0.0.3	ubuntu2.linux
```

and of `ubuntu2` looks like:

```bash
10.0.0.2	ubuntu1
10.0.0.2	ubuntu1.linux
```

## Pinging the hosts
Let's ping `ubuntu2.linux` from `ubuntu1` and ping `ubuntu1.linux` from `ubuntu2` using the `ping ubuntu1.linux` 
and `ping ubuntu2.linux` command. It works! 

## Recap
While this is useful, you’ll notice that you have to use `docker-machine config` to point your docker client at each 
machine `mhl-demo0` and `mhl-demo1`. Next we'll use [docker-swarm](https://github.com/docker/swarm) to turn a pool of 
docker hosts into a single, virtual host that makes working with docker and docker-compose a whole lot easier, because
we only have one docker configuration to set (the swarm) and then swarm schedules containers on any host in the swarm.
 
# Multi host networking with swarm example
The previous setup has the following problem: in order to schedule running a container on a docker host, we have to know 
the configuration of the docker host, and then instruct that host to create and launch a container. Wouldn't it be nice to turn all 
the docker host into one single, virtual host? Docker-swarm doest just that, it turns a pool of docker hosts into a single, 
virtual host, that will schedule containers to run on any docker host in the swarm. Of course, multi host networking also
works.
  
We will create the following:

![swarm-local](https://github.com/dnvriend/docker-networking-test/blob/master/yed/swarm-local.png)

The script `swarm-local.sh` will create three virtual machines using `docker-machine`:

1. __swl-consul:__ This docker host will run the [progrium/consul](https://hub.docker.com/r/progrium/consul/) container that will 
 run a consul agent which is available on port 8500. The docker service will not take part sharing its configuration to other docker 
 services so it runs stand-alone and will not know about other docker hosts. It will only run the consul key/value service that 
 that the other docker hosts will use. It will be used by the `docker-network` service to share docker network configuration 
 and also the `docker-swarm service` to maintain a list of IP addresses in the swarm.
2. __swl-demo0:__ A docker host that will run two swarm instances (nodes), one `swarm-master` and a `swarm-agent`.
3. __swl-demo1:__ Another docker host that will run a `swarm-agent`. 

Every new docker host (node) must run a `swarm-agent` to become part of the swarm cluster. Every `swarm-node` will be 
configured to use consul for service discovery of the swarm. You can imagine that the key/value store (consul) will be
very important for the cluster to function, so in production, consul must be configured to be highly available. Docker-swarm
supports multiple [discovery backends](https://github.com/docker/swarm/tree/master/discovery), here we will use Consul.
   
# Communicating with swarm
To be able to instruct the swarm cluster to do stuff like creating a network or launching a container we must set
the docker-environment to point to the `swarm-master`:

```bash
$ eval $(docker-machine env --swarm swl-demo0)
```

To get information about the swarm cluster, use the `docker info` command:

```bash
$ docker info
Containers: 3
Images: 2
Role: primary
Strategy: spread
Filters: health, port, dependency, affinity, constraint
Nodes: 2
 swl-demo0: 192.168.99.101:2376
  └ Containers: 2
  └ Reserved CPUs: 0 / 4
  └ Reserved Memory: 0 B / 8.179 GiB
  └ Labels: executiondriver=native-0.2, kernelversion=4.1.12-boot2docker, operatingsystem=Boot2Docker 1.9.0 (TCL 6.4); master : 16e4a2a - Tue Nov  3 19:49:22 UTC 2015, provider=virtualbox, storagedriver=aufs
 swl-demo1: 192.168.99.102:2376
  └ Containers: 1
  └ Reserved CPUs: 0 / 4
  └ Reserved Memory: 0 B / 8.179 GiB
  └ Labels: executiondriver=native-0.2, kernelversion=4.1.12-boot2docker, operatingsystem=Boot2Docker 1.9.0 (TCL 6.4); master : 16e4a2a - Tue Nov  3 19:49:22 UTC 2015, provider=virtualbox, storagedriver=aufs
CPUs: 8
Total Memory: 16.36 GiB
Name: 9acf15bab2ae
```

# Creating a network
Let's create a network. You don't have to instruct swarm to create a network, you could instruct any docker host in the 
cluster to do that, but because we already have set the environment to the swarm-master, its a lot easier to use swarm.

Note that we must specify a driver to use. Between hosts we must use the `overlay` driver and not the default `bridge` 
driver, so we must specify the driver to use below:

```bash
$ docker network create --driver=overlay linux
$ docker network ls
NETWORK ID          NAME                DRIVER
009dd541403a        swl-demo0/none      null
1dac9f7cdd6e        linux               overlay
0ac270a21266        swl-demo0/host      host
7729c35f8a4a        swl-demo1/bridge    bridge
84fe22d382f1        swl-demo1/none      null
f328f1dcf034        swl-demo1/host      host
99ca9a9c3db9        swl-demo0/bridge    bridge
```
 
Because we are in the `swarm-master` environment, you see all the networks on all swarm nodes. Notice that each NETWORK ID 
is unique. The default networks on each engine and the single overlay network.

We can switch to each docker host and list the network, we will see that every docker host reports about the linux network 
and that means that the multi host networking is running, huzzah!

```bash
$ docker $(docker-machine config swl-demo0) network ls
NETWORK ID          NAME                DRIVER
1dac9f7cdd6e        linux               overlay
009dd541403a        none                null
0ac270a21266        host                host
99ca9a9c3db9        bridge              bridge
$ docker $(docker-machine config swl-demo0) network ls
NETWORK ID          NAME                DRIVER
1dac9f7cdd6e        linux               overlay
99ca9a9c3db9        bridge              bridge
009dd541403a        none                null
0ac270a21266        host                host
```

## Launching the hosts
Let's launch a couple of ubuntu instances. We will instruct swarm to launch a container on specific hosts using a 
[docker-swarm-filter](https://github.com/docker/swarm/tree/master/scheduler/filter):

```bash
$ docker run -it --net=linux --name=ubuntu1 --env="constraint:node==swl-demo0" ubuntu
$ docker run -it --net=linux --name=ubuntu2 --env="constraint:node==swl-demo1" ubuntu
```

The command will instruct swarm to launch a container running ubuntu on a node with the name `swl-demo0`, call the container
`ubuntu1` and make it a member of the network `linux`. 

The host file of `ubuntu1` looks like:

```bash
10.0.0.3	ubuntu2
10.0.0.3	ubuntu2.linux
```

and of `ubuntu2` looks like:

```bash
10.0.0.2	ubuntu1
10.0.0.2	ubuntu1.linux
```

## Pinging the hosts
Let's ping `ubuntu2.linux` from `ubuntu1` and ping `ubuntu1.linux` from `ubuntu2` using the `ping ubuntu1.linux` 
and `ping ubuntu2.linux` command. It works! 

## Adding a docker-swarm node
Let's add a new node to the swarm cluster called `swl-demo2`. You can use the `swarm-local-add-node.sh` script for this.

When the new node has been launched we can query the swarm cluster:
 
```bash
$ docker info
Containers: 6
Images: 5
Role: primary
Strategy: spread
Filters: health, port, dependency, affinity, constraint
Nodes: 3
 swl-demo0: 192.168.99.101:2376
  └ Containers: 3
  └ Reserved CPUs: 0 / 4
  └ Reserved Memory: 0 B / 8.179 GiB
  └ Labels: executiondriver=native-0.2, kernelversion=4.1.12-boot2docker, operatingsystem=Boot2Docker 1.9.0 (TCL 6.4); master : 16e4a2a - Tue Nov  3 19:49:22 UTC 2015, provider=virtualbox, storagedriver=aufs
 swl-demo1: 192.168.99.102:2376
  └ Containers: 2
  └ Reserved CPUs: 0 / 4
  └ Reserved Memory: 0 B / 8.179 GiB
  └ Labels: executiondriver=native-0.2, kernelversion=4.1.12-boot2docker, operatingsystem=Boot2Docker 1.9.0 (TCL 6.4); master : 16e4a2a - Tue Nov  3 19:49:22 UTC 2015, provider=virtualbox, storagedriver=aufs
 swl-demo2: 192.168.99.103:2376
  └ Containers: 1
  └ Reserved CPUs: 0 / 4
  └ Reserved Memory: 0 B / 8.179 GiB
  └ Labels: executiondriver=native-0.2, kernelversion=4.1.12-boot2docker, operatingsystem=Boot2Docker 1.9.0 (TCL 6.4); master : 16e4a2a - Tue Nov  3 19:49:22 UTC 2015, provider=virtualbox, storagedriver=aufs
CPUs: 12
Total Memory: 24.54 GiB
Name: 9acf15bab2ae
```

Does it know about the `linux` network?

```bash
$ docker $(docker-machine config swl-demo2) network ls
NETWORK ID          NAME                DRIVER
1dac9f7cdd6e        linux               overlay
0df96c200a6c        bridge              bridge
f8c7d3f50ac3        none                null
94c85144ce20        host                host
```

Yes it does! Let's launch an ubuntu on the new node and ping `ubuntu1.linux` and `ubuntu2.linux`:
 
```bash
$ docker run -it --net=linux --name=ubuntu3 --env="constraint:node==swl-demo2" ubuntu
$ cat /etc/hosts
10.0.0.3	ubuntu2
10.0.0.3	ubuntu2.linux
10.0.0.2	ubuntu1
10.0.0.2	ubuntu1.linux
```

This is great! It's that easy to work with docker, swarm and add a new node, launch a container and do multi host networking. Great work guys!

## Recap
The swarm strategy has the following advantages:

- a single environment configuration to communicate with the swarm, eg. using docker-compose
- using [docker-swarm-filters](https://github.com/docker/swarm/tree/master/scheduler/filter) to instruct swarm to schedule
 a container on a node based upon rules.
- adding more nodes to the cluster and still have a single virtual docker host.
