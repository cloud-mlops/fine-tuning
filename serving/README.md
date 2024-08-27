# Guide for standalone and distributed inferencing on GKE (Google Kubernetes Engine)

This exercise assumes you have a fine-tuned model, that we would like to serve on GKE.
If you have followed the previous steps for dataprep and finetune you would have a model store in the GCS bucket in your GCP Project.

### A quick brief on Inference on VLLM.

There are three common strategies for inference on vLLM:

- Single GPU (no distributed inference)
- Single-Node Multi-GPU (tensor parallel inference)
- Multi-Node Multi-GPU 

In this guide, you would serve a fine-tuned Gemma large language model (LLM) using graphical processing units (GPUs) on Google Kubernetes Engine (GKE) with the vLLM serving framework with the above mentioned deployment strategies.You can choose to swap the Gemma model with any other fine-tuned or instruction based model for inference on GKE.

By the end of this guide, you should be able to perform the following steps:

                [ Place holder for concept diagram]

1. Prepare your ML Platform [Playground]( https://github.com/GoogleCloudPlatform/ai-on-gke/tree/ml-platform-dev/best-practices/ml-platform/examples/platform/playground).
2. Create a Persistent Disk for the LLM model weights.
2. Deploy a vLLM container to your cluster to host your model.
3. Use vLLM to serve the Gemma7B model through curl and a web chat interface.
4. View Production metrics for your model serving on GKE
5. Use custom metrics and HPA to scale your model deployments(instances) on GKE.

### Prerequisites
1. The ML Platform [Playground]( https://github.com/GoogleCloudPlatform/ai-on-gke/tree/ml-platform-dev/best-practices/ml-platform/examples/platform/playground) must be deployed
2. Data Set output from the [Data Preparation example](https://github.com/GoogleCloudPlatform/ai-on-gke/tree/ml-platform-dev/best-practices/ml-platform/examples/use-case/datapreparation/gemma-it)
3. Fine tune or other model available ready to be served.If you have been following the [fine tuning exercise with gemma model](https://<github.com/GoogleCloudPlatform/ai-on-gke/tree/ml-platform-dev/best-practices/ml-platform/examples/use-case/finetuning/pytorch), a model artifact would be availble to use in [your model artifacts GCS bucket](https://github.com/GoogleCloudPlatform/ai-on-gke/tree/ml-platform-dev/best-practices/ml-platform/examples/use-case/finetuning/pytorch)
4. Set these Enviorment variables.

```
PROJECT_ID=your-project-id>
PROJECT_NUMBER=$(gcloud projects describe ${PROJECT_ID} --format="value(projectNumber)")
V_MODEL_BUCKET=<model-artifacts-bucket>
CLUSTER_NAME=<your-gke-cluster>
NAMESPACE=ml-serve
KSA=<k8s-service-account>
HF_TOKEN=<your-Hugging-Face-account-token>
MODEL_ID=<your-model-id>
REGION=<your-region>
IMAGE_NAME=<your-image-name>
DISK_NAME=<your-disk-name>
```

## Single GPU (no distributed inference)

If your model fits in a single GPU, you probably don’t need to use distributed inference. Just use the single GPU to run the inference.
You can follow the steps similiar to the Single-Node Multi-GPU (tensor parallel inference)

## Single-Node Multi-GPU (tensor parallel inference):

If your model is too large to fit in a single GPU, but it can fit in a single node with multiple GPUs, you can use tensor parallelism. The tensor parallel size is the number of GPUs you want to use. For example, if you have 4 GPUs in a single node, you can set the tensor parallel size to 4.

#### Prepare your environment with a GKE cluster in Standard mode.

Follow along the steps provide in this README.md( https://github.com/GoogleCloudPlatform/ai-on-gke/tree/ml-platform-dev/best-practices/ml-platform/examples/platform/playground) to create a playground cluster for ML platform on GKE.

You can also re-use the cluster from previous fine-tuning and dataprep exercise as mentioned in pre-requistes.

From the CLI connect to the GKE cluster

```
gcloud container clusters get-credentials ${CLUSTER_NAME} --region $REGION
```

```
kubectl create ns ${NAMESPACE}
```

```
kubectl create sa ${KSA} -n ${NAMESPACE}
```

#### Create a Persistent Disk for the LLM model weights

If you already have LLM model and weights uploaded to a bucket location( as mentioned above) then skip creation of bucket.

##### Optional :  Upload the model and weights to GCS bucket.

Create a GCS bucket in the same region as your GKE cluster.

```
gcloud storage buckets create gs://${V_MODEL_BUCKET} --location ${REGION}
```

Grant permission to kubernetes service account in cluster to access the storage bucket to view model weights

```
gcloud storage buckets add-iam-policy-binding "gs://$V_MODEL_BUCKET" \
--member "principal://iam.googleapis.com/projects/"$PROJECT_NUMBER"/locations/global/workloadIdentityPools/${PROJECT_ID}.svc.id.goog/subject/ns/$NAMESPACE/sa/$KSA" \
--role "roles/storage.objectViewer"
```

Update the bucket access level to uniform.

```
gcloud storage buckets update "gs://$V_MODEL_BUCKET"  --uniform-bucket-level-access
```

Download the model to your local environment. For example, here we are downloading a model from hugging face.

In your local enviornment, install hugging face hub using pip :

```
pip3 install huggingface_hub
```

Download the model using python3 script.:

Note: The model_id that you provided in the script will be downloaded locally to your /tmp/models folder.

```
python3 serving-yamls/download_model_hugging_face.py
```

Upload the model to the GCS bucket.

```
MODEL_ID=<your_model_id> # eg: google/gemma-1.1-7b-it
MODEL_ORG="$(dirname "$MODEL_ID")"      
gsutil cp -r /tmp/models/$MODEL_ORG/  gs://$V_MODEL_BUCKET
```

##### Create PV, PVC and Persistent disk.

Loading model weights from Persistent Volume is one of solutions to load models faster on GKE cluster. In GKE, Persistent Volumes backed by GCP Persistent Disks can be mounted read-only simultaneously  by multiple nodes(ReadOnlyMany), this makes multiple pods access the model weights possible. 

1. Create a PVC for the model weights

```
kubectl apply -f serving-yamls/pvc_disk_image.yaml
```

2. Create a job downloading the models to the volume and review logs for successful completion.

```
sed -i -e "s|_YOUR_BUCKET_NAME_|${V_MODEL_BUCKET}|" serving-yamls/batch_job_download_model_on_pv_volume.yaml
kubectl create -f serving-yamls/batch_job_download_model_on_pv_volume.yaml
kubectl logs  module-download-job-ptdpt-6cq8r
```

Wait for the job to show completion.

```
module-download-job-sg6j7-4bxg4
```

3. Create the PV and PVC

```
PV_NAME="$(kubectl get pvc/block-pvc-model -o jsonpath='{.spec.volumeName}')"
```

```
DISK_REF="$(kubectl get pv "$PV_NAME"  -o jsonpath='{.spec.csi.volumeHandle}')"
```

```
gcloud compute images create model-weights-image --source-disk="$DISK_REF"
```

```
gcloud compute disks create models-fine-tune-disk-v1  --size=1TiB --type=pd-ssd --zone=<enter-your-zone> --image=model-weights-image
Note: Choose a zone based on cluster location and gpu availability
```

```
sed -i -e "s|_NAMESPACE_|${NAMESPACE}|" serving-yamls/pv_and_pvc.yaml
kubectl apply -f serving-yamls/pv_and_pvc.yaml
```

       
#### Deploy a vLLM container to your cluster.

Run the batch job to deploy model using persistent disk on GKE.

```
NAMESPACE=<your-inference-namespace>
ACCELERATOR_TYPE=<gpu-accelerator-type> #e.g nvidia-l4

sed -i -e "s|_NAMESPACE_|${NAMESPACE}|" serving-yamls/batch_job_model_deployment.yaml
sed -i -e "s|_ACCELERATOR_TYPE_|${ACCELERATOR_TYPE}|" serving-yamls/batch_job_model_deployment.yaml

```

```
kubectl create -f serving-yamls/model_deployment.yaml
kubectl describe pods vllm-openai-<replace-the-pod-name> -n ${NAMESPACE}
```

```
INFO:     Started server process [1]
INFO:     Waiting for application startup.
INFO:     Application startup complete.
INFO:     Uvicorn running on http://0.0.0.0:8000 (Press CTRL+C to quit)
```


#### Serve the deployed model through curl and a web chat interface.

You can run curl commands to test prompts for your LLM

ssh into the LLM pod 

```
kubectl exec -it vllm-openai-<your-pod-name> -n ml-serve -- bash
```

Run the curl prompt with your values

```
./servimg-yamls/prompt-n.sh
```

Optional : You can also deploy gradio chat interface to view the model chat interface.

```
sed -i -e "s|_NAMESPACE_|${NAMESPACE}|" serving-yamls/gradio.yaml
kubectl apply -f serving-yamls/gradio.yaml
```

#### Production Metrics
vLLM exposes a number of metrics that can be used to monitor the health of the system. These metrics are exposed via the /metrics endpoint on the vLLM OpenAI compatible API server.


```
kubectl exec -it vllm-openai-6cdc44d69-hrlkz -n ml-serve -- bash
curl http://vllm-openai:8000/metrics
```

#### View Production metrics for your model serving on GKE

You can configure monitoring of the metrics above using the [pod monitoring](https://cloud.google.com/stackdriver/docs/managed-prometheus/setup-managed#gmp-pod-monitoring)

```
kubectl apply -f serving-yamls/pod_monitoring.yaml
```

#### Import the vLLM metrics into cloud monitoring.


Cloud Monitoring provides an [importer](https://cloud.google.com/monitoring/dashboards/import-grafana-dashboards) that you can use to import dashboard files in the Grafana JSON format into Cloud Monitoring


1. Clone github repository 

```
git clone https://github.com/GoogleCloudPlatform/monitoring-dashboard-samples
```


2. Change to the directory for the dashboard importer:

```
cd monitoring-dashboard-samples/scripts/dashboard-importer
```

The dashboard importer includes the following scripts:

import.sh, which converts dashboards and optionally uploads the converted dashboards to Cloud Monitoring.

upload.sh, which uploads the converted dashboards—or any Monitoring dashboards—to Cloud Monitoring. The import.sh script calls this script to do the upload.



3. Import the dashboard

```
./import.sh ./grafana.json ${PROJECT_ID}
```

When you use the import.sh script, you must specify the location of the Grafana dashboards to convert. The importer creates a directory that contains the converted dashboards and other information.


### Run Batch inference on GKE

Once a model has completed fine-tuning and is deployed on GKE , its ready to run batch Inference pipeline.
In this example batch inference pipeline, we would first send prompts to the hosted fine-tuned model and then validate the results based on ground truth.

#### Prepare your environment


Set env variables.

```
PROJECT_ID=<your-project-id>
PROJECT_NUMBER=$(gcloud projects describe ${PROJECT_ID} --format="value(projectNumber)")
CLUSTER_NAME=<your-gke-cluster>
NAMESPACE=ml-serve
MODEL_PATH=<your-model-path>
BUCKET="<your dataset bucket name>"
DATASET_OUTPUT_PATH=""
ENDPOINT=<your-endpoint> # eg "http://vllm-openai:8000/v1/chat/completions"
KSA=<k8s-service-account> # Service account with work-load identity enabled
```

Create Service account.

```
NAMESPACE=ml-serve
kubectl create sa ${KSA} -n ${NAMESPACE}
```

Setup Workload Identity Federation access to read/write to the bucket for the inference batch data set

```
gcloud storage buckets add-iam-policy-binding gs://${BUCKET} \
    --member "principal://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${PROJECT_ID}.svc.id.goog/subject/ns/${NAMESPACE}/sa/${KSA}" \
    --role "roles/storage.objectUser"
```

```
gcloud storage buckets add-iam-policy-binding gs://${BUCKET} \
    --member "principal://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${PROJECT_ID}.svc.id.goog/subject/ns/${NAMESPACE}/sa/${KSA}" \
    --role "roles/storage.legacyBucketWriter"
```

#### Build the image of the source and execute batch inference job

Create Artifact Registry repository for your docker image

```
gcloud artifacts repositories create llm-inference-repository \
    --repository-format=docker \
    --location=us \
    --project=${PROJECT_ID} \
    --async

```

Set Docker Image URL

```
DOCKER_IMAGE_URL=us-docker.pkg.dev/${PROJECT_ID}/llm-inference-repository/validate:v1.0.0
```

Enable the Cloud Build APIs

```
gcloud services enable cloudbuild.googleapis.com --project ${PROJECT_ID}
```

Build container image using Cloud Build and push the image to Artifact Registry Modify cloudbuild.yaml to specify the image url

sed -i "s|IMAGE_URL|${DOCKER_IMAGE_URL}|" cloudbuild.yaml && \
gcloud builds submit . --project ${PROJECT_ID}

Get credentials for the GKE cluster

```
gcloud container fleet memberships get-credentials ${CLUSTER_NAME} --project ${PROJECT_ID}
```

Set variables for the inference job in model-eval.yaml

```
sed -i -e "s|IMAGE_URL|${DOCKER_IMAGE_URL}|" \
    -i -e "s|KSA|${KSA}|" \
    -i -e "s|V_BUCKET|${BUCKET}|" \
    -i -e "s|V_MODEL_PATH|${MODEL_PATH}|" \
    -i -e "s|V_DATASET_OUTPUT_PATH|${DATASET_OUTPUT_PATH}|" \
    -i -e "s|V_ENDPOINT|${ENDPOINT}|" \
    model-eval.yaml
```

Create the Job in the ml-team namespace using kubectl command

```
kubectl apply -f model-eval.yaml -n ${NAMESPACE}
```

You can review predictions result in file named `predictions.txt` .Sample file has been added to the repository.
The job will take approx 45 mins to execute.

### Run Benchmarks for inference

The model is ready to run the benchmarks for inference job. We can run few performance tests using locust.
Locust is an open source performance/load testing tool for HTTP and other protocols.
You can refer to the documentation to [set up](https://docs.locust.io/en/stable/installation.html) locust locally or deploy as a container on GKE.

We have created a sample [locustfile](https://docs.locust.io/en/stable/writing-a-locustfile.html) to run tests against our model using sample prompts which we tried earlier in the exercise.
Here is a sample ![graph](./serving-yamls/benchmarks/locust.py) to review.

If you have a local set up for locust. You can execute the tests using following :


```
cd benchmarks
$locust
```

You can update the service end point of model to LoadBalancer(type) to ensure you can reach the hosted model's endpoint outside the ml-serve namespace . You can access the model endpoint using correct [annotation](https://cloud.google.com/kubernetes-engine/docs/concepts/service-load-balancer#load_balancer_types)




### Inference at Scale

There are different metrics available that could be used to autoscale your inference workloads on GKE.

1. Server metrics: LLM inference servers vLLM provides workload-specific performance metrics. GKE simplifies scraping and autoscaling of workloads based on these server-level metrics. You can use these metrics to gain visibility into performance indicators like batch size, queue size, and decode latencies

In case of vLLM, [production metrics class](https://docs.vllm.ai/en/latest/serving/metrics.html) exposes a number of useful metrics whch GKE can use to autoscale inference workloads.

```
vllm:num_requests_running : Number of requests currently running on GPU.
vllm:num_requests_waiting : Number of requests waiting to be processed
```

2. GPU metrics:

```
GPU Utilization (DCGM_FI_DEV_GPU_UTIL)	Measures the duty cycle, which is the amount of time that the GPU is active.
GPU Memory Usage (DCGM_FI_DEV_FB_USED)	Measures how much GPU memory is being used at a given point in time. This is useful for workloads that implement dynamic allocation of GPU memory.
```

3. CPU metrics: Since the inference workloads primarily rely on GPU resources , we don't recommend CPU and memory utilization as the only indicators of the amount of resources a job consumes.Therefore, using CPU metrics alone for autoscaling can lead to suboptimal performance and costs. 
 
HPA is an efficient way to ensure that your model servers scale appropriately with load. Fine-tuning the HPA settings is the primary way to align your provisioned hardware cost with traffic demands to achieve your inference server performance goals.

We recommend setting these HPA configuration options:

Stabilization window: Use this HPA configuration option to prevent rapid replica count changes due to fluctuating metrics. Defaults are 5 minutes for scale-down (avoiding premature downscaling) and 0 for scale-up (ensuring responsiveness). Adjust the value based on your workload's volatility and your preferred responsiveness.
Scaling policies: Use this HPA configuration option to fine-tune the scale-up and scale-down behavior. You can set the "Pods" policy limit to specify the absolute number of replicas changed per time unit, and the "Percent" policy limit to specify by the percentage change.

For more details, see Horizontal pod autoscaling in the Google Cloud Managed Service for Prometheus [documentation](https://cloud.google.com/kubernetes-engine/docs/horizontal-pod-autoscaling).


Pre-requistes:

1. GKE cluster running inference workload as shown in previous examples.
2. Export the metrics from the vLLM server to Cloud Monitoring as shown in enable monitoring section.

We have couple of options to scale the inference workload on GKE using the HPA and custom metrics adapter.

1. Scale pod on the same node as the existing inference workload.
2. Scale pod on the other nodes in the same node pool as the existing inference workload.


#### Prepare your environment to autoscale with HPA metrics


1. Install the Custom Metrics Stackdriver Adapter. This adapter makes the custom metric that you exported to Cloud Monitoring visible to the HPA controller. For more details, see Horizontal pod autoscaling in the Google Cloud Managed Service for Prometheus documentation.

The following example command shows how to install the adapter:

```
kubectl apply -f kubectl apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/k8s-stackdriver/master/custom-metrics-stackdriver-adapter/deploy/production/adapter_new_resource_model.yaml
```

2. Set up the custom metric-based HPA resource. Deploy an HPA resource that is based on your preferred custom metric. 

Select ONE of yamls to configure the HorizontalPodAutoscaler resource in your manifest:

< Add vllm Metrics Dashboard here >



Add the appropriate target values for vllm:num_requests_running or vllm:num_requests_waiting in hte yaml file.

Queue-depth
```
NAMESPACE=ml-serve
kubectl apply -f serving-yamls/inference-scale/hpa-vllm-openai-queue-size.yaml -n ${NAMESPACE}

```

OR

Batch-size
```
NAMESPACE=ml-serve
kubectl apply -f serving-yamls/inference-scale/hpa-vllm-openai-batch-size.yaml -n ${NAMESPACE}
```

Note: I used Batch Size HPA to run the scale test below:

```
kubectl get  hpa vllm-openai-hpa -n ml-serve --watch
NAME              REFERENCE                TARGETS   MINPODS   MAXPODS   REPLICAS   AGE
vllm-openai-hpa   Deployment/vllm-openai   0/10      1         5         1          6d16h
vllm-openai-hpa   Deployment/vllm-openai   13/10     1         5         1          6d16h
vllm-openai-hpa   Deployment/vllm-openai   17/10     1         5         2          6d16h
vllm-openai-hpa   Deployment/vllm-openai   12/10     1         5         2          6d16h
vllm-openai-hpa   Deployment/vllm-openai   17/10     1         5         2          6d16h
vllm-openai-hpa   Deployment/vllm-openai   14/10     1         5         2          6d16h
vllm-openai-hpa   Deployment/vllm-openai   17/10     1         5         2          6d16h
vllm-openai-hpa   Deployment/vllm-openai   10/10     1         5         2          6d16h

```

```
kubectl get pods -n ml-serve --watch
NAME                           READY   STATUS      RESTARTS   AGE
gradio-6b8698d7b4-88zm7        1/1     Running     0          10d
model-eval-2sxg2               0/1     Completed   0          8d
vllm-openai-767b477b77-2jm4v   1/1     Running     0          3d17h
vllm-openai-767b477b77-82l8v   0/1     Pending     0          9s
```

Pod scaled up
```
kubectl get pods -n ml-serve --watch
NAME                           READY   STATUS      RESTARTS   AGE
gradio-6b8698d7b4-88zm7        1/1     Running     0          10d
model-eval-2sxg2               0/1     Completed   0          8d
vllm-openai-767b477b77-2jm4v   1/1     Running     0          3d17h
vllm-openai-767b477b77-82l8v   1/1     Running     0          111s
```

The new pod is deployed on a node triggered by autoscaler.
Note: The existing node where inference workload was deployed in this case had only two GPUS. Hence a new node is required to deploy the copy pod of inference workload.

```
kubectl describe pods vllm-openai-767b477b77-82l8v -n ml-serve

Events:
  Type     Reason                  Age    From                                   Message
  ----     ------                  ----   ----                                   -------
  Warning  FailedScheduling        4m15s  gke.io/optimize-utilization-scheduler  0/3 nodes are available: 1 Insufficient ephemeral-storage, 1 Insufficient nvidia.com/gpu, 2 node(s) didn't match Pod's node affinity/selector. preemption: 0/3 nodes are available: 1 No preemption victims found for incoming pod, 2 Preemption is not helpful for scheduling.
  Normal   TriggeredScaleUp        4m13s  cluster-autoscaler                     pod triggered scale-up: [{https://www.googleapis.com/compute/v1/projects/gkebatchexpce3c8dcb/zones/us-east4-a/instanceGroups/gke-kh-e2e-l4-2-c399c5c0-grp 1->2 (max: 20)}]
  Normal   Scheduled               2m40s  gke.io/optimize-utilization-scheduler  Successfully assigned ml-serve/vllm-openai-767b477b77-82l8v to gke-kh-e2e-l4-2-c399c5c0-vvm9
  Normal   SuccessfulAttachVolume  2m36s  attachdetach-controller                AttachVolume.Attach succeeded for volume "model-weights-disk-1024gb-zone-a"
  Normal   Pulling                 2m29s  kubelet                                Pulling image "vllm/vllm-openai:v0.5.3.post1"
  Normal   Pulled                  2m25s  kubelet                                Successfully pulled image "vllm/vllm-openai:v0.5.3.post1" in 4.546s (4.546s including waiting). Image size: 5586843591 bytes.
  Normal   Created                 2m25s  kubelet                                Created container inference-server
  Normal   Started                 2m25s  kubelet                                Started container inference-server

```


#### Prepare your environment to autoscale with GPU metrics

Another option is to scale the workloads using GPU metrics provided by Cloud Monitoring using GKE or DCGM

1. Export the GPU metrics to Cloud Monitoring. If your GKE cluster has system metrics enabled, it automatically sends the GPU utilization metric to Cloud Monitoring through the container/accelerator/duty_cycle system metric, every 60 seconds.

For this ML Platform, we have enabled and exported DCGM metrics to Cloud Monitoring as well.

< Add GPU Metrics Dashboard here >

In the code, make sure to change the DCGM metric name to use in HPA to lowercase. This is because there's a known issue where HPA doesn't work with uppercase external metric names.

2. Install the Custom Metrics Stackdriver Adapter. This adapter makes the custom metric you exported to Monitoring visible to the HPA controller. The following example command shows how to execute this installation:


```
kubectl apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/k8s-stackdriver/master/custom-metrics-stackdriver-adapter/deploy/production/adapter_new_resource_model.yaml
```

3. Set up the custom metric-based HPA resource. Deploy a HPA resource based on your preferred custom metric. 
Identify an average value target for HPA to trigger autoscaling. You can do this experimentally; for example, generate increasing load on your server and observe where your GPU utilization peaks. Be mindful of the HPA tolerance, which defaults to a 0.1 no-action range around the target value to dampen oscillation.
We recommend using the locust-load-inference tool for testing. You can also create a Cloud Monitoring custom dashboard to visualize the metric behavior.

Scale with GKE metrics

```
NAMESPACE=ml-serve
sed -i -e "s|_NAMESPACE_|${NAMESPACE}|" serving-yamls/inference-scale/custom-metrics-gpu-duty-cycle-gke.yaml
kubectl apply -f serving-yamls/inference-scale/custom-metrics-gpu-duty-cycle-gke.yaml -n ${NAMESPACE}

```
Scale with DCGM metrics

```
NAMESPACE=ml-serve
sed -i -e "s|_NAMESPACE_|${NAMESPACE}|" serving-yamls/inference-scale/custom-metrics-gpu-duty-cycle-dcgm.yaml
kubectl apply -f serving-yamls/inference-scale/custom-metrics-gpu-duty-cycle-dcgm.yaml -n ${NAMESPACE}
```






