```
export PROJECT_ID=gkebatchexpce3c8dcb
export REGION=us-central1

gcloud services enable cloudbuild.googleapis.com servicenetworking.googleapis.com

gcloud compute addresses create cb-service-network \
    --global \
    --purpose=VPC_PEERING \
    --addresses=192.168.100.0 \
    --prefix-length=24 \
    --description="cloud build service network" \
    --network=ml-vpc-kenthua

gcloud services vpc-peerings connect \
    --service=servicenetworking.googleapis.com \
    --ranges=cb-service-network \
    --network=ml-vpc-kenthua \
    --project=${PROJECT_ID}

gcloud builds worker-pools create private-pool \
    --project=${PROJECT_ID} \
    --region=${REGION} \
    --peered-network=projects/gkebatchexpce3c8dcb/global/networks/ml-vpc-kenthua \
    --peered-network-ip-range=192.168.100.0/24 \
    --worker-machine-type=e2-standard-4 \
    --worker-disk-size=100
```