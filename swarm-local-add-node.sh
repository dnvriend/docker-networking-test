#!/bin/bash

set -e

# Docker Machine Setup
docker-machine create \
    -d virtualbox \
    --virtualbox-disk-size 50000 \
    --swarm \
    --swarm-discovery="consul://$(docker-machine ip swl-consul):8500" \
    --engine-opt="cluster-store=consul://$(docker-machine ip swl-consul):8500" \
    --engine-opt="cluster-advertise=eth1:0" \
    swl-demo2