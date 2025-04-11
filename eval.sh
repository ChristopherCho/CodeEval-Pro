while getopts "m:n:o:t:" opt; do
    case $opt in
        m) MODEL_PATH=$OPTARG;;
        n) MODEL_NAME=$OPTARG;;
        o) OUTPUT_DIR=$OPTARG;;
        t) TASK=$OPTARG;;
    esac
done

if [ -z "$MODEL_PATH" ]; then
    echo "MODEL_PATH is not provided"
    exit 1
fi

if [ -z "$MODEL_NAME" ]; then
    MODEL_NAME=$(basename $MODEL_PATH)
    echo "MODEL_NAME is not provided. Set to $MODEL_NAME"
fi

if [ -z "$OUTPUT_DIR" ]; then
    OUTPUT_DIR=result/${MODEL_NAME}
    echo "OUTPUT_DIR is not provided. Set to $OUTPUT_DIR"
fi

if [ -z "$TASK" ]; then
    echo "TASK is not provided. Set to all"
    TASKS=(
        humaneval_pro
        humaneval_pro_cot
        humaneval_pro_1shot
        mbpp_pro
        mbpp_pro_cot
        mbpp_pro_1shot
    )
else
    TASKS=($TASK)
fi

export VLLM_WORKER_MULTIPROC_METHOD=spawn

set -e

inference() {
    local TASK_TYPE=$1
    local output_file_path=${OUTPUT_DIR}/${TASK_TYPE}/outputs/results.jsonl
    if [ -f $output_file_path ]; then
        echo "Output file already exists. Skipping inference." >&2
        echo "X"
        return
    fi

    (
        python -m eval.inference \
            --model_name_or_path $MODEL_PATH \
            --save_path ${output_file_path} \
            --dataset $TASK_TYPE \
            --is_use_vllm true \
            --do_sample false \
            --temperature 0.0 \
            --top_p 1.0 \
            --max_new_tokens 4096 \
            --n_problems_per_batch 28 \
            --n_samples_per_problem 1 \
            --n_batches 1
    ) >/dev/null 2>&1
    
    echo "O"
}

sanitize() {
    local TASK_TYPE=$1
    local output_file_path=${OUTPUT_DIR}/${TASK_TYPE}/outputs/santized_results.jsonl
    if [ -f $output_file_path ]; then
        echo "Output file already exists. Skipping sanitize." >&2
        echo "X"
        return 
    fi

    (
        python -m eval.santize \
            --model_name $MODEL_NAME \
            --source_path ${OUTPUT_DIR}/${TASK_TYPE}/outputs/
    ) >/dev/null 2>&1
    
    echo "O"
}

harness() {
    local TASK_TYPE=$1
    local output_file_path=${OUTPUT_DIR}/${TASK_TYPE}/result_of_pass_k.json
    if [ -f $output_file_path ]; then
        echo "Output file already exists. Skipping harness." >&2
        echo "X"
        return
    fi

    local humaneval_dataset_path=dataset/humaneval_pro.json
    local humaneval_variations=(
        humaneval_pro
        humaneval_pro_cot
        humaneval_pro_1shot
    )

    local mbpp_dataset_path=dataset/mbpp_pro.json
    local mbpp_variations=(
        mbpp_pro
        mbpp_pro_cot
        mbpp_pro_1shot
    )

    if [[ " ${humaneval_variations[@]} " =~ " ${TASK_TYPE} " ]]; then
        dataset_path=$humaneval_dataset_path
    elif [[ " ${mbpp_variations[@]} " =~ " ${TASK_TYPE} " ]]; then
        dataset_path=$mbpp_dataset_path
    else
        echo "Invalid task type: $TASK_TYPE"
        exit 1
    fi

    (
        python -m eval.harness \
            --model_name $MODEL_NAME \
            --task $TASK_TYPE \
            --dataset_path $dataset_path \
            --source_path ${OUTPUT_DIR}/${TASK_TYPE}/outputs/ \
            --save_path ${OUTPUT_DIR}/${TASK_TYPE} \
            --run_code
    ) >/dev/null 2>&1

    echo "O"
}

for task in "${TASKS[@]}"; do
    mkdir -p ${OUTPUT_DIR}/${task}/outputs/

    echo "Evaluating $task"
    SECONDS=0

    inference_status=$(inference $task 2>/dev/null)
    sanitize_status=$(sanitize $task 2>/dev/null)
    harness_status=$(harness $task 2>/dev/null)

    duration=$SECONDS

    status_line="[$(date)] Time taken: $duration seconds; Inference: $inference_status; Sanitize: $sanitize_status; Harness: $harness_status"
    echo $status_line >> ${OUTPUT_DIR}/${task}/time_taken.txt
done
