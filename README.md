# Prereq
```
export PROJECT_ID=gkebatchexpce3c8dcb
export REGION=us-central1
export SERVICE_ACCOUNT_NAME=deploy-gke-sa
```
# Create the repository connection to GitHub
- To do this in the [UI](https://cloud.google.com/build/docs/automating-builds/github/connect-repo-github?generation=2nd-gen#connecting_a_github_host)

- To do this in the [CLI](https://cloud.google.com/build/docs/automating-builds/github/connect-repo-github?generation=2nd-gen#gcloud)

- Set repository environment variables
```
# the repository values will differ depending on your setup
export REPOSITORY_CONNECTION_NAME=cloudml-ops
export REPOSITORY=cloud-mlops-fine-tuning
```


# Create build triggers finetune
```
gcloud builds triggers create github \
    --name=build-finetune-image \
    --region=${REGION} \
    --repository="projects/${PROJECT_ID}/locations/${REGION}/connections/${REPOSITORY_CONNECTION_NAME}/repositories/${REPOSITORY}" \
    --branch-pattern="^main$" \
    --build-config="finetune-gemma/cloudbuild.yaml" \
    --included-files="finetune-gemma/fine_tune.py,finetune-gemma/requirements.txt" \
    --substitutions='_VERSION=$SHORT_SHA'
```

# Cloud Build Pub/Sub Trigger To Provision Resources in Cluster
- Create the topic for Artifact Registry to trigger on image addition
```
gcloud pubsub topics create gcr --project=${PROJECT_ID}
#gcloud pubsub subscriptions create ar-sub --topic=gcr --project=${PROJECT_ID}
```

- Create Service Account to be used for the pub/sub trigger
```
gcloud iam service-accounts create ${SERVICE_ACCOUNT_NAME} \
  --description="GKE SA for Cloud Build"
```

- Assign valid roles
```
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member=serviceAccount:${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com \
    --role=roles/gkehub.gatewayEditor \
    --condition=None

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member=serviceAccount:${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com \
    --role=roles/gkehub.viewer \
    --condition=None

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member=serviceAccount:${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com \
    --role=roles/logging.logWriter \
    --condition=None
```

- Create the Pub/Sub trigger
```
gcloud builds triggers create pubsub \
    --name=trigger-deploy-finetune-job \
    --region=${REGION} \
    --topic=projects/${PROJECT_ID}/topics/gcr \
    --build-config=finetune-gemma/cloudbuild-deploy.yaml \
    --repository="projects/${PROJECT_ID}/locations/${REGION}/connections/${REPOSITORY_CONNECTION_NAME}/repositories/${REPOSITORY}" \
    --branch="main" \
    --substitutions='_IMAGE_TAG=$(body.message.data.tag)','_ACTION=$(body.message.data.action)','_IMAGE_VERSION=${_IMAGE_TAG##*:}','_ACCELERATOR=a100','_CLUSTER_NAME=mlp-kenthua' \
    --subscription-filter='_IMAGE_TAG.matches("(us-docker.pkg.dev/gkebatchexpce3c8dcb/llm/finetune)(?::.+)?") && _ACTION.matches("INSERT")' \
    --service-account="projects/${PROJECT_ID}/serviceAccounts/${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
```