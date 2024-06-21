#!/bin/bash

eth1=enp4s0f0
eth2=enp4s0f1

TOE_OPTIONS="rx tx sg tso ufo gso gro lro rxvlan txvlan rxhash"
for TOE_OPTION in $TOE_OPTIONS; do
/sbin/ethtool --offload $eth1  "$TOE_OPTION" off
/sbin/ethtool --offload $eth2  "$TOE_OPTION" off
done

