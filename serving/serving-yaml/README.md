# Standalone vLLM
## vLLM Pod
- Update the image & bucket
```
env:
- name: MODEL
    value: /model-data/hyperparam/model-job-1
...
bucketName: kh-test-data
```

- Deploy the vLLM Pod which will load the model from GCS
```
kubectl apply -f vllm-openai.yaml -n ml-team
```

## vLLM Pod Monitoring for Prometheus
Deploy pod monitoring
```
kubectl apply -f pod-monitoring.yaml -n ml-team
```

## Custom metrics HPA
Install the adapter
```
kubectl apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/k8s-stackdriver/master/custom-metrics-stackdriver-adapter/deploy/production/adapter_new_resource_model.yaml

gcloud projects add-iam-policy-binding projects/gkebatchexpce3c8dcb \
  --role roles/monitoring.viewer \
  --member=principal://iam.googleapis.com/projects/348087736605/locations/global/workloadIdentityPools/gkebatchexpce3c8dcb.svc.id.goog/subject/ns/custom-metrics/sa/custom-metrics-stackdriver-adapter
```

Deploy the HPA resource
```
kubectl apply -f hpa-vllm-openai.yaml -n ml-team
```

Output - HPA status
```
Name:                                                                   vllm-openai-hpa
Namespace:                                                              ml-team
Labels:                                                                 <none>
Annotations:                                                            <none>
CreationTimestamp:                                                      Wed, 03 Jul 2024 00:04:31 +0000
Reference:                                                              Deployment/vllm-openai
Metrics:                                                                ( current / target )
  "prometheus.googleapis.com|vllm:num_requests_running|gauge" on pods:  50 / 10
Min replicas:                                                           1
Max replicas:                                                           5
Deployment pods:                                                        5 current / 5 desired
Conditions:
  Type            Status  Reason               Message
  ----            ------  ------               -------
  AbleToScale     True    ScaleDownStabilized  recent recommendations were higher than current one, applying the highest recent recommendation
  ScalingActive   True    ValidMetricFound     the HPA was able to successfully calculate a replica count from pods metric prometheus.googleapis.com|vllm:num_requests_running|gauge
  ScalingLimited  True    TooManyReplicas      the desired replica count is more than the maximum replica count
Events:
  Type    Reason             Age   From                       Message
  ----    ------             ----  ----                       -------
  Normal  SuccessfulRescale  92s   horizontal-pod-autoscaler  New size: 4; reason: pods metric prometheus.googleapis.com|vllm:num_requests_running|gauge above target
  Normal  SuccessfulRescale  76s   horizontal-pod-autoscaler  New size: 5; reason: pods metric prometheus.googleapis.com|vllm:num_requests_running|gauge above target
```

Output - Pod Status Scaling Up
```
vllm-openai-59897668c4-5fsd5                               1/2     PodInitializing   0               2m13s
vllm-openai-59897668c4-hw5h9                               2/2     Running           0               3d19h
vllm-openai-59897668c4-phkbh                               1/2     PodInitializing   0               117s
vllm-openai-59897668c4-q7kj6                               1/2     PodInitializing   0               2m13s
vllm-openai-59897668c4-vd797                               1/2     PodInitializing   0               2m13s
```

Output - HPA Scaling Down
```
Name:                                                                   vllm-openai-hpa
Namespace:                                                              ml-team
Labels:                                                                 <none>
Annotations:                                                            <none>
CreationTimestamp:                                                      Wed, 03 Jul 2024 00:04:31 +0000
Reference:                                                              Deployment/vllm-openai
Metrics:                                                                ( current / target )
  "prometheus.googleapis.com|vllm:num_requests_running|gauge" on pods:  0 / 10
Min replicas:                                                           1
Max replicas:                                                           5
Deployment pods:                                                        4 current / 3 desired
Conditions:
  Type            Status  Reason              Message
  ----            ------  ------              -------
  AbleToScale     True    SucceededRescale    the HPA controller was able to update the target scale to 3
  ScalingActive   True    ValidMetricFound    the HPA was able to successfully calculate a replica count from pods metric prometheus.googleapis.com|vllm:num_requests_running|gauge
  ScalingLimited  False   DesiredWithinRange  the desired count is within the acceptable range
Events:
  Type    Reason             Age    From                       Message
  ----    ------             ----   ----                       -------
  Normal  SuccessfulRescale  22m    horizontal-pod-autoscaler  New size: 4; reason: pods metric prometheus.googleapis.com|vllm:num_requests_running|gauge above target
  Normal  SuccessfulRescale  21m    horizontal-pod-autoscaler  New size: 5; reason: pods metric prometheus.googleapis.com|vllm:num_requests_running|gauge above target
  Normal  SuccessfulRescale  5m18s  horizontal-pod-autoscaler  New size: 4; reason: pods metric prometheus.googleapis.com|vllm:num_requests_running|gauge below target
  Normal  SuccessfulRescale  15s    horizontal-pod-autoscaler  New size: 3; reason: pods metric prometheus.googleapis.com|vllm:num_requests_running|gauge below target
```

## Import vLLM Dashboard to Cloud Monitoring
```
git clone https://github.com/GoogleCloudPlatform/monitoring-dashboard-samples
cd monitoring-dashboard-samples/scripts/dashboard-importer
./import.sh ./grafana.json gkebatchexpce3c8dcb
```

# Ray Service + vLLM
- Update the image & bucket
```
MODEL_ID: "/model-data/hyperparam/model-job-1"
...
bucketName: kh-test-data
```

- Deploy the Ray Service, the workers will load the model from GCS
```
kubectl apply -f rayserve-vllm.yaml -n ml-team
```

Describe the Ray Service for controller details
```
kubectl describe rayservice gemma-ft -n ml-team
```

Output - Running
```
...
Status:
  Active Service Status:
    Application Statuses:
      Llm:
        Health Last Update Time:  2024-07-02T20:47:23Z
        Serve Deployment Statuses:
          VLLM Deployment:
            Health Last Update Time:  2024-07-02T20:47:23Z
            Status:                   HEALTHY
        Status:                       RUNNING
    Ray Cluster Name:                 gemma-ft-raycluster-q25t6
...
```

Output - Triggered Scaling
```
...
Status:
  Active Service Status:
    Application Statuses:
      Llm:
        Health Last Update Time:  2024-07-03T00:18:34Z
        Serve Deployment Statuses:
          VLLM Deployment:
            Health Last Update Time:  2024-07-03T00:18:34Z
            Message:                  Upscaling from 1 to 4 replicas.
            Status:                   UPSCALING
        Status:                       RUNNING
    Ray Cluster Name:                 gemma-ft-raycluster-q25t6
...
```

Output - Model Loading
```
...
Status:
  Active Service Status:
    Application Statuses:
      Llm:
        Health Last Update Time:  2024-07-03T00:30:35Z
        Serve Deployment Statuses:
          VLLM Deployment:
            Health Last Update Time:  2024-07-03T00:30:35Z
            Message:                  Deployment 'VLLMDeployment' in application 'llm' has 2 replicas that have taken more than 30s to initialize. This may be caused by a slow __init__ or reconfigure method.
            Status:                   UPSCALING
        Status:                       RUNNING
    Ray Cluster Name:                 gemma-ft-raycluster-q25t6
    Ray Cluster Status:
      Available Worker Replicas:  4
      Desired CPU:                34
      Desired GPU:                8
      Desired Memory:             108Gi
      Desired TPU:                0
      Desired Worker Replicas:    4
...
```

Output - Pod Status Scaling Up
```
NAME                                               READY   STATUS    RESTARTS   AGE
gemma-ft-raycluster-q25t6-head-pwkvd               3/3     Running   0          5h22m
gemma-ft-raycluster-q25t6-worker-gpu-group-br2p5   0/3     Pending   0          64s
gemma-ft-raycluster-q25t6-worker-gpu-group-jrsst   0/3     Pending   0          64s
gemma-ft-raycluster-q25t6-worker-gpu-group-kktvz   3/3     Running   0          4h33m
gemma-ft-raycluster-q25t6-worker-gpu-group-wr4cw   0/3     Pending   0          64s
```

Output - Scaling Down
```
Status:
  Active Service Status:
    Application Statuses:
      Llm:
        Health Last Update Time:  2024-07-03T00:39:35Z
        Serve Deployment Statuses:
          VLLM Deployment:
            Health Last Update Time:  2024-07-03T00:39:35Z
            Message:                  Deployment 'VLLMDeployment' in application 'llm' has 1 replicas that have taken more than 30s to initialize. This may be caused by a slow __init__ or reconfigure method.
            Status:                   DOWNSCALING
        Status:                       RUNNING
    Ray Cluster Name:                 gemma-ft-raycluster-q25t6
    Ray Cluster Status:
      Available Worker Replicas:  3
      Desired CPU:                26
      Desired GPU:                6
      Desired Memory:             83Gi
      Desired TPU:                0
      Desired Worker Replicas:    3
```

## Additional Files
```
rayserve-vllm-local.yaml # Load code as a configmap for custom updates
rayserve-vllm-mlp.yaml   # MLP specific, head KSA is ray-head
```