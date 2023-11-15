##
## GSP330 - Implement DevOps in Google Cloud: Challenge Lab
##

# STATUS - Lab Broken?  I can't get the pods to properly download the images.

# Session variables
export PROJECT_ID=$(gcloud config get-value project)
echo $PROJECT_ID
export PROJECT_NUMBER=$(gcloud projects describe ${PROJECT_ID} --format="value(projectNumber)")
echo $PROJECT_NUMBER
export REGION="us-central1"
export ZONE="us-central1-c"
export REPO_NAME="my-repository"
export CLUSTER_NAME="hello-cluster" 

# Fix Tabular Output
gcloud config set accessibility/screen_reader false

# Set Region and Zone
gcloud config set compute/region $REGION
gcloud config set compute/zone $ZONE

gcloud services enable container.googleapis.com \
    cloudbuild.googleapis.com \
    sourcerepo.googleapis.com

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member=serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com \
  --role="roles/container.developer"

git config --global user.email student-01-ea2b12e6a72d@qwiklabs.net
git config --global user.name "Noah Body"

gcloud artifacts repositories create $REPO_NAME \
  --repository-format=docker \
  --location=$REGION

# gcloud artifacts repositories add-iam-policy-binding $REPO_NAME \
#     --location=$REGION \
#     --member=serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com \
#     --role="roles/artifactregistry.reader"

# gcloud container clusters create hello-cluster \
#   --enable-autoscaling --num-nodes=3 --min-nodes=2 --max-nodes=6 

gcloud beta container --project "$PROJECT_ID" clusters create "$CLUSTER_NAME" --zone "$ZONE" \
  --no-enable-basic-auth --cluster-version latest --release-channel "regular" \
  --machine-type "e2-medium" --image-type "COS_CONTAINERD" --disk-type "pd-balanced" --disk-size "100" \
  --metadata disable-legacy-endpoints=true  --logging=SYSTEM,WORKLOAD --monitoring=SYSTEM --enable-ip-alias \
  --network "projects/$PROJECT_ID/global/networks/default" \
  --subnetwork "projects/$PROJECT_ID/regions/$REGION/subnetworks/default" \
  --no-enable-intra-node-visibility --default-max-pods-per-node "110" \
  --enable-autoscaling --min-nodes "2" --max-nodes "6" --location-policy "BALANCED" \
  --no-enable-master-authorized-networks \
  --addons HorizontalPodAutoscaling,HttpLoadBalancing,GcePersistentDiskCsiDriver \
  --enable-autoupgrade --enable-autorepair --max-surge-upgrade 1 --max-unavailable-upgrade 0 \
  --enable-shielded-nodes --node-locations "$ZONE"


gcloud container clusters get-credentials hello-cluster
kubectl create ns prod
kubectl create ns dev

## Check Step One

## Step Two

gcloud source repos create sample-app
gcloud source repos clone sample-app
gsutil cp -r gs://spls/gsp330/sample-app/* sample-app
cd sample-app

for file in cloudbuild-dev.yaml cloudbuild.yaml; do
    sed -i "s/<your-region>/${REGION}/g" "$file"
    sed -i "s/<your-zone>/${ZONE}/g" "$file"
done

git add .
git commit -m "Clone app & update params to push to private repo"
git push origin master
git checkout -b dev
git push origin dev

## Step Two Check

#
# Test initial cloud build of dev image
#
# COMMIT_ID="$(git rev-parse --short=7 HEAD)"
# gcloud builds submit --tag="${REGION}-docker.pkg.dev/${PROJECT_ID}/my-repository/hello-cloudbuild-dev:${COMMIT_ID}" .
# gcloud auth configure-docker $REGION-docker.pkg.dev 
# docker pull $REGION-docker.pkg.dev/$PROJECT_ID/my-repository/sample-app:$COMMIT_ID
# docker run -p 4000:8080 --name my-app -d $REGION-docker.pkg.dev/$PROJECT_ID/my-repository/sample-app:$COMMIT_ID
# curl http://localhost:4000/blue
# docker stop -vf $(docker ps -aq) && docker rm -vf $(docker ps -aq) && docker rmi -f $(docker images -aq)


## Step Three


# Create Cloud Build Triggers in GUI and fix code customization
gcloud builds triggers create cloud-source-repositories --name="sample-app-prod-deploy" --repo="sample-app" --branch-pattern="^master$" --build-config="cloudbuild.yaml"
gcloud builds triggers create cloud-source-repositories --name="sample-app-dev-deploy" --repo="sample-app" --branch-pattern="^dev$" --build-config="cloudbuild-dev.yaml"

## Step Three Check 

# Fix dev branch code customizations
#  -edit cloudbuild-dev.yaml  s/<version>/v1.0/
#  -edit dev/deployment.yaml  s/<todo>/hello-cloudbuild-dev/

COMMIT_ID="$(git rev-parse --short=7 HEAD)"
gcloud builds submit --tag="${REGION}-docker.pkg.dev/${PROJECT_ID}/$REPO_NAME/hello-cloudbuild:${COMMIT_ID}" .
IMAGE=$(gcloud builds list --format="value(IMAGES)")
echo $IMAGE

sed -i "s/<version>/v1.0/g" cloudbuild-dev.yaml
sed -i "s#<todo>#$IMAGE#g" dev/deployment.yaml

git add .
git commit -m "Dev branch code customization update"
git push google dev

docker pull $REGION-docker.pkg.dev/$PROJECT_ID/my-repository/hello-cloudbuild-dev:v1.0
docker run -p 4000:8080 --name my-app -d $REGION-docker.pkg.dev/$PROJECT_ID/my-repository/hello-cloudbuild-dev:v1.0
curl http://localhost:4000/blue
docker stop -vf $(docker ps -aq) && docker rm -vf $(docker ps -aq) && docker rmi -f $(docker images -aq)

#export POD_NAME=$(kubectl get pods --namespace default -l "app.kubernetes.io/component=jenkins-master" -l "app.kubernetes.io/instance=cd" -o jsonpath="{.items[0].metadata.name}")
#kubectl port-forward $POD_NAME 8080:8080 >> /dev/null &

kubectl expose deployment development-deployment --type="LoadBalancer" --port=8080 --target-port==8080 --name=dev-deployment-service -n dev
#kubectl delete deployment development-deployment -n dev

