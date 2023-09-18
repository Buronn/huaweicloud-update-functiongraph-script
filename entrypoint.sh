#!/bin/bash
# @Author: Fernando Burón (Buronn)


# Function to print error and exit
function error_exit {
  echo -e "${RED}[ERROR] $1 ${NC}"
  exit 1
}

# Function to print warnings
function warning {
  echo -e "${ORANGE}[WARNING] $1 ${NC}"
}

function debug {
  if [ "$DEBUG" = true ]; then
    echo -e "${PURPLE}[DEBUG] ${NC}$1"
  fi
}

function info_msg {
  echo -e "${YELLOW}[INFO] ${NC}$1"
}

# Colors for logs
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
ORANGE='\033[0;33m'
NC='\033[0m' # No Color

jq_installed=0
if command -v jq &> /dev/null; then
  jq_installed=1
fi

# Check if all required variables are set
for var in "FUNC_NAME" "REGION" "PROJECT" "ACCESS_KEY" "SECRET_KEY" "HANDLER" "MEMORY_SIZE" "RUNTIME" "TIMEOUT"; do
  if [ -z "${!var}" ]; then
    error_exit "Required variable $var is not set"
  fi
done

# Start of the script

PROJECT_ID=$PROJECT
echo -e "${GREEN}[INFO] Starting${NC}"

# Check for metadata folder
if [ ! -d "/root/.hcloud/metaOrigin" ]; then
  info_msg "${BLUE}Metadata folder not found. Downloading metadata...${NC}"
  expect <<EOD >/dev/null 2>&1
  spawn hcloud meta download
  expect -re ".*:"
  send "y\r"
  expect eof
EOD
  [ $? -eq 0 ] || error_exit "Failed to download metadata."
  info_msg "${BLUE}Metadata successfully downloaded${NC}"
else
  info_msg "${BLUE}Metadata folder already exists${NC}"
fi

# Execute the hcloud configure set command and store its output
command_output=$(hcloud configure set --cli-profile=default \
  --cli-access-key=${ACCESS_KEY} \
  --cli-secret-key=${SECRET_KEY} \
  --cli-project-id=${PROJECT_ID} \
  --cli-region=${REGION} \
  --cli-mode=AKSK 2>&1)

debug "KooCLI Configure Command:\n$command_output"

# Check if the command failed
if [[ $? -ne 0 ]]; then
  if [[ $jq_installed -eq 1 ]]; then
    error_code=$(echo "$command_output" | jq -r '.error_code // empty')
    error_msg=$(echo "$command_output" | jq -r '.error_msg // empty')
    
    if [[ ! -z "$error_code" && ! -z "$error_msg" ]]; then
      error_exit "Failed to configure hcloud.\nError Code: $error_code\nError Message: $error_msg"
    else
      error_exit "Failed to configure hcloud.\nFull output: $command_output"
    fi
  else
    error_exit "Failed to configure hcloud.\njq is not installed.\nFull output: $command_output"
  fi
else
  info_msg "${BLUE}hcloud configured successfully."
fi

# Display function name
info_msg "${BLUE}Function name to update: ${NC}$FUNC_NAME"

# Display other required parameters
debug "${BLUE}Required parameters: ${NC}$REGION, $PROJECT_ID, $DEPENDENCIES"

# Convert DEPENDENCIES to array and fetch their IDs
IFS=',' read -ra DEP_ARRAY <<< "$DEPENDENCIES"
command_output=$(hcloud FunctionGraph ListDependencies --ispublic=false)
debug "KooCLI ListDependencies: \n$command_output"
echo -e 
counter=1
ids=""
depend_version_list=""  # Agregar esta línea para inicializar la variable
info_msg "${BLUE}Fetching dependency IDs...${NC}"

if command -v jq &> /dev/null; then
  echo $user_data_json | jq empty || error_exit "Invalid JSON in user_data_json."
fi

for dep in "${DEP_ARRAY[@]}"; do
  id=$(echo "$command_output" | jq -r --arg DEP "$dep" --arg RUNTIME "$RUNTIME" '.dependencies[] | select(.name == $DEP and .runtime == $RUNTIME) | .id')
  get_version_id_output=$(hcloud FunctionGraph ListDependencyVersion --depend_id=${id} 2>&1)
  version=$(echo "$get_version_id_output" | jq -r '.dependencies[0] | .id')
  if [ ! -z "$id" ]; then
    depend_version_list="${depend_version_list}--depend_version_list.${counter}=${version} "
    ((counter++))
  fi
done
debug "Final depend_version_list value: $depend_version_list"

# Compress the function folder
info_msg "${BLUE}Compressing function folder...${NC}"
# Check if zip command is available
if ! command -v zip &> /dev/null; then
  error_exit "zip command not found. Please install zip to continue."
fi

# Compress the function folder
cd ${FUNCTION_FOLDER} || error_exit "Failed to change directory to function."
rm -rf function.zip
command_output=$(zip -r function.zip . -x *pycache*) || error_exit "Failed to compress function folder."
debug "Compressing output: $command_output"
base64_zip=$(base64 -w 0 function.zip) || error_exit "Failed to create base64 encoded ZIP."

info_msg "${BLUE}Function folder compressed${NC}"

# Upload the compressed function
info_msg "${BLUE}Uploading function...${NC}"


# Update the function code
info_msg "${BLUE}Updating function code${NC}"
FUNCTION_URN="urn:fss:$REGION:$PROJECT_ID:function:default:$FUNC_NAME:latest"

command_output=$(hcloud FunctionGraph UpdateFunctionCode \
        --cli-region=${REGION} \
        --code_type="zip" \
        --function_urn=${FUNCTION_URN} \
        --project_id=${PROJECT_ID} \
        --func_code.file="$base64_zip" \
        --code_filename="function.zip" \
        ${depend_version_list} 2>&1)

debug "KooCLI UpdateFunctionCode Command:\n$command_output"
# Check if the command was successful
if [[ $? -ne 0 ]]; then
  error_exit "Failed to update function code.\nFull output: $command_output"
else
  # Check if jq is installed to parse the error message
  if command -v jq &> /dev/null; then
    error_code=$(echo "$command_output" | jq -r '.error_code // empty' 2>/dev/null)
    
    if [[ ! -z "$error_code" ]]; then
      error_msg=$(echo "$command_output" | jq -r '.error_msg // empty' 2>/dev/null)
      error_exit "Failed to update function code.\n\tError Code: $error_code\n\tError Message: $error_msg"
    else
      info_msg "${BLUE}Function code updated."
    fi
  else
    info_msg "Function code updated (jq is not installed for additional error checking)."
  fi
fi



# Collect all environment variables that start with "FUNCTIONGRAPH_" and construct the JSON string for --user_data
declare -A user_data
for var in $(compgen -e); do
    if [[ $var == FUNCTIONGRAPH_* ]]; then
        user_data["$var"]="${!var}"
    fi
done

# Initialize an empty associative array to store the user data as key-value pairs
declare -A user_data_json_array

# Populate user_data_json_array with key-value pairs
for key in "${!user_data[@]}"; do
    value="${user_data[$key]}"
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

# Execute the command and store its output
command_output=$(hcloud FunctionGraph UpdateFunctionConfig \
   --func_name=${FUNC_NAME} \
   --function_urn=${FUNCTION_URN} \
   --handler=${HANDLER} \
   --memory_size=${MEMORY_SIZE} \
   --project_id=${PROJECT_ID} \
   --runtime=${RUNTIME} \
   --timeout=${TIMEOUT} \
   --app_xrole=${AGENCY_NAME} \
   --user_data="$user_data_json" 2>&1)

debug "KooCLI UpdateFunctionConfig Command:\n$command_output"
# Check if the command failed
if [[ $? -ne 0 ]]; then
  error_exit "Failed to update function configuration.\nFull output: $command_output"
else
  # Check if jq is installed to parse the error message
  if command -v jq &> /dev/null; then
    error_code=$(echo "$command_output" | jq -r '.error_code // empty' 2>/dev/null)
    
    if [[ ! -z "$error_code" ]]; then
      error_msg=$(echo "$command_output" | jq -r '.error_msg // empty' 2>/dev/null)
      error_exit "Failed to update function configuration.\nError Code: $error_code\nError Message: $error_msg"
    else
      info_msg "${BLUE}Function configuration updated${NC}"
    fi
  else
    info_msg "Function configuration updated (jq is not installed for additional error checking)."
  fi
fi

rm -rf function.zip

# Completion
echo -e "${GREEN}[INFO] Finished${NC}"
