#!/bin/bash

function stop_flexibee {
  /etc/init.d/flexibee stop
  /etc/init.d/postgresql stop
  exit 0
}

trap stop_flexibee SIGTERM

while true; do
  sleep 1
done