#!/bin/sh
#
# Script to invoke Infrastructure Manager via gcloud CLI

set -ex

plan()
{
    [ -z "${DEPLOYMENT_ID}" ] && echo "ERROR: DEPLOYMENT_ID environment variable must be set" && exit 1
    [ -z "${DEPLOYMENT_PROJECT_ID}" ] && echo "ERROR: DEPLOYMENT_PROJECT_ID environment variable must be set" && exit 1
    [ -z "${DEPLOYMENT_REGION}" ] && echo "ERROR: DEPLOYMENT_REGION environment variable must be set" && exit 1
    [ -z "${IAC_SERVICE_ACCOUNT_NAME}" ] && echo "ERROR: IAC_SERVICE_ACCOUNT_NAME environment variable must be set" && exit 1
    [ -z "${GITHUB_URL}" ] && echo "ERROR: GITHUB_URL environment variable must be set" && exit 1
    [ -z "${GITHUB_SHA}" ] && echo "ERROR: GITHUB_SHA environment variable must be set" && exit 1
    [ -z "${GITHUB_REF}" ] && echo "ERROR: GITHUB_REF environment variable must be set" && exit 1
    [ -z "${SOURCE_DIRECTORY}" ] && echo "ERROR: SOURCE_DIRECTORY environment variable must be set" && exit 1

    # Delete existing preview, if it exists
    PREVIEW_NAME="projects/${DEPLOYMENT_PROJECT_ID}/locations/${DEPLOYMENT_REGION}/previews/${GITHUB_SHA}"
    gcloud infra-manager previews delete --quiet "${PREVIEW_NAME}" 2>/dev/null || true

    # See if there is an existing deployment to attach to the preview
    DEPLOYMENT_NAME="projects/${DEPLOYMENT_PROJECT_ID}/locations/${DEPLOYMENT_REGION}/deployments/${DEPLOYMENT_ID}"
    HAS_EXISTING_DEPLOYMENT="$(gcloud infra-manager deployments describe "${DEPLOYMENT_NAME}" --format "value(name)" 2>/dev/null || true)"

    # Create a new preview for the commit
    gcloud infra-manager previews create "${PREVIEW_NAME}" \
        --service-account="${IAC_SERVICE_ACCOUNT_NAME}" \
        --git-source-repo="${GITHUB_URL}" \
        --git-source-ref="${GITHUB_REF}" \
        --git-source-directory="${SOURCE_DIRECTORY}" \
        --inputs-file="${GITHUB_SHA}.tfvars" \
        ${HAS_EXISTING_DEPLOYMENT:+--deployment="${DEPLOYMENT_NAME}"}

    # Export the tfplan from preview
    gcloud infra-manager previews export "${PREVIEW_NAME}" --file="${GITHUB_SHA}"

    # Transform tfplan to readable text
    terraform -chdir="${SOURCE_DIRECTORY}" init
    terraform -chdir="${SOURCE_DIRECTORY}" show -no-color "$(readlink -f "${GITHUB_SHA}.tfplan")" > "${GITHUB_SHA}.txt"
}

apply()
{
    [ -z "${DEPLOYMENT_ID}" ] && echo "ERROR: DEPLOYMENT_ID environment variable must be set" && exit 1
    [ -z "${DEPLOYMENT_PROJECT_ID}" ] && echo "ERROR: DEPLOYMENT_PROJECT_ID environment variable must be set" && exit 1
    [ -z "${DEPLOYMENT_REGION}" ] && echo "ERROR: DEPLOYMENT_REGION environment variable must be set" && exit 1
    [ -z "${IAC_SERVICE_ACCOUNT_NAME}" ] && echo "ERROR: IAC_SERVICE_ACCOUNT_NAME environment variable must be set" && exit 1
    [ -z "${GITHUB_URL}" ] && echo "ERROR: GITHUB_URL environment variable must be set" && exit 1
    [ -z "${GITHUB_SHA}" ] && echo "ERROR: GITHUB_SHA environment variable must be set" && exit 1
    [ -z "${GITHUB_REF}" ] && echo "ERROR: GITHUB_REF environment variable must be set" && exit 1
    [ -z "${SOURCE_DIRECTORY}" ] && echo "ERROR: SOURCE_DIRECTORY environment variable must be set" && exit 1
    [ -z "${TF_VERSION}" ] && echo "ERROR: TF_VERSION environment variable must be set" && exit 1

    DEPLOYMENT_NAME="projects/${DEPLOYMENT_PROJECT_ID}/locations/${DEPLOYMENT_REGION}/deployments/${DEPLOYMENT_ID}"
    gcloud infra-manager deployments apply "${DEPLOYMENT_NAME}" \
        --service-account="${IAC_SERVICE_ACCOUNT_NAME}" \
        --git-source-repo="${GITHUB_URL}" \
        --git-source-ref="${GITHUB_REF}" \
        --git-source-directory="${SOURCE_DIRECTORY}" \
        --tf-version-constraint="${TF_VERSION}" \
        --inputs-file="${GITHUB_SHA}.tfvars"
}

delete()
{
    [ -z "${DEPLOYMENT_ID}" ] && echo "ERROR: DEPLOYMENT_ID environment variable must be set" && exit 1
    [ -z "${DEPLOYMENT_PROJECT_ID}" ] && echo "ERROR: DEPLOYMENT_PROJECT_ID environment variable must be set" && exit 1
    [ -z "${DEPLOYMENT_REGION}" ] && echo "ERROR: DEPLOYMENT_REGION environment variable must be set" && exit 1
    gcloud infra-manager deployments delete "projects/${DEPLOYMENT_PROJECT_ID}/locations/${DEPLOYMENT_REGION}/deployments/${DEPLOYMENT_ID}"
}

case "$1" in
    apply)
        apply
        ;;
    delete)
        delete
        ;;
    *)
        plan
        ;;
esac
