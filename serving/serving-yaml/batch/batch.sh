#!/bin/bash

FILE=vllm-openai
MODEL_PATH_PREFIX=/model-data/hyperparam-gemma2/model-job-

for i in {0..2}
do
    sed -e "s|MODEL_PATH|${MODEL_PATH_PREFIX}${i}|g" \
        -e "s|J_IT|${i}|g" \
        ${FILE}.yaml > ${FILE}-${i}.yaml
    kubectl apply -f ${FILE}-${i}.yaml -n ml-team
done
