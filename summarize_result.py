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
    
    result_str = f"{pass_k_of_output*100:.2f}"
    if pass_k_of_output != pass_k_of_output_santized:
        result_str += f" (santized: {pass_k_of_output_santized*100:.2f})"

    time_file_path = os.path.join(task_path, "time_taken.txt")
    with open(time_file_path, "r") as f:
        time_taken = f.read()
        ### [Tue Apr 1 07:33:17 UTC 2025] Time taken: 284 seconds; Inference: O; Sanitize: O; Harness: O

    time_taken = re.search(r"Time taken: (\d+) seconds", time_taken).group(1)
    
    return result_str, time_taken


def get_model_result(model_path):
    model_name = os.path.basename(model_path)
    print(f"# {model_name}")

    result_table = [["Task", "Score (pass@1)", "Time taken (s)"]]
    
    tasks = os.listdir(model_path)
    for task in sorted(tasks):
        task_path = os.path.join(model_path, task)
        result_str, time_taken = get_task_result(task_path)
        result_table.append([task, result_str, time_taken])
    
    print(tabulate(result_table, headers="firstrow", tablefmt="github"))
    print()


def main(args):
    models = os.listdir(args.result_dir)
    for model in models:
        model_path = os.path.join(args.result_dir, model)
        get_model_result(model_path)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--result_dir", type=str, default="result")
    args = parser.parse_args()

    main(args)
