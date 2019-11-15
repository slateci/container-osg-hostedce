#!/bin/bash

. foreach_bosco_endpoint.sh

OVERRIDE_DIR=/etc/condor-ce/bosco_override

setup_bosco_cluster () {
  bosco_cluster -o "$OVERRIDE_DIR" -a "${ruser}@${rhost}" "$batch"
}

foreach_bosco_endpoint setup_bosco_cluster

