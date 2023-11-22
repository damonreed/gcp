##
## gcloud-init.sh
##

#Fix tabular output
gcloud config set accessibility/screen_reader false

#Set Important Vars
export PROJECT_ID=$(gcloud config get-value project)
export REGION="us-east4"
export ZONE="us-east4-a"
gcloud config set compute/region $REGION
gcloud config set compute/zone $ZONE

# Show starting resources
gcloud compute networks list
gcloud compute networks subnets list
gcloud compute firewall-rules list
gcloud compute instances list


# Task 1 -  Set up a Global VPC environment
gcloud compute networks create vpc-demo --subnet-mode custom

gcloud compute networks subnets create vpc-demo-subnet1 \
--network vpc-demo --range 10.1.1.0/24 --region "us-east4"

gcloud compute networks subnets create vpc-demo-subnet2 \
--network vpc-demo --range 10.2.1.0/24 --region us-central1

gcloud compute firewall-rules create vpc-demo-allow-custom \
  --network vpc-demo \
  --allow tcp:0-65535,udp:0-65535,icmp \
  --source-ranges 10.0.0.0/8
gcloud compute firewall-rules create vpc-demo-allow-ssh-icmp --network vpc-demo --allow tcp:22,icmp

gcloud compute instances create vpc-demo-instance1 --machine-type=e2-medium --zone us-east4-b --subnet vpc-demo-subnet1
gcloud compute instances create vpc-demo-instance2 --machine-type=e2-medium --zone us-central1-f --subnet vpc-demo-subnet2

# Task 2 - Set up a simulated on-premises environment
gcloud compute networks create on-prem --subnet-mode custom
gcloud compute networks subnets create on-prem-subnet1 --network on-prem --range 192.168.1.0/24 --region us-east4
gcloud compute firewall-rules create on-prem-allow-custom \
  --network on-prem \
  --allow tcp:0-65535,udp:0-65535,icmp \
  --source-ranges 192.168.0.0/16
gcloud compute firewall-rules create on-prem-allow-ssh-icmp \
--network on-prem \
--allow tcp:22,icmp
gcloud compute instances create on-prem-instance1 --machine-type=e2-medium --zone us-east4-a --subnet on-prem-subnet1

# Task 3. Set up an HA VPN gateway
gcloud compute vpn-gateways create vpc-demo-vpn-gw1 --network vpc-demo --region us-east4
gcloud compute vpn-gateways create on-prem-vpn-gw1 --network on-prem --region us-east4
gcloud compute vpn-gateways describe vpc-demo-vpn-gw1 --region us-east4
gcloud compute vpn-gateways describe on-prem-vpn-gw1 --region us-east4
gcloud compute routers create vpc-demo-router1 \
    --region us-east4 \
    --network vpc-demo \
    --asn 65001
gcloud compute routers create on-prem-router1 \
    --region us-east4 \
    --network on-prem \
    --asn 65002

# Task 4. Create two VPN tunnels
gcloud compute vpn-tunnels create vpc-demo-tunnel0 \
    --peer-gcp-gateway on-prem-vpn-gw1 \
    --region us-east4 \
    --ike-version 2 \
    --shared-secret [SHARED_SECRET] \
    --router vpc-demo-router1 \
    --vpn-gateway vpc-demo-vpn-gw1 \
    --interface 0
gcloud compute vpn-tunnels create vpc-demo-tunnel1 \
    --peer-gcp-gateway on-prem-vpn-gw1 \
    --region us-east4 \
    --ike-version 2 \
    --shared-secret [SHARED_SECRET] \
    --router vpc-demo-router1 \
    --vpn-gateway vpc-demo-vpn-gw1 \
    --interface 1
gcloud compute vpn-tunnels create on-prem-tunnel0 \
    --peer-gcp-gateway vpc-demo-vpn-gw1 \
    --region us-east4 \
    --ike-version 2 \
    --shared-secret [SHARED_SECRET] \
    --router on-prem-router1 \
    --vpn-gateway on-prem-vpn-gw1 \
    --interface 0
gcloud compute vpn-tunnels create on-prem-tunnel1 \
    --peer-gcp-gateway vpc-demo-vpn-gw1 \
    --region us-east4 \
    --ike-version 2 \
    --shared-secret [SHARED_SECRET] \
    --router on-prem-router1 \
    --vpn-gateway on-prem-vpn-gw1 \
    --interface 1

# Task 5. Create Border Gateway Protocol (BGP) peering for each tunnel
gcloud compute routers add-interface vpc-demo-router1 \
    --interface-name if-tunnel0-to-on-prem \
    --ip-address 169.254.0.1 \
    --mask-length 30 \
    --vpn-tunnel vpc-demo-tunnel0 \
    --region us-east4
gcloud compute routers add-bgp-peer vpc-demo-router1 \
    --peer-name bgp-on-prem-tunnel0 \
    --interface if-tunnel0-to-on-prem \
    --peer-ip-address 169.254.0.2 \
    --peer-asn 65002 \
    --region us-east4
gcloud compute routers add-interface vpc-demo-router1 \
    --interface-name if-tunnel1-to-on-prem \
    --ip-address 169.254.1.1 \
    --mask-length 30 \
    --vpn-tunnel vpc-demo-tunnel1 \
    --region us-east4
gcloud compute routers add-bgp-peer vpc-demo-router1 \
    --peer-name bgp-on-prem-tunnel1 \
    --interface if-tunnel1-to-on-prem \
    --peer-ip-address 169.254.1.2 \
    --peer-asn 65002 \
    --region us-east4
gcloud compute routers add-interface on-prem-router1 \
    --interface-name if-tunnel0-to-vpc-demo \
    --ip-address 169.254.0.2 \
    --mask-length 30 \
    --vpn-tunnel on-prem-tunnel0 \
    --region us-east4
gcloud compute routers add-bgp-peer on-prem-router1 \
    --peer-name bgp-vpc-demo-tunnel0 \
    --interface if-tunnel0-to-vpc-demo \
    --peer-ip-address 169.254.0.1 \
    --peer-asn 65001 \
    --region us-east4
gcloud compute routers add-interface  on-prem-router1 \
    --interface-name if-tunnel1-to-vpc-demo \
    --ip-address 169.254.1.2 \
    --mask-length 30 \
    --vpn-tunnel on-prem-tunnel1 \
    --region us-east4
gcloud compute routers add-bgp-peer  on-prem-router1 \
    --peer-name bgp-vpc-demo-tunnel1 \
    --interface if-tunnel1-to-vpc-demo \
    --peer-ip-address 169.254.1.1 \
    --peer-asn 65001 \
    --region us-east4

# Task 6. Verify router configurations
gcloud compute routers describe vpc-demo-router1 --region us-east4
gcloud compute routers describe on-prem-router1 --region us-east4
gcloud compute firewall-rules create vpc-demo-allow-subnets-from-on-prem \
    --network vpc-demo \
    --allow tcp,udp,icmp \
    --source-ranges 192.168.1.0/24
gcloud compute firewall-rules create on-prem-allow-subnets-from-vpc-demo \
    --network on-prem \
    --allow tcp,udp,icmp \
    --source-ranges 10.1.1.0/24,10.2.1.0/24

gcloud compute vpn-tunnels list
gcloud compute vpn-tunnels describe vpc-demo-tunnel0 --region us-east4
gcloud compute vpn-tunnels describe vpc-demo-tunnel1 --region us-east4

gcloud compute ssh on-prem-instance1 --zone us-east4-a
 ping -c 4 10.1.1.2
exit

gcloud compute networks update vpc-demo --bgp-routing-mode GLOBAL
gcloud compute networks describe vpc-demo

# Task 7. Verify and test the configuration of HA VPN tunnels
gcloud compute vpn-tunnels delete vpc-demo-tunnel0  --region us-east4
gcloud compute vpn-tunnels describe on-prem-tunnel0  --region us-east4

ping -c 3 10.1.1.2

# Task 8. (Optional) Clean up lab environment
gcloud compute vpn-tunnels delete on-prem-tunnel0  --region us-east4
gcloud compute vpn-tunnels delete vpc-demo-tunnel1  --region us-east4
gcloud compute vpn-tunnels delete on-prem-tunnel1  --region us-east4

gcloud compute routers remove-bgp-peer vpc-demo-router1 --peer-name bgp-on-prem-tunnel0 --region us-east4
gcloud compute routers remove-bgp-peer vpc-demo-router1 --peer-name bgp-on-prem-tunnel1 --region us-east4
gcloud compute routers remove-bgp-peer on-prem-router1 --peer-name bgp-vpc-demo-tunnel0 --region us-east4
gcloud compute routers remove-bgp-peer on-prem-router1 --peer-name bgp-vpc-demo-tunnel1 --region us-east4

gcloud compute  routers delete on-prem-router1 --region us-east4
gcloud compute  routers delete vpc-demo-router1 --region us-east4

gcloud compute vpn-gateways delete vpc-demo-vpn-gw1 --region us-east4
gcloud compute vpn-gateways delete on-prem-vpn-gw1 --region us-east4

gcloud compute instances delete vpc-demo-instance1 --zone us-east4-b
gcloud compute instances delete vpc-demo-instance2 --zone us-central1-f
gcloud compute instances delete on-prem-instance1 --zone zone_name

gcloud compute firewall-rules delete vpc-demo-allow-custom

