#!/bin/bash

get-metadata() {
    curl http://metadata/computeMetadata/v1/instance/attributes/${1} -H "Metadata-Flavor: Google"
}

export CS_ENGINE_INSTALLER_FILE="`get-metadata cs-installer-file`"
export CLOUD_STORAGE_BUCKET="`get-metadata cloud-storage-bucket`"
export IS_SWARM_MASTER="`get-metadata is-swarm-master`"
export OTHER_NODES="`get-metadata other-nodes`"
export PROJECT_ID="`curl http://metadata.google.internal/computeMetadata/v1/project/project-id -H 'Metadata-Flavor: Google'`"

if [ ! -d /workspace ]
then
    mkdir /workspace
    chmod 777 /workspace
fi

cd /workspace

if [ ! -f linux-image-extra-virtual-sentinel.txt ]
then
    apt-get update && apt-get upgrade -y
    apt-get install -y linux-image-extra-virtual
    touch linux-image-extra-virtual-sentinel.txt
    reboot
fi

if [ ! -f docker-install-sentinel.txt ]
then
  gsutil cp gs://${CLOUD_STORAGE_BUCKET}/* .
  
  chmod 755 ${CS_ENGINE_INSTALLER_FILE}
  ./${CS_ENGINE_INSTALLER_FILE}
  apt-get install -y docker-engine-cs
  
  mkdir /keys
  cp *.pem /keys
  
  echo 'DOCKER_OPTS=" --tlsverify --tlscacert=/workspace/ca.pem --tlscert=/workspace/server.pem --tlskey=/workspace/server-key.pem -H=0.0.0.0:2376 -H=unix:///var/run/docker.sock "' >> /etc/default/docker
  
  cp ca.pem /usr/local/share/ca-certificates/docker.crt
  update-ca-certificates
  service docker restart
  
  touch docker-install-sentinel.txt
  
  reboot
  
fi


if [ ! -f swarm-install-sentinel.txt ] 
then


  if [ "`hostname`" == "swarm-master" ]
  then
  
      sleep 60 # wait a minute while the other nodes boot up

      for node in $OTHER_NODES
      do
        echo "${node}.c.${PROJECT_ID}.internal:2376" >> /workspace/my_cluster
      done

      docker run -d -p 3376:3376 \
        -v /workspace/:/keys/  \
        swarm manage \
        --tlsverify \
        --tlscacert=/keys/ca.pem \
        --tlscert=/keys/server.pem \
        --tlskey=/keys/server-key.pem \
        -H tcp://0.0.0.0:3376 \
        file:///keys/swarm_config.txt
  
  fi
  
  touch swarm-install-sentinel.txt

fi


if [ ! -f dtr-repo-sentinel.txt ] 
then


  if [ "`hostname`" == "dtr-repo" ]
  then
  
      bash -c "$(sudo docker run docker/trusted-registry install)"
      
      sleep 60
  
      cat /workspace/server.pem /workspace/ca.pem /workspace/server-key.pem \
          > /usr/local/etc/dtr/ssl/server.pem
    
      cp /workspace/*.lic /usr/local/etc/dtr/license.json
      tee "/usr/local/etc/dtr/hub.yml" > /dev/null << hostname_config_heredoc
load_balancer_http_port: 80
load_balancer_https_port: 443
domain_name: dtr-repo.c.${PROJECT_ID}.internal
extra_env:
  HTTP_PROXY: ""
  HTTPS_PROXY: ""
  NO_PROXY: ""
hostname_config_heredoc
      
      
      touch dtr-repo-sentinel.txt
      
      reboot
  
  fi
  
  touch dtr-repo-sentinel.txt

fi

