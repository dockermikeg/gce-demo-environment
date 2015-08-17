#!/bin/bash

get-metadata() {
    curl http://metadata/computeMetadata/v1/instance/attributes/${1} -H "Metadata-Flavor: Google"
}

export CS_ENGINE_INSTALLER_FILE="`get-metadata cs-installer-file`"
export CLOUD_STORAGE_BUCKET="`get-metadata cloud-storage-bucket`"

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


