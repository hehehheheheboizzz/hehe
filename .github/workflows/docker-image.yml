FROM ubuntu:22.04

# --- 1. CÀI ĐẶT MÔI TRƯỜNG & SSH SERVER ---
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    curl wget sudo nano unzip \
    openssh-server \
    net-tools iputils-ping \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir /var/run/sshd

# --- 2. CẤU HÌNH SSH (Cho phép đăng nhập mật khẩu) ---
# Mở khóa SSH Root login
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# --- 3. TẠO USER & MẬT KHẨU ---
# User: trthaodev (Sudo không pass)
# Mật khẩu ROOT mặc định: 123456 (Để bạn SSH vào ngay)
RUN useradd -m -s /bin/bash trthaodev && \
    echo "trthaodev:thaodev@" | chpasswd && \
    usermod -aG sudo trthaodev && \
    echo "trthaodev ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    echo "root:123456" | chpasswd

# --- 4. CÀI ĐẶT CLOUDFLARED (Tunnel) ---
RUN wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb && \
    dpkg -i cloudflared-linux-amd64.deb && \
    rm cloudflared-linux-amd64.deb

# --- 5. CÀI ĐẶT FILEBROWSER (Quản lý File) ---
RUN curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash

# --- 6. SCRIPT KHỞI ĐỘNG (Tự động chạy tất cả) ---
RUN echo '#!/bin/bash' > /start.sh && \
    echo 'echo "=== KHOI DONG HE THONG ==="' >> /start.sh && \
    echo '' >> /start.sh && \
    # Kiểm tra Token
    echo 'if [ -z "$CF_TOKEN" ]; then' >> /start.sh && \
    echo '  echo "❌ LOI: Thieu CF_TOKEN!"' >> /start.sh && \
    echo '  exit 1' >> /start.sh && \
    echo 'fi' >> /start.sh && \
    # 1. Bật SSH Server (Port 22)
    echo 'echo "1. Dang bat SSH Server..."' >> /start.sh && \
    echo 'service ssh start' >> /start.sh && \
    echo '' >> /start.sh && \
    # 2. Bật FileBrowser (Port 8080)
    echo 'echo "2. Dang bat FileBrowser..."' >> /start.sh && \
    echo 'nohup filebrowser -r / -p 8080 --no-auth > /var/log/fb.log 2>&1 &' >> /start.sh && \
    echo '' >> /start.sh && \
    # 3. Kết nối Cloudflare
    echo 'echo "3. Dang ket noi Cloudflare Tunnel..."' >> /start.sh && \
    echo 'cloudflared tunnel run --token $CF_TOKEN' >> /start.sh && \
    chmod +x /start.sh

# --- 7. MỞ PORT ---
EXPOSE 8080 22
CMD ["/start.sh"]
