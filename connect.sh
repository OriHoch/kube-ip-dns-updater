#!/usr/bin/env bash

CONTEXT_NAME="${1}"
NAMESPACE_NAME="${2}"

if ( [ "${CONTEXT_NAME}" == "" ] || [ "${NAMESPACE_NAME}" == "" ] ); then
    echo Usage: source connect.sh '<CONTEXT_NAME> <NAMESPACE_NAME>'
else
    kubectl config use-context "${CONTEXT_NAME}"
    kubectl config set-context "${CONTEXT_NAME}" --namespace="${NAMESPACE_NAME}"
    kubectl create ns "${NAMESPACE_NAME}" >/dev/null 2>&1
    source <(kubectl completion bash)
    echo Connected to context "${CONTEXT_NAME}" default namespace "${NAMESPACE_NAME}"
fi
