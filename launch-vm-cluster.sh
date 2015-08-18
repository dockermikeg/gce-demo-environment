#!/bin/bash
#
#  INSTRUCTIONS:
#    - install the Google Cloud SDK (cloud.google.com/sdk) on your laptop
#    - create a Google Cloud account - put the account id in the CLOUD_PROJECT ID variable below
#    - create a Google Cloud Storage bucket, and put the bucket name in the CLOUD_STORAGE_BUCKET variable below
#    - adjust the values of the other environment variables below if you'd like to change the defaults
#    - create a directory at the same level of this script called install-files
#    - copy docker-cs-engine-deb.sh and provision-docker-node.sh into a directory called install-files
#    - run boot2docker on your laptop; then run this script from within the boot2docker terminal
#    - IMPORTANT: this script, along with provision-docker-node.sh, depend heavily on the
#                 fact that two of the nodes are named "swarm-master" and "dtr-repo."  
#                 DO NOT CHANGE THESE NAMES.
#

export SWARM_NODES="node1 node2" # change this line to add more swarm nodes, as desired
export ALL_NODES="${SWARM_NODES} swarm-master jenkins-slave dtr-repo" # don't change this line
export INSTANCE_TYPE="g1-small"
export ZONE="us-central1-f"
export CLOUD_PROJECT_ID="mike-graboski"
export CLOUD_STORAGE_BUCKET="graboski-install-files"
export CS_ENGINE_INSTALLER_FILE="docker-cs-engine-deb.sh"
export BASE_DIR

validate-prerequisites() {

license_file="$(ls install-files/*.lic 2>/dev/null)"
if [ ! -d install-files ] || [ ! -f install-files/${CS_ENGINE_INSTALLER_FILE} ] || [ "$license_file" == "" ]
then
    echo "ERROR: this script needs to be run in a directory where an 'install-files' subdirectory is present."
    echo "${CS_ENGINE_INSTALLER_FILE} and the DTR license key also must be present in the install-files directory."
    exit 1
fi

if [ "`which gcloud`" == "" ]
then
    echo "ERROR:  The Google Cloud SDK must be installed to run this script."
    echo "You also must create a Google Cloud Storage bucket and update the value of CLOUD_STORAGE_BUCKET in this launch-vm-cluster.sh script."
    exit 1
fi

if [ "`which docker`" == "" ]
then
    echo "ERROR:  The Docker runtime must be installed to run this script."
    exit 1
fi

if [[ "`docker ps 2>&1`" == *"no such file or directory"* ]]
then
    echo "ERROR:  You need to run this script inside a boot2docker terminal."
    exit 1
fi

}

generate-keys-and-certs() {

rm -rf ${BASE_DIR}/keys > /dev/null 2>&1
mkdir ${BASE_DIR}/keys

# generate CA cert and key
export keygen_hosts=""
for node in ${ALL_NODES}
do
    keygen_hosts=${keygen_hosts}" --host ${node} --host ${node}.c.${CLOUD_PROJECT_ID}.internal "
done

docker run --rm -v ${BASE_DIR}/keys:/certs ehazlett/certm \
    -d /certs bundle generate \
    -o=local \
    --host localhost --host 127.0.0.1 \
    ${keygen_hosts}
}

generate-swarm-config-file() {

for node in $SWARM_NODES
do
    echo "${node}.c.${CLOUD_PROJECT_ID}.internal:2376" >> install-files/swarm_config.txt
done

}


BASE_DIR=`pwd`
validate-prerequisites
generate-keys-and-certs
generate-swarm-config-file

gsutil cp ${BASE_DIR}/install-files/* gs://${CLOUD_STORAGE_BUCKET}/
gsutil cp ${BASE_DIR}/keys/* gs://${CLOUD_STORAGE_BUCKET}/

for NODE in $ALL_NODES
do

gcloud compute --project "${CLOUD_PROJECT_ID}" \
        instances create "${NODE}" \
        --zone "${ZONE}" \
        --machine-type "${INSTANCE_TYPE}" \
        --network "default" \
        --metadata "cloud-storage-bucket=${CLOUD_STORAGE_BUCKET}" \
        "cs-installer-file=${CS_ENGINE_INSTALLER_FILE}" \
        "startup-script-url=gs://${CLOUD_STORAGE_BUCKET}/provision-docker-node.sh" \
        --maintenance-policy "MIGRATE" \
        --scopes "https://www.googleapis.com/auth/devstorage.full_control" \
        "https://www.googleapis.com/auth/logging.write" \
        --image "https://www.googleapis.com/compute/v1/projects/ubuntu-os-cloud/global/images/ubuntu-1404-trusty-v20150805" \
        --boot-disk-type "pd-standard" \
        --boot-disk-device-name "${NODE}"
done