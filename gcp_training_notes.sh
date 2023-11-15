# Session variables
PROJECT=$(gcloud config get-value core/project)
export REGION="us-central1"
export ZONE="us-central1-a"

# Fix Tabular Output
gcloud config set accessibility/screen_reader false

# Set Region and Zone
gcloud config set compute/region $REGION
gcloud config set compute/zone $ZONE

# Set Services
gcloud services enable \
  compute.googleapis.com \
  iam.googleapis.com \
  iamcredentials.googleapis.com \
  monitoring.googleapis.com \
  logging.googleapis.com

#Cloud Monitoring setup
curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
sudo bash add-google-cloud-ops-agent-repo.sh --also-install

##
## Create GKE Cluster with web service
##
gcloud config set compute/region europe-west1
gcloud config set compute/zone europe-west1-c
gcloud container clusters create --machine-type=e2-medium --zone=europe-west1-c lab-cluster
gcloud container clusters get-credentials lab-cluster
kubectl create deployment hello-server --image=gcr.io/google-samples/hello-app:2.0
kubectl expose deployment hello-server --type=LoadBalancer --port 8082
kubectl get service


##
## Create network HTTP Load Balancer
##
gcloud compute instances create www1 --zone=us-east1-d --tags=network-lb-tag \
    --machine-type=e2-small --image-family=debian-11 --image-project=debian-cloud \
    --metadata=startup-script='#!/bin/bash
      apt-get update
      apt-get install apache2 -y
      service apache2 restart
      echo "
<h3>Web Server: www1</h3>" | tee /var/www/html/index.html'

gcloud compute instances create www2 \
    --zone=us-east1-d \
    --tags=network-lb-tag \
    --machine-type=e2-small \
    --image-family=debian-11 \
    --image-project=debian-cloud \
    --metadata=startup-script='#!/bin/bash
      apt-get update
      apt-get install apache2 -y
      service apache2 restart
      echo "
<h3>Web Server: www2</h3>" | tee /var/www/html/index.html'

gcloud compute instances create www3 --zone=us-east1-d  --tags=network-lb-tag \
    --machine-type=e2-small --image-family=debian-11 --image-project=debian-cloud \
    --metadata=startup-script='#!/bin/bash
      apt-get update
      apt-get install apache2 -y
      service apache2 restart
      echo "
<h3>Web Server: www3</h3>" | tee /var/www/html/index.html'

gcloud compute firewall-rules create www-firewall-network-lb --target-tags network-lb-tag --allow tcp:80
gcloud compute addresses create network-lb-ip-1 --region us-east1
gcloud compute http-health-checks create basic-check
gcloud compute target-pools create www-pool --region us-east1 --http-health-check basic-check
gcloud compute target-pools add-instances www-pool --instances www1,www2,www3
gcloud compute forwarding-rules create www-rule --region  us-east1 \--ports 80 --address network-lb-ip-1 --target-pool www-pool


##
## Create Global HTTP Load Balancer
##
gcloud compute instance-templates create lb-backend-template --network=default --subnet=default \
   --tags=allow-health-check --machine-type=e2-medium --image-family=debian-11 --image-project=debian-cloud \
   --metadata=startup-script='#!/bin/bash
     apt-get update
     apt-get install apache2 -y
     a2ensite default-ssl
     a2enmod ssl
     vm_hostname="$(curl -H "Metadata-Flavor:Google" \
     http://169.254.169.254/computeMetadata/v1/instance/name)"
     echo "Page served from: $vm_hostname" | \
     tee /var/www/html/index.html
     systemctl restart apache2'

gcloud compute instance-groups managed create lb-backend-group --template=lb-backend-template --size=2 --zone=us-east1-d
gcloud compute firewall-rules create fw-allow-health-check --network=default --action=allow --direction=ingress --source-ranges=130.211.0.0/22,35.191.0.0/16 --target-tags=allow-health-check --rules=tcp:80
gcloud compute addresses create lb-ipv4-1 --ip-version=IPV4 --global
gcloud compute addresses describe lb-ipv4-1 --format="get(address)" --global
gcloud compute health-checks create http http-basic-check --port 80
gcloud compute backend-services create web-backend-service --protocol=HTTP --port-name=http --health-checks=http-basic-check --global
gcloud compute backend-services add-backend web-backend-service --instance-group=lb-backend-group --instance-group-zone=us-east1-d --global
gcloud compute url-maps create web-map-http --default-service web-backend-service
gcloud compute target-http-proxies create http-lb-proxy --url-map web-map-http
gcloud compute forwarding-rules create http-content-rule --address=lb-ipv4-1 --global --target-http-proxy=http-lb-proxy --ports=80


##
## Create BigQuery Dataset & Bucket
##
bq mk dataset-name
bq mk --time_partitioning_field timestamp \
--schema ride_id:string,point_idx:integer,latitude:float,longitude:float,\
timestamp:timestamp,meter_reading:float,meter_increment:float,ride_status:string,\
passenger_count:integer -t taxirides.realtime
gsutil mb gs://$BUCKET_NAME/

##
## Create Dataproc Cluster and Job
##
gcloud config set dataproc/region us-central1
PROJECT_ID=$(gcloud config get-value project) && gcloud config set project $PROJECT_ID
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')
gcloud projects add-iam-policy-binding $PROJECT_ID --member=serviceAccount:$PROJECT_NUMBER-compute@developer.gserviceaccount.com --role=roles/storage.admin
gcloud dataproc clusters create example-cluster --worker-boot-disk-size 500 --worker-machine-type=e2-standard-4 --master-machine-type=e2-standard-4
gcloud dataproc jobs submit spark --cluster example-cluster --class org.apache.spark.examples.SparkPi --jars file:///usr/lib/spark/examples/jars/spark-examples.jar -- 1000
gcloud dataproc clusters update example-cluster --num-workers 4


##
## Parse Natural Language 
##
language.googleapis.com
export GOOGLE_CLOUD_PROJECT=$(gcloud config get-value core/project)
gcloud iam service-accounts create api-sa --display-name "API Service Account for CLI"
gcloud iam service-accounts keys create ~/key.json --iam-account api-sa@${GOOGLE_CLOUD_PROJECT}.iam.gserviceaccount.com
export GOOGLE_APPLICATION_CREDENTIALS="~/key.json"
export API_KEY=
#
gcloud ml language analyze-entities --content="Michelangelo Caravaggio, Italian painter, is known for 'The Calling of Saint Matthew'." > result.json
#
cat > request.json << EOF
{
  "config": {
      "encoding":"FLAC",
      "languageCode": "en-US"
  },
  "audio": {
      "uri":"gs://cloud-samples-tests/speech/brooklyn.flac"
  }
}
EOF
curl -s -X POST -H "Content-Type: application/json" --data-binary @request.json "https://speech.googleapis.com/v1/speech:recognize?key=${GOOGLE_APPLICATION_CREDENTIALS}"

##
## Parse Audio Speech
##









