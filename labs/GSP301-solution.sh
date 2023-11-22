##
## GSP301 - Create instance with Cloud Storage startup script
##
# Session variables
export PROJECT_ID=$(gcloud config get-value project)
export REGION="us-central1"
export ZONE="us-central1-a"
export BUCKET_NAME="${PROJECT_ID}-startup"
echo $BUCKET_NAME

# Fix Tabular Output
gcloud config set accessibility/screen_reader false

# Set Region and Zone
gcloud config set compute/region $REGION
gcloud config set compute/zone $ZONE

# Make Script Bucket
gsutil mb gs://$BUCKET_NAME/

cat << EOF > install-web.sh
#!/bin/bash
apt-get update
apt-get install -y apache2
EOF
gsutil cp install-web.sh gs://$BUCKET_NAME/

gcloud compute instances create linux-host --tags=web \
    --machine-type=e2-small --image-family=debian-11 --image-project=debian-cloud \
    --metadata=startup-script-url=gs://$BUCKET_NAME/install-web.sh \
    --scopes=storage-ro 

gcloud compute firewall-rules create http --target-tags web --allow tcp:80

