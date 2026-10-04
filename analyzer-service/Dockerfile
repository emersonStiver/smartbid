# syntax=docker/dockerfile:1

ARG JAVA_VERSION=21
# Docker Hub official images mirrored on ECR Public (no Docker Hub rate limits).
# Later in CodeBuild: --build-arg BASE_REGISTRY=<account>.dkr.ecr.<region>.amazonaws.com/docker-hub/library
ARG BASE_REGISTRY=public.ecr.aws/docker/library

# ---- 1. Dependencies: downloaded INTO this layer, so the layer cache (local or ECR) keeps them.
#         Rebuilt only when pom.xml changes. No cache mounts: files in a mount never reach the layer.
FROM ${BASE_REGISTRY}/maven:3.9.9-eclipse-temurin-${JAVA_VERSION} AS deps
WORKDIR /build
COPY pom.xml .
RUN mvn -B -q dependency:go-offline

# ---- 2. Build the jar. Inherits /root/.m2 from the deps layer, so nothing is downloaded again.
#         Tests run in the pipeline's build-test stage, not here.
FROM deps AS builder
COPY src ./src
RUN mvn -B -q package -DskipTests && cp target/*.jar application.jar

# ---- 3. Split the jar into layers: dependencies change rarely, application code changes often
FROM ${BASE_REGISTRY}/eclipse-temurin:${JAVA_VERSION}-jre AS extract
WORKDIR /extract
COPY --from=builder /build/application.jar .
RUN java -Djarmode=tools -jar application.jar extract --layers --destination layers

# ---- 4. Runtime image: starts clean, so the jar and build tools from earlier stages are left behind
FROM ${BASE_REGISTRY}/eclipse-temurin:${JAVA_VERSION}-jre AS runtime

# Passed in by the pipeline (buildspecs/package-publish.yml)
ARG APP_NAME=analyzer-service
ARG APP_VERSION=0.0.0-local
ARG GIT_SHA=unknown
ARG SOURCE_URL=""
LABEL org.opencontainers.image.title="${APP_NAME}" \
      org.opencontainers.image.version="${APP_VERSION}" \
      org.opencontainers.image.revision="${GIT_SHA}" \
      org.opencontainers.image.source="${SOURCE_URL}" \
      org.opencontainers.image.description="SmartBid analyzer service (Spring Boot)"

RUN apt-get update \
 && apt-get install -y --no-install-recommends curl \
 && rm -rf /var/lib/apt/lists/* \
 && groupadd --system --gid 10001 spring \
 && useradd --system --uid 10001 --gid spring --no-create-home spring

# Logs go to stdout; Docker on EC2 ships them to CloudWatch (awslogs log driver)
ENV JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=75.0 -XX:+ExitOnOutOfMemoryError" \
    SERVER_PORT=8080 \
    MANAGEMENT_SERVER_PORT=8081

WORKDIR /app
COPY --from=extract --chown=spring:spring /extract/layers/dependencies/ ./
COPY --from=extract --chown=spring:spring /extract/layers/spring-boot-loader/ ./
COPY --from=extract --chown=spring:spring /extract/layers/snapshot-dependencies/ ./
COPY --from=extract --chown=spring:spring /extract/layers/application/ ./

USER 10001:10001
EXPOSE 8080 8081

# curl -f fails on HTTP 503, which actuator returns when the app is DOWN
HEALTHCHECK --start-period=60s --interval=30s --timeout=5s --retries=3 \
  CMD curl -sf http://localhost:8081/actuator/health || exit 1

ENTRYPOINT ["java", "-jar", "application.jar"]