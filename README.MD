# Huawei Cloud Update FunctionGraph Script
---
## Description

This Bash script is designed to automate the deployment of a function to the Huawei Cloud FunctionGraph service. The script performs a variety of tasks such as environment setup, dependency management, and function deployment.

## Requirements

1. `(koocli)[https://support.huaweicloud.com/intl/en-us/qs-hcli/hcli_02_003_02.html]` CLI installed.
2. `jq` for JSON manipulation.
3. `(obsutil)[https://support.huaweicloud.com/intl/en-us/utiltg-obs/obs_11_0003.html]` for Huawei OBS operations.
4. `expect` for automating interactive tasks.
5. `zip` for compressing the function folder.
6. A running Huawei Cloud account and an existing project.

## Environment Variables

The script expects the following environment variables to be set:

- `FUNC_NAME`: The name of the function.
- `REGION`: The region where the function resides.
- `PROJECT_ID`: Your Huawei Cloud Project ID.
- `DEPENDENCIES`: A comma-separated list of dependencies the function needs.
- `ACCESS_KEY`: Your Huawei Cloud access key.
- `SECRET_KEY`: Your Huawei Cloud secret key.
- `HANDLER`: The function handler.
- `MEMORY_SIZE`: The memory size allocated for the function.
- `RUNTIME`: The runtime environment for the function (e.g., Python3.6).
- `TIMEOUT`: The timeout for the function execution.
- `FUNCTIONGRAPH_*`: Environment variables starting with "FUNCTIONGRAPH_" will be used as function configuration parameters.

**Optional:**
- `AGENCY_NAME`: The name of the agency role with permissions (optional).

## How to Use

1. **Download the script:**

   Use `curl` or `wget` to download the raw script:

   ```bash
   curl -O https://raw.githubusercontent.com/Buronn/huaweicloud-update-functiongraph-script/main/entrypoint.sh
   ```
   Or
   ```bash
   wget https://raw.githubusercontent.com/Buronn/huaweicloud-update-functiongraph-script/main/entrypoint.sh
   ```

2. **Make the script executable:**

   ```bash
   chmod +x entrypoint.sh
   ```

3. **Set environment variables:**

   You can either export them in your shell session or put them in a `.env` file.

   ```bash
   export FUNC_NAME="my_function"
   export REGION="cn-north-4"
   export PROJECT_ID="your_project_id"
   # ... (set all required variables)
   ```

   Or, in a `.env` file:

   ```env
   FUNC_NAME=my_function
   REGION=cn-north-4
   PROJECT_ID=your_project_id
   # ... (set all required variables)
   ```

   If you use a `.env` file, make sure to source it:

   ```bash
   source .env
   ```

4. **Run the script:**

   ```bash
   ./entrypoint.sh
   ```

## Troubleshooting

- Make sure you have all required CLI tools installed (`hcloud`, `jq`, `obsutil`, `expect`, `zip`).
- Ensure all environment variables are set before running the script.
- Check the log messages carefully to diagnose any issues.

## Contribute

We welcome contributions! If you find a bug or would like to propose a new feature, please feel free to open an issue or submit a pull request. 

- **Report Bugs:** If you find any issues or bugs, please report them by opening a new issue on the GitHub repository.
- **Feature Requests:** If you have an idea for a new feature, feel free to open an issue describing the feature and why it would be useful.
- **Pull Requests:** Contributions via pull requests are highly appreciated.

## License

This script is released under the MIT License.
