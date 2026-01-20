FROM ubuntu:22.04

# --- 1. CÀI ĐẶT MÔI TRƯỜNG & SSH & DOCKER ---
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    curl wget sudo nano unzip \
    openssh-server \
    net-tools iputils-ping \
    ca-certificates \
    docker.io \
    iptables \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir /var/run/sshd

# --- 2. CẤU HÌNH SSH ---
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# --- 3. TẠO USER & GROUP DOCKER ---
# Thêm user 'trthaodev' vào nhóm 'docker' để chạy lệnh không cần sudo
RUN useradd -m -s /bin/bash trthaodev && \
    echo "trthaodev:thaodev@" | chpasswd && \
    usermod -aG sudo trthaodev && \
    usermod -aG docker trthaodev && \
    echo "trthaodev ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    echo "root:123456" | chpasswd

# --- 4. CÀI ĐẶT CLOUDFLARED ---
RUN wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb && \
    dpkg -i cloudflared-linux-amd64.deb && \
    rm cloudflared-linux-amd64.deb

# --- 5. CÀI ĐẶT FILEBROWSER ---
RUN curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash

# --- 6. SCRIPT KHỞI ĐỘNG (Đã thêm fix quyền Docker) ---
RUN echo '#!/bin/bash' > /start.sh && \
    echo 'echo "=== KHOI DONG HE THONG ==="' >> /start.sh && \
    echo '' >> /start.sh && \
    # --- PHẦN MỚI: FIX QUYỀN DOCKER SOCK ---
    echo 'if [ -S /var/run/docker.sock ]; then' >> /start.sh && \
    echo '  echo "🔧 Phat hien Docker Socket, dang cap quyen..."' >> /start.sh && \
    echo '  chmod 666 /var/run/docker.sock' >> /start.sh && \
    echo 'fi' >> /start.sh && \
    # --------------------------------------
    echo 'if [ -z "$CF_TOKEN" ]; then' >> /start.sh && \
    echo '  echo "❌ LOI: Thieu CF_TOKEN!"' >> /start.sh && \
    echo '  exit 1' >> /start.sh && \
    echo 'fi' >> /start.sh && \
    echo 'echo "1. Dang bat SSH Server..."' >> /start.sh && \
    echo 'service ssh start' >> /start.sh && \
    echo '' >> /start.sh && \
    echo 'echo "2. Dang bat FileBrowser..."' >> /start.sh && \
    echo 'nohup filebrowser -r / -p 8080 --no-auth > /var/log/fb.log 2>&1 &' >> /start.sh && \
    echo '' >> /start.sh && \
    echo 'echo "3. Dang ket noi Cloudflare Tunnel..."' >> /start.sh && \
    echo 'cloudflared tunnel run --token $CF_TOKEN' >> /start.sh && \
    chmod +x /start.sh

# --- 7. START ---
EXPOSE 8080 22
CMD ["/start.sh"]
