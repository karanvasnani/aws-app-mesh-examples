#!/bin/bash

set -ex

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

aws --region "${AWS_DEFAULT_REGION}" \
    cloudformation deploy \
    --stack-name "${ENVIRONMENT_NAME}-ecr-repositories" \
    --capabilities CAPABILITY_IAM \
    --template-file "${DIR}/ecr-repositories.yaml" \
    --parameter-overrides \
    ColorTellerImageName="${COLOR_TELLER_IMAGE_NAME}" \
    SideCarRouterManagerImageName="${SIDECAR_ROUTER_MANAGER_IMAGE_NAME}" \
    ExternalProxyImageName="${EXTERNAL_PROXY_IMAGE_NAME}"
