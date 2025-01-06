cleanup:
  rm -rf temphome
  distrobox rm -f jumpstart

create: cleanup 
  mkdir ./temphome
  cp ./jumpstart.sh ./temphome/
  distrobox create --name jumpstart --image ubuntu:25.04 --home $(pwd)/temphome --init-hooks "touch $(pwd)/temphome/.zshrc"


start: create
 cd ./temphome && distrobox enter jumpstart -- zsh -l -i -c "source ./jumpstart.sh && zsh -i"


build-ubuntu:
    docker build --progress=plain -f ./ubuntu-shell.dockerfile -t ubuntu-shell:latest .

run-docker-shell: cleanup-docker-shell build-ubuntu
 docker run -it --name dev-shell -u root -v /var/run/docker.sock:/var/run/docker.sock ubuntu-shell:latest


cleanup-docker-shell:
  -docker rm dev-shell
