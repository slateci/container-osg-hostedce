#!/bin/bash

# source me

# for each bosco endpoint, call cmdline "$@" with batch, ruser, rhost set
foreach_bosco_endpoint () {
  local rx='^batch ([a-zA-Z0-9_]+) ([^ @]+)@([^ ]+)$'
  local ret=0
  condor_ce_job_router_info -config |
  while read key _ val; do
    case $key in
    GridResource)
      if [[ $val =~ $rx ]]; then
        batch=${BASH_REMATCH[1]} \
        ruser=${BASH_REMATCH[2]} \
        rhost=${BASH_REMATCH[3]} \
        "$@" || ret=1
      else
        echo "'$val' was not a recognized Bosco endpoint"  # >&2
      fi ;;
    esac
  done
  return $ret
}

