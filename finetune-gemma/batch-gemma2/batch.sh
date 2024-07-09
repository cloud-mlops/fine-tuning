#!/bin/bash
FILE=fine-tune-multi

V_LORA_R=(8 16 32)
V_LORA_ALPHA=(16 32 64)
V_LORA_DROPOUT=(0.1 0.2 0.3)
V_NUM_TRAIN_EPOCHS=(2 3 4)
V_MAX_GRAD_NORM=(1.0 1.0 1.0)
V_LEARNING_RATE=(2e-5 2e-4 3e-4)
V_WEIGHT_DECAY=(.01 .005 .001)
V_WARMUP_RATIO=(0.1 0.2 0.3)
V_MAX_SEQ_LENGTH=(1024 2048 8192)

for IDX in ${!V_LORA_R[@]}
do
    export J_IT=${IDX}
    sed -e s/J_IT/${J_IT}/g \
        -e s/V_LORA_R/${V_LORA_R[IDX]}/g \
        -e s/V_LORA_ALPHA/${V_LORA_ALPHA[IDX]}/g \
        -e s/V_LORA_DROPOUT/${V_LORA_DROPOUT[IDX]}/g \
        -e s/V_NUM_TRAIN_EPOCHS/${V_NUM_TRAIN_EPOCHS[IDX]}/g\
        -e s/V_MAX_GRAD_NORM/${V_MAX_GRAD_NORM[IDX]}/g\
        -e s/V_LEARNING_RATE/${V_LEARNING_RATE[IDX]}/g\
        -e s/V_WEIGHT_DECAY/${V_WEIGHT_DECAY[IDX]}/g\
        -e s/V_WARMUP_RATIO/${V_WARMUP_RATIO[IDX]}/g\
        -e s/V_MAX_SEQ_LENGTH/${V_MAX_SEQ_LENGTH[IDX]}/g\
        ${FILE}.yaml > ${FILE}-${J_IT}.yaml

    kubectl apply -f ${FILE}-${J_IT}.yaml -n ml-team
    sleep 60
done