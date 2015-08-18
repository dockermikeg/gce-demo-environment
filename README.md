#  Docker CS Engine, Swarm, and Trusted Registry on Google Compute Engine

These scripts install Docker CS Engine, Docker Swarm, and Docker Trusted Registry on Google Compute Engine.  The script generate certificates and keys, so that communication with Docker CS Engines is protected with TLS.  The end-state will be a cluster of nodes that all have CS Engine installed.  Swarm will also be running on the swarm-master node, and DTR will be running on the dtr-repo node.

There are two main scripts in this repo:
- **launch-vm-cluster.sh**: This is the "entrypoint" script, containing all customizable environment variables.  Edit the variables at the top of this file, then execute this script.
- **provision-docker-node.sh**: This script runs as a startup script on each Compute Engine node.  Generally, you shouldn't have to modify this script at all.

Prerequisites and instructions:
- Install the Google Cloud SDK (cloud.google.com/sdk) on your laptop
- Create a Google Cloud account - put the account id in the CLOUD_PROJECT ID variable in launch-vm-cluster.sh
- Create a Google Cloud Storage bucket, and put the bucket name in the CLOUD_STORAGE_BUCKET variable in launch-vm-cluster.sh
- Adjust the values of the other environment variables in launch-vm-cluster.sh if you'd like to change the defaults
- Create a directory at the same level of this script called install-files
- Download docker-cs-engine-deb.sh and the DTR license file from Docker Hub.  Copy them and provision-docker-node.sh into a directory called install-files
- Run boot2docker on your laptop; then run launch-vm-cluster.sh from within the boot2docker terminal
- IMPORTANT: this script, along with provision-docker-node.sh, depend heavily on the fact that two of the nodes are named "swarm-master" and "dtr-repo." **DO NOT CHANGE THESE NAMES.**

Once the cluster is up and running you will need to manually do the following:
- Configure the DTR server's hostname, license file, and server certificates (haven't got this working yet)
- Install Jenkins on the swarm-master node, and configure a continuous integration job

If you are having problems accessing any of the ports on your instances, you may need to create a firewall rule in GCE to allow access to your IP address.  To do this:
- Go to www.whatismyip.com.  Write down your ip address.
- Run the command: 

    gcloud compute --project "*your project ID*" firewall-rules create "allow-my-ip" --allow tcp:1-65535 --network "default" --source-ranges "*your IP address*"
