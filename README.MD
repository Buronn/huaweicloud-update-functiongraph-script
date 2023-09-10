# Huawei Cloud update FunctionGraph script

## Description

This Bash script is designed to automate the deployment of a function to the Huawei Cloud FunctionGraph service. The script does the following:

1. Checks if all required environment variables are set.
2. Downloads metadata if not found.
3. Configures the `hcloud` environment.
4. Fetches dependency IDs.
5. Compresses the function folder into a zip file.
6. Uploads the zip file to a temporary OBS bucket.
7. Updates the function code and configuration.

## Requirements

1. `hcloud` CLI installed.
2. `jq` for JSON manipulation.
3. `obsutil` for Huawei OBS operations.
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
- `AGENCY_NAME`: The name of the agency role with permissions.
- `FUNCTIONGRAPH_*`: Environment variables starting with "FUNCTIONGRAPH_" will be used as function configuration parameters.

## How to Use

1. **Clone this repository:**

   ```bash
   git clone https://github.com/Buronn/huaweicloud-update-functiongraph-script
   ```

2. **Navigate to the repository:**

   ```bash
   cd path/to/repo
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

   Make sure the script is executable:

   ```bash
   chmod +x path/to/script.sh
   ```

   Then run it:

   ```bash
   ./path/to/script.sh
   ```

## Troubleshooting

- Make sure you have all required CLI tools installed (`hcloud`, `jq`, `obsutil`, `expect`, `zip`).
- Ensure all environment variables are set before running the script.
- Check the log messages carefully to diagnose any issues.

## License

This script is released under the MIT License.
