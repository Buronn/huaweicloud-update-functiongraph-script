# First build stage
FROM ubuntu:22.04 AS builder

# Install dependencies
RUN apt-get update && \
    apt-get install -y curl tar ca-certificates wget && \
    update-ca-certificates

# Download and install Huawei Cloud CLI
RUN curl -LO "https://ap-southeast-3-hwcloudcli.obs.ap-southeast-3.myhuaweicloud.com/cli/latest/huaweicloud-cli-linux-amd64.tar.gz" && \
    tar -zxvf huaweicloud-cli-linux-amd64.tar.gz && \
    chmod +x hcloud && \
    mv hcloud /usr/local/bin/

# Download and install obsutil
RUN wget https://obs-community-intl.obs.ap-southeast-1.myhuaweicloud.com/obsutil/current/obsutil_linux_amd64.tar.gz && \
    tar -xzvf obsutil_linux_amd64.tar.gz && \
    obsutil_dir=$(ls -d obsutil_linux_amd64_*/) && \
    chmod 755 ${obsutil_dir}obsutil && \
    mv ${obsutil_dir}obsutil /usr/local/bin/

# Second build stage
FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && \
    apt-get install -y expect zip unzip jq

# Copy binaries and certificates
COPY --from=builder /usr/local/bin/hcloud /usr/local/bin/hcloud
COPY --from=builder /usr/local/bin/obsutil /usr/local/bin/obsutil
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

# Copy local script
COPY ./entrypoint.sh entrypoint.sh

# Make the entrypoint script executable
RUN chmod +x entrypoint.sh

ENTRYPOINT ["./entrypoint.sh"]
