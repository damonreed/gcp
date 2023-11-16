# Enable APIs
gcloud services enable compute.googleapis.com
gcloud services enable dns.googleapis.com
gcloud services list | grep -E 'compute|dns'

#Create Firewalls
gcloud compute firewall-rules create fw-default-iapproxy \
--direction=INGRESS \
--priority=1000 \
--network=default \
--action=ALLOW \
--rules=tcp:22,icmp \
--source-ranges=35.235.240.0/20
gcloud compute firewall-rules create allow-http-traffic \
--direction=INGRESS --priority=1000 --network=default --action=ALLOW \
--rules=tcp:80 --source-ranges=0.0.0.0/0 --target-tags=http-server

# Launch Client VPNs
gcloud compute instances create us-client-vm --machine-type e2-medium --zone us-east1-d
gcloud compute instances create europe-client-vm --machine-type e2-medium --zone europe-west1-d
gcloud compute instances create asia-client-vm --machine-type e2-medium --zone asia-south1-b

# Launch Server VMs
gcloud compute instances create us-web-vm \
--zone=us-east1-d \
--machine-type=e2-medium \
--network=default \
--subnet=default \
--tags=http-server \
--metadata=startup-script='#! /bin/bash
 apt-get update
 apt-get install apache2 -y
 echo "Page served from: us-east1" | \
 tee /var/www/html/index.html
 systemctl restart apache2'
gcloud compute instances create europe-web-vm \
--zone=europe-west1-d \
--machine-type=e2-medium \
--network=default \
--subnet=default \
--tags=http-server \
--metadata=startup-script='#! /bin/bash
 apt-get update
 apt-get install apache2 -y
 echo "Page served from: europe-west1" | \
 tee /var/www/html/index.html
 systemctl restart apache2'

# Create Envs for IPs
export US_WEB_IP=$(gcloud compute instances describe us-web-vm --zone=us-east1-d --format="value(networkInterfaces.networkIP)")
export EUROPE_WEB_IP=$(gcloud compute instances describe europe-web-vm --zone=europe-west1-d --format="value(networkInterfaces.networkIP)")
echo -e "    US_WEB_IP : ${US_WEB_IP}\nEUROPE_WEB_IP : ${EUROPE_WEB_IP}"

# Create the private zone
gcloud dns managed-zones create example --description=test --dns-name=example.com --networks=default --visibility=private
gcloud beta dns record-sets create geo.example.com \
--ttl=5 --type=A --zone=example \
--routing_policy_type=GEO \
--routing_policy_data="us-east1=$US_WEB_IP;europe-west1=$EUROPE_WEB_IP"
gcloud beta dns record-sets list --zone=example

#SSH to client instances and test GEO DNS
gcloud compute ssh europe-client-vm --zone europe-west1-d --tunnel-through-iap
for i in {1..10}; do echo $i; curl geo.example.com; sleep 6; done
exit
gcloud compute ssh us-client-vm --zone us-east1-d --tunnel-through-iap
for i in {1..10}; do echo $i; curl geo.example.com; sleep 6; done
exit
gcloud compute ssh asia-client-vm --zone asia-south1-b --tunnel-through-iap
for i in {1..10}; do echo $i; curl geo.example.com; sleep 6; done
exit



