# syntax=docker/dockerfile:1
# checkov:skip=CKV_DOCKER_2:CI build image, not a long-running service
# checkov:skip=CKV_DOCKER_3:CodeBuild runs builds as root, and dockerd (privileged projects) requires root

# smartbid-ci/tools — the image every CodeBuild project (except ci-image-build) runs on.
# All tools are version-pinned below; bump a version, merge, and smartbid-ci-image-build rebuilds it.
# Base images come through the ECR pull-through cache (BASE_REGISTRY is passed by the buildspec).

ARG BASE_REGISTRY=public.ecr.aws/docker/library
FROM ${BASE_REGISTRY}/eclipse-temurin:21-jdk-noble

ARG TERRAFORM_VERSION=1.16.5
ARG TFLINT_VERSION=0.64.0
ARG NODE_VERSION=22.23.3
ARG MAVEN_VERSION=3.9.16
ARG TRIVY_VERSION=0.75.0
ARG SYFT_VERSION=1.54.0
ARG COSIGN_VERSION=2.6.5
ARG GITLEAKS_VERSION=8.30.1
ARG HADOLINT_VERSION=2.15.1
ARG CHECKOV_VERSION=3.3.22
ARG SEMGREP_VERSION=1.179.0

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENV DEBIAN_FRONTEND=noninteractive

# OS packages + Docker engine. Privileged CodeBuild projects start dockerd themselves
# (custom images don't get the Docker daemon that AWS curated images provide).
# hadolint ignore=DL3008
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl git gnupg jq unzip xz-utils python3 python3-venv \
 && install -m 0755 -d /etc/apt/keyrings \
 && curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc \
 && echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu noble stable" > /etc/apt/sources.list.d/docker.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
 && rm -rf /var/lib/apt/lists/*

# AWS CLI v2
RUN curl -fsSLo /tmp/awscliv2.zip https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip \
 && unzip -q /tmp/awscliv2.zip -d /tmp \
 && /tmp/aws/install \
 && rm -rf /tmp/aws /tmp/awscliv2.zip

# Terraform + TFLint
RUN curl -fsSLo /tmp/terraform.zip "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip" \
 && unzip -q -o /tmp/terraform.zip terraform -d /usr/local/bin \
 && curl -fsSLo /tmp/tflint.zip "https://github.com/terraform-linters/tflint/releases/download/v${TFLINT_VERSION}/tflint_linux_amd64.zip" \
 && unzip -q -o /tmp/tflint.zip -d /usr/local/bin \
 && rm /tmp/terraform.zip /tmp/tflint.zip

# Node.js (frontend) and Maven (Java services; the JDK comes from the base image)
RUN curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz" \
    | tar -xJ -C /usr/local --strip-components=1 --exclude='*.md' --exclude=LICENSE \
 && curl -fsSL "https://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz" \
    | tar -xz -C /opt \
 && ln -s "/opt/apache-maven-${MAVEN_VERSION}/bin/mvn" /usr/local/bin/mvn

# Security and supply-chain tools: trivy (vulns/misconfig), syft (SBOM), cosign (signing),
# gitleaks (secrets), hadolint (Dockerfiles). Trivy's report templates go to /usr/local/share/trivy/templates.
RUN curl -fsSL "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz" \
    | tar -xz -C /tmp trivy contrib \
 && mv /tmp/trivy /usr/local/bin/trivy \
 && mkdir -p /usr/local/share/trivy \
 && mv /tmp/contrib /usr/local/share/trivy/templates \
 && curl -fsSL "https://github.com/anchore/syft/releases/download/v${SYFT_VERSION}/syft_${SYFT_VERSION}_linux_amd64.tar.gz" \
    | tar -xz -C /usr/local/bin syft \
 && curl -fsSL "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz" \
    | tar -xz -C /usr/local/bin gitleaks \
 && curl -fsSLo /usr/local/bin/cosign "https://github.com/sigstore/cosign/releases/download/v${COSIGN_VERSION}/cosign-linux-amd64" \
 && curl -fsSLo /usr/local/bin/hadolint "https://github.com/hadolint/hadolint/releases/download/v${HADOLINT_VERSION}/hadolint-Linux-x86_64" \
 && chmod +x /usr/local/bin/cosign /usr/local/bin/hadolint

# Python tools in separate virtualenvs (their dependency pins conflict)
RUN python3 -m venv /opt/checkov \
 && /opt/checkov/bin/pip install --no-cache-dir "checkov==${CHECKOV_VERSION}" \
 && ln -s /opt/checkov/bin/checkov /usr/local/bin/checkov \
 && python3 -m venv /opt/semgrep \
 && /opt/semgrep/bin/pip install --no-cache-dir "semgrep==${SEMGREP_VERSION}" \
 && ln -s /opt/semgrep/bin/semgrep /usr/local/bin/semgrep

# Fail the image build if any tool is missing or broken
RUN set -e; java -version; mvn -v; node -v; npm -v; terraform version; tflint --version; aws --version; \
    docker --version; docker buildx version; docker compose version; trivy --version; syft version; \
    cosign version; gitleaks version; hadolint --version; checkov --version; semgrep --version
