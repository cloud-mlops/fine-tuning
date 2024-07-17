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

# Create build triggers dataprep
```
gcloud builds triggers create github \
    --name=build-dataprep-image \
    --region=${REGION} \
    --repository="projects/${PROJECT_ID}/locations/${REGION}/connections/${REPOSITORY_CONNECTION_NAME}/repositories/${REPOSITORY}" \
    --branch-pattern="^main$" \
    --build-config="dataprep/cloudbuild.yaml" \
    --included-files="dataprep/dataprep.py,dataprep/requirements.txt" \
    --substitutions='_VERSION=$SHORT_SHA'
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

# Cloud Build Pub/Sub Artifact Registry Trigger To Provision Resources in Cluster
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

- Create the Pub/Sub trigger to deploy dataprep
```
gcloud builds triggers create pubsub \
    --name=trigger-deploy-dataprep-job \
    --region=${REGION} \
    --topic=projects/${PROJECT_ID}/topics/gcr \
    --build-config=dataprep/cloudbuild-deploy.yaml \
    --repository="projects/${PROJECT_ID}/locations/${REGION}/connections/${REPOSITORY_CONNECTION_NAME}/repositories/${REPOSITORY}" \
    --branch="main" \
    --substitutions='_IMAGE_TAG=$(body.message.data.tag)','_ACTION=$(body.message.data.action)','_IMAGE_VERSION=${_IMAGE_TAG##*:}','_CLUSTER_NAME=mlp-kenthua','_BUCKET=kh-finetune-ds','_DATASET_INPUT_PATH=flipkart_preprocessed_dataset','_DATASET_INPUT_FILE=flipkart.csv','_PROMPT_MODEL_ID=gemini-1.5-flash-001','_VERTEX_REGION=us-central1' \
    --subscription-filter='_IMAGE_TAG.matches("(us-docker.pkg.dev/gkebatchexpce3c8dcb/llm/dataprep)(?::.+)?") && _ACTION.matches("INSERT")' \
    --service-account="projects/${PROJECT_ID}/serviceAccounts/${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
```

- Create the Pub/Sub trigger to deploy finetune
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

# Cloud Build Pub/Sub GCS Trigger To Provision Resources in Cluster
- Allow GCS bucket to publish
```
SERVICE_ACCOUNT="$(gsutil kms serviceaccount -p ${PROJECT_ID})"
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${SERVICE_ACCOUNT}" \
    --role='roles/pubsub.publisher' \
    --condition=None
```

- Create the GCS Pub/Sub topic
```
TOPIC=${BUCKET}-topic
gcloud storage buckets notifications create gs://${BUCKET} --topic=${TOPIC}
```

- Create the trigger for new data in GCS
```
gcloud builds triggers create pubsub \
    --name=trigger-deploy-findtune-job-new-data-1 \
    --region=${REGION} \
    --topic=projects/${PROJECT_ID}/topics/${TOPIC} \
    --build-config=finetune-gemma/cloudbuild-deploy-new-data.yaml \
    --repository="projects/${PROJECT_ID}/locations/${REGION}/connections/${REPOSITORY_CONNECTION_NAME}/repositories/${REPOSITORY}" \
    --branch="main" \
    --substitutions='_EVENT_TYPE="$(body.message.attributes.eventType)"','_BUCKET_ID="$(body.message.attributes.bucketId)"','_OBJECT_ID="$(body.message.attributes.objectId)"','_IMAGE_TAG=$(body.message.data.tag)','_IMAGE_VERSION=${_IMAGE_TAG##*:}','_ACCELERATOR=a100','_CLUSTER_NAME=mlp-kenthua' \
    --subscription-filter='_EVENT_TYPE == "OBJECT_FINALIZE" && _OBJECT_ID.matches("training/state.json") && _BUCKET_ID.matches("${BUCKET}")'
```