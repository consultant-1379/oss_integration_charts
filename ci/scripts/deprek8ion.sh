#!/bin/sh
set -o nounset
set -o errexit
SUPPORTED_VERSIONS_FILE_PATH=$1
FULL_TEMPLATE_PATH=$2

echo "Running deprek8ion against the supported minor kubernetes versions"
MINOR_K8S_VERSIONS=$(awk -F. '{print $1 "." $2}' "${SUPPORTED_VERSIONS_FILE_PATH}" | sort -u)
echo "$MINOR_K8S_VERSIONS" | while read -r supported_version
do
    echo "Running deprek8ion against kubernetes version $supported_version"
    POLICY_FILE=/policies/kubernetes-${supported_version}.rego
    if [ -f "$POLICY_FILE" ]
    then
        set +o errexit
        CHECK_OUTPUT=$(/conftest test -p /policies "$FULL_TEMPLATE_PATH" --policy "/policies/kubernetes-${supported_version}.rego")
        EXIT_CODE=$?
        set -o errexit
        echo "$CHECK_OUTPUT"
        if [ $EXIT_CODE -ne 0 ]
        then
            if (echo "$CHECK_OUTPUT" | grep -q " 1 failure") && (echo "$CHECK_OUTPUT" | grep -q "ingress.class has been deprecated in 1.18")
            then
                echo "WARNING: Skipping 'ingress.class has been deprecated in 1.18' failure"
            else
                echo "kubeval failed against kubernetes version $supported_version"
                exit 1
            fi
        fi
    elif [ "$supported_version" = "1.15" ]
    then
        echo "Skipping because deprek8ion is known to not support version 1.15"
    else
        echo "ERROR: No deprek8ion policy for kubernetes version $supported_version. Check if a newer version of deprek8ion supports this version"
        exit 1
    fi
done
