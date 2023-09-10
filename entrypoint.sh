#!/bin/bash

# Function to print error and exit
function error_exit {
  echo -e "${RED}[ERROR] $1 ${NC}"
  exit 1
}

# Function to print warnings
function warning {
  echo -e "${YELLOW}[WARNING] $1 ${NC}"
}

# Colors for logs
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if all required variables are set
for var in "FUNC_NAME" "REGION" "PROJECT_ID" "DEPENDENCIES" "ACCESS_KEY" "SECRET_KEY" "HANDLER" "MEMORY_SIZE" "RUNTIME" "TIMEOUT"; do
  if [ -z "${!var}" ]; then
    error_exit "Required variable $var is not set"
  fi
done

echo -e "${YELLOW}[INFO] ${BLUE}Starting...${NC}"

# Check for metadata folder
if [ ! -d "/root/.hcloud/metaOrigin" ]; then
  echo -e "${YELLOW}[INFO] ${BLUE}Metadata folder not found. Downloading metadata...${NC}"
  expect <<EOD >/dev/null 2>&1
  spawn hcloud meta download
  expect -re ".*:"
  send "y\r"
  expect eof
EOD
  [ $? -eq 0 ] || error_exit "Failed to download metadata."
  echo -e "${YELLOW}[INFO] ${BLUE}Metadata successfully downloaded${NC}"
else
  echo -e "${YELLOW}[INFO] ${BLUE}Metadata folder already exists${NC}"
fi

# Configure hcloud environment
hcloud configure set --cli-profile=default \
  --cli-access-key=${ACCESS_KEY} \
  --cli-secret-key=${SECRET_KEY} \
  --cli-project-id=${PROJECT_ID} \
  --cli-region=${REGION} \
  --cli-mode=AKSK || error_exit "Failed to configure hcloud."

# Display function name
echo -e "${YELLOW}[INFO] ${BLUE}Function name: ${NC}$FUNC_NAME"

# Display other required parameters
echo -e "${YELLOW}[INFO] ${BLUE}Required parameters: ${NC}$REGION, $PROJECT_ID, $DEPENDENCIES"

# Convert DEPENDENCIES to array and fetch their IDs
IFS=',' read -ra DEP_ARRAY <<< "$DEPENDENCIES"
command_output=$(hcloud FunctionGraph ListDependencies --ispublic=false)
counter=1
ids=""
depend_list_str=""
echo -e "${YELLOW}[INFO] ${BLUE}Fetching dependency IDs...${NC}"

if command -v jq &> /dev/null; then
  echo $user_data_json | jq empty || error_exit "Invalid JSON in user_data_json."
fi

for dep in "${DEP_ARRAY[@]}"; do
  id=$(echo "$command_output" | jq -r --arg DEP "$dep" '.dependencies[] | select(.name == $DEP) | .id')
  if [ ! -z "$id" ]; then
    ids="${ids}${id},"
    depend_list_str="${depend_list_str}--depend_list.${counter}=${id} "
    ((counter++))
  fi
done
ids=${ids%,}
echo -e "${YELLOW}[INFO] ${BLUE}Dependency IDs: ${NC}$ids"

# Compress the function folder
echo -e "${YELLOW}[INFO] ${BLUE}Compressing function folder...${NC}"
# Check if zip command is available
if ! command -v zip &> /dev/null; then
  error_exit "zip command not found. Please install zip to continue."
fi

# Compress the function folder
cd /app/function || error_exit "Failed to change directory to /app/function."
rm -rf function.zip
zip -r function.zip . -x *pycache* || error_exit "Failed to compress function folder."

echo -e "${YELLOW}[INFO] ${BLUE}Function folder compressed${NC}"

# Upload the compressed function
echo -e "${YELLOW}[INFO] ${BLUE}Uploading function...${NC}"

# Configure OBS and upload the compressed function
obsutil config -i=${ACCESS_KEY} -k=${SECRET_KEY} -e=obs.${REGION}.myhuaweicloud.com
RANDOM_NUM=$(shuf -i 10000-99999 -n 1)
TEMP_BUCKET="codearts-tmp-$RANDOM_NUM"

echo -e "${YELLOW}[INFO] ${BLUE}Creating temporary bucket ${NC}${TEMP_BUCKET}${NC}"
obsutil mb obs://${TEMP_BUCKET} -location=${REGION} -sc=standard

echo -e "${YELLOW}[INFO] ${BLUE}Uploading function to temporary bucket${NC}"
obsutil cp /app/function/function.zip obs://${TEMP_BUCKET}/function.zip

# Update the function code
FUNCTION_URN="urn:fss:$REGION:$PROJECT_ID:function:default:$FUNC_NAME:latest"
echo -e "${YELLOW}[INFO] ${BLUE}Updating function code${NC}"
hcloud FunctionGraph UpdateFunctionCode \
        --cli-region=${REGION} \
        --code_type="obs" \
        --function_urn=${FUNCTION_URN} \
        --project_id=${PROJECT_ID} \
        --code_url="https://${TEMP_BUCKET}.obs.${REGION}.myhuaweicloud.com/function.zip" \
        ${depend_list_str}  # Using depend_list_str here

echo -e "${YELLOW}[INFO] ${BLUE}Function code updated${NC}"

# Cleanup
echo -e "${YELLOW}[INFO] ${BLUE}Cleaning up temporary bucket${NC}"
obsutil rm obs://${TEMP_BUCKET} -r -f
obsutil rm obs://${TEMP_BUCKET} -f


# Collect all environment variables that start with "FUNCTIONGRAPH_" and construct the JSON string for --encrypted_user_data
declare -A encrypted_user_data
for var in $(compgen -e); do
    if [[ $var == FUNCTIONGRAPH_* ]]; then
        encrypted_user_data["$var"]="${!var}"
    fi
done

# Initialize an empty associative array to store the user data as key-value pairs
declare -A user_data_json_array

# Populate user_data_json_array with key-value pairs
for key in "${!encrypted_user_data[@]}"; do
    value="${encrypted_user_data[$key]}"
    # Remove trailing quotes if any
    value="${value%\"}"
    # Remove leading quotes if any
    value="${value#\"}"

    if [ -n "$value" ]; then
        clean_key="${key#FUNCTIONGRAPH_}"  # Remove the prefix "FUNCTIONGRAPH_"
        user_data_json_array["$clean_key"]=$value
    else
        echo -e "${RED}[ERROR] ${NC}Value for $key is empty."
    fi
done

# Convert the associative array to a JSON string
user_data_json="{"
first=true
for key in "${!user_data_json_array[@]}"; do
    [ "$first" = true ] && first=false || user_data_json+=","
    user_data_json+="\"$key\":\"${user_data_json_array[$key]}\""
done
user_data_json+="}"

# Then use $user_data_json in the hcloud FunctionGraph UpdateFunctionConfig command
hcloud FunctionGraph UpdateFunctionConfig \
    --cli-region=${REGION} \
    --func_name=${FUNC_NAME} \
    --function_urn=${FUNCTION_URN} \
    --handler=${HANDLER} \
    --memory_size=${MEMORY_SIZE} \
    --project_id=${PROJECT_ID} \
    --runtime=${RUNTIME} \
    --timeout=${TIMEOUT} \
    --app_xrole=${AGENCY_NAME} \
    --encrypted_user_data="$user_data_json" || error_exit "Failed to update function configuration."

echo -e "${YELLOW}[INFO] ${BLUE}Function configuration updated${NC}"

# Completion
echo -e "${GREEN}[INFO] Finished${NC}"
