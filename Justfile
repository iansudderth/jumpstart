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
  
run-docker-ubuntu-shell: cleanup-docker-shell build-ubuntu
  docker run -it --name dev-shell --privileged -v /var/run/docker.sock:/var/run/docker.sock ubuntu-shell:latest

run-docker-arch-shell:cleanup-docker-shell build-arch
  docker run -it --name dev-shell --privileged -v /var/run/docker.sock:/var/run/docker.sock -v /home/iansudderth/:/home/root/work-home/ arch-shell:latest

build-arch:
  docker build --progress=plain -f ./arch-shell.dockerfile -t arch-shell:latest .

cleanup-docker-shell:
  -docker rm dev-shell

attach-to-docker-shell:
  -docker start dev-shell
  docker attach dev-shell
