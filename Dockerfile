FROM ubuntu:22.04

# --- 1. CÀI ĐẶT MÔI TRƯỜNG & JAVA 21 ---
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    curl wget sudo nano unzip \
    openssh-server \
    net-tools iputils-ping \
    ca-certificates \
    # Minecraft 1.21.1 bắt buộc dùng Java 21
    openjdk-21-jre-headless \ 
    docker.io \
    iptables \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir /var/run/sshd

# --- 2. CẤU HÌNH SSH & USER ---
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    echo "root:123456" | chpasswd && \
    useradd -m -s /bin/bash trthaodev && \
    echo "trthaodev:thaodev@" | chpasswd && \
    usermod -aG sudo trthaodev && \
    echo "trthaodev ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# --- 3. CÀI ĐẶT CLOUDFLARED ---
RUN wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb && \
    dpkg -i cloudflared-linux-amd64.deb && \
    rm cloudflared-linux-amd64.deb

# --- 4. TẠO ENTRYPOINT TRỰC TIẾP TRONG DOCKERFILE ---
# Cách này giúp bạn không cần file start.sh bên ngoài, tránh lỗi Railpack không tìm thấy file
RUN printf '#!/bin/bash\n\
echo "=== DANG KHOI DONG HE THONG ==="\n\
if [ -S /var/run/docker.sock ]; then chmod 666 /var/run/docker.sock; fi\n\
service ssh start\n\
if [ ! -z "$CF_TOKEN" ]; then\n\
  echo "✅ Dang ket noi Cloudflare Tunnel..."\n\
  cloudflared tunnel run --token $CF_TOKEN\n\
else\n\
  echo "⚠️ Thieu CF_TOKEN! Container se chay o che do cho..."\n\
  tail -f /dev/null\n\
fi' > /entrypoint.sh && chmod +x /entrypoint.sh

# --- 5. KHAI BÁO CỔNG ---
EXPOSE 22 25565

# --- 6. CHẠY ---
ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]
