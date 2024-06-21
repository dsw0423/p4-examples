#!/bin/bash

sudo ip netns add ns
sudo ip link set enp5s0f0 netns ns
sudo ip netns exec ns ip link set lo up
sudo ip netns exec ns ip link set enp5s0f0 up

