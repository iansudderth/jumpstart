cleanup:
  rm -rf temphome
  distrobox rm -f jumpstart

create: cleanup
  mkdir ./temphome
  cp ./jumpstart.sh ./temphome/
  distrobox create --name jumpstart --image ubuntu --home $(pwd)/temphome

start: create
 cd ./temphome && distrobox enter jumpstart
