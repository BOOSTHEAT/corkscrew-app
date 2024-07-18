#!/bin/sh
echo "Running $0"

set -eu

trap '[ $? -eq 0 ] && exit 0 || onError $?' EXIT

onError () {
  echo "Initialization script FAILED. Error $1."
  return "$1"
}

# Initialize Redis DB
callRedis() {
  redis-cli -h "127.0.0.1" -p 6379 -n 2 "$@"
}
while [ "$(callRedis DBSIZE)" != "0" ]
do
  echo "FLUSHALL"
  callRedis FLUSHALL > /dev/null
done


# Initialize Influx DB
while [ $(influx -execute 'exit' >/dev/null 2>&1; echo $?) != 0 ]
do
  echo "Waiting for InfluxDB"
  sleep 1
done
INFLUXCMD='DROP DATABASE boiler; CREATE DATABASE boiler; ALTER RETENTION POLICY "autogen" ON "boiler" DURATION 20d; SHOW DATABASES'
influx -execute "${INFLUXCMD}"

# self destruction
rm -v $0
