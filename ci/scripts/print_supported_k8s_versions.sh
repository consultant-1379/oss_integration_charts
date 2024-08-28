#!/bin/bash
set -o nounset
set -o errexit
MIN_SUPPORTED_K8S_VERSION=$(grep kubeVersion "${1}/charts/eric-oss/kubeVersion.yaml" | awk '{print $2}')
MAX_SUPPORTED_K8S_VERSION=$(grep kubeVersion "${1}/charts/eric-oss/kubeVersion.yaml" | awk '{print $4}')
K8S_VERSION_GITHUB_TAGS=$(git ls-remote --tags https://github.com/kubernetes/kubernetes | grep -E -v 'beta|\^|alpha|-rc' | awk '{print $2}' | sed 's|refs/tags/v||g' | sort -V)
SUPPORTED_K8S_VERSIONS=$(echo "${K8S_VERSION_GITHUB_TAGS}" | grep -A 1000 "^${MIN_SUPPORTED_K8S_VERSION}$" | grep -B 1000 "^${MAX_SUPPORTED_K8S_VERSION}$")
echo "$SUPPORTED_K8S_VERSIONS"
