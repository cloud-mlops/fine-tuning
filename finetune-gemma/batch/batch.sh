#!/bin/bash
set -x
FILE=fine-tune
source params.env
# Check for any overriding values in params
if [ -z "${HP_EXPERIMENT}" ]; then
  HP_EXPERIMENT=${EXPERIMENT}
fi

if [ -z "${HP_IMAGE_URL}" ]; then
  HP_IMAGE_URL=${IMAGE_URL}
fi

if [ -z "${HP_MODEL_NAME}" ]; then
  HP_MODEL_NAME=${MODEL_NAME}
fi

if [ -z "${HP_MODEL_BUCKET}" ]; then
  HP_MODEL_BUCKET=${MODEL_BUCKET}
fi

if [ -z "${HP_MODEL_PATH}" ]; then
  HP_MODEL_PATH=${MODEL_PATH}
fi

if [ -z "${HP_TRAINING_DATASET_BUCKET}" ]; then
  HP_TRAINING_DATASET_BUCKET=${TRAINING_DATASET_BUCKET}
fi

# We need the commit tag from the overriding path
# If there is an overriding path, extract the tag to be used
if [ -z "${HP_TRAINING_DATASET_PATH}" ]; then
  HP_TRAINING_DATASET_PATH=${TRAINING_DATASET_PATH}
else
  DATA_COMMIT=${HP_TRAINING_DATASET_PATH##*-}
fi

for IDX in ${!V_LORA_R[@]}
do
    export J_IT=${IDX}
    export JOB_ID=${DATA_COMMIT}it${J_IT}
    
    sed -e s/J_ID/${JOB_ID}/g \
        -e s/V_LORA_R/${V_LORA_R[IDX]}/g \
        -e s/V_LORA_ALPHA/${V_LORA_ALPHA[IDX]}/g \
        -e s/V_LORA_DROPOUT/${V_LORA_DROPOUT[IDX]}/g \
        -e s/V_NUM_TRAIN_EPOCHS/${V_NUM_TRAIN_EPOCHS[IDX]}/g \
        -e s/V_MAX_GRAD_NORM/${V_MAX_GRAD_NORM[IDX]}/g \
        -e s/V_LEARNING_RATE/${V_LEARNING_RATE[IDX]}/g \
        -e s/V_WEIGHT_DECAY/${V_WEIGHT_DECAY[IDX]}/g \
        -e s/V_WARMUP_RATIO/${V_WARMUP_RATIO[IDX]}/g \
        -e s/V_MAX_SEQ_LENGTH/${V_MAX_SEQ_LENGTH[IDX]}/g \
        -e s,IMAGE_URL,${HP_IMAGE_URL},g \
        -e s/V_EXPERIMENT/${HP_EXPERIMENT}-${DATA_COMMIT}/g \
        -e s/V_MODEL_BUCKET/${HP_MODEL_BUCKET}/g \
        -e s,V_MODEL_NAME,${HP_MODEL_NAME},g \
        -e s/V_TRAINING_DATASET_BUCKET/${HP_TRAINING_DATASET_BUCKET}/g \
        -e s,V_TRAINING_DATASET_PATH,/${HP_TRAINING_DATASET_PATH}/training,g \
        -e s,V_MODEL_PATH,/${HP_MODEL_PATH}-${JOB_ID},g \
        ${FILE}.yaml > ${FILE}-${JOB_ID}.yaml
    kubectl apply -f ${FILE}-${JOB_ID}.yaml -n ml-team
done