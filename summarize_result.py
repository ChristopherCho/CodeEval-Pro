import os
import re
import json
import argparse

from tabulate import tabulate


def get_task_result(task_path):
    result_file_path = os.path.join(task_path, "result_of_pass_k.json")
    with open(result_file_path, "r") as f:
        result = json.load(f)
    
    pass_k_of_output = result["results"]["pass_k_of_output"]["pass@1"]
    pass_k_of_output_santized = result["results"]["pass_k_of_output_santized"]["pass@1"]
    
    result_str = f"{pass_k_of_output*100:.1f}"
    if pass_k_of_output != pass_k_of_output_santized:
        result_str += f"/{pass_k_of_output_santized*100:.1f})"

    time_file_path = os.path.join(task_path, "time_taken.txt")
    with open(time_file_path, "r") as f:
        time_taken = f.read()

    time_taken = re.search(r"Time taken: (\d+) seconds", time_taken).group(1)
    
    return result_str, time_taken


def get_model_result(model_path):
    model_name = os.path.basename(model_path)
    tasks = [
        "humaneval_pro",
        "humaneval_pro_1shot",
        "humaneval_pro_cot",
        "mbpp_pro",
        "mbpp_pro_1shot",
        "mbpp_pro_cot",
    ]

    model_result = [model_name]
    for task in sorted(tasks):
        task_path = os.path.join(model_path, task)
        result_str, time_taken = get_task_result(task_path)
        model_result.append(f"{result_str} ({time_taken}s)")
    
    return model_result


def main(args):
    table = [
        ["Score: Pass@1 (Time taken)", "HumanEval-Pro", "", "", "MBPP-Pro", "", ""],
        ["Model", "0-shot", "1-shot", "CoT", "0-shot", "1-shot", "CoT"],
    ]
    
    models = os.listdir(args.result_dir)
    for model in models:
        model_path = os.path.join(args.result_dir, model)
        model_result = get_model_result(model_path)
        table.append(model_result)
    
    print(tabulate(table, headers="firstrow", tablefmt="github"))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--result_dir", type=str, default="result")
    args = parser.parse_args()

    main(args)
