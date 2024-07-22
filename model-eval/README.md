# Model evaluation and validation

Once a model has completed fine-tuning, the model must be validated for precision and accuracy
against the dataset used to fine-tune the model. In this example, the model is deployed on an 
inference serving engine to host the model for the model validaiton to take place.  Two steps are performed
for this activity, the first is to send prompts to the fine-tuned model, the second is to validate the results.

# Build the image of the source
- Modify cloudbuild.yaml to specify the image url
```
gcloud builds submit .
```

## Model evaluation Job inputs
- For `model-eval.yaml`
| Variable | Description | Example |
| --- | --- | --- |
| IMAGE_URL | The image url of the validate image | |
| BUCKET | The bucket where the fine-tuning data set is located | kh-finetune-ds | 
| MODEL_PATH | The output folder path for the fine-tuned model.  This is used by model evaluation to generate the prompt. | /model-data/model-gemma2-a100/experiment |
| DATASET_TAG | This is the unique tag/suffix of the dataset. Mapped to a generated commit id, i.e output-[id] | | 
| DATASET_OUTPUT_PATH | The folder path of the generated output data set. | dataset/output |
| ENDPOINT | This is the endpoint URL of the inference server | http://10.40.0.51:8000/v1/chat/completions | 

- For `vllm-openai.yaml`
| IMAGE_URL | The image url for the vllm image | |
| MODEL | The output folder path for the fine-tuned model | |