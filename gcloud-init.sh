##
## gcloud-init.sh
##

#Fix tabular output
gcloud config set accessibility/screen_reader false

#Set Important Vars
export PROJECT_ID=$(gcloud config get-value project)
export REGION="us-east1"
export ZONE="us-east1-d"
gcloud config set compute/region $REGION
gcloud config set compute/zone $ZONE

# Show starting resources
gcloud compute networks list
gcloud compute networks subnets list
gcloud compute firewall-rules list
gcloud compute instances list

