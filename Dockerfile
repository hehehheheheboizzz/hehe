FROM ubuntu:22.04

# --- 1. CÀI ĐẶT CÁC GÓI CẦN THIẾT ---
# Java 21, SSH, Docker Client, Screen, Nano, Curl...
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    curl wget sudo nano unzip jq \
    openssh-server \
    net-tools iputils-ping \
    ca-certificates \
    docker.io \
    iptables \
    openjdk-21-jre-headless \
    screen \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir /var/run/sshd

# --- 2. CẤU HÌNH SSH ---
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# --- 3. TẠO USER 'trthaodev' ---
# Pass: thaodev@ | User này có quyền sudo và docker
RUN useradd -m -s /bin/bash trthaodev && \
    echo "trthaodev:thaodev@" | chpasswd && \
    usermod -aG sudo trthaodev && \
    usermod -aG docker trthaodev && \
    echo "trthaodev ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    echo "root:123456" | chpasswd

# Tạo thư mục làm việc cho Minecraft
RUN mkdir -p /home/trthaodev/minecraft && \
    chown -R trthaodev:trthaodev /home/trthaodev/minecraft

# --- 4. CÀI CLOUDFLARED (Mới nhất) ---
RUN wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb && \
    dpkg -i cloudflared-linux-amd64.deb && \
    rm cloudflared-linux-amd64.deb

# --- 5. CÀI FILEBROWSER (Quản lý file qua Web) ---
RUN curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash

# --- 6. TẠO SCRIPT: QUẢN LÝ MINECRAFT ---
# Script này nằm trong /usr/local/bin để gọi ở đâu cũng được
RUN echo '#!/bin/bash\n\
MC_DIR="/home/trthaodev/minecraft"\n\
RAM="4G"\n\
\n\
cd $MC_DIR\n\
\n\
# Ham kiem tra va tai PaperMC\n\
check_install() {\n\
    if [ ! -f "server.jar" ]; then\n\
        echo "📥 Chua co server.jar. Dang tai PaperMC 1.20.4..."\n\
        VER="1.20.4"\n\
        # Lay build moi nhat tu API\n\
        BUILD=$(curl -s https://api.papermc.io/v2/projects/paper/versions/$VER/builds | jq -r .builds[-1].build)\n\
        URL="https://api.papermc.io/v2/projects/paper/versions/$VER/builds/$BUILD/downloads/paper-$VER-$BUILD.jar"\n\
        wget -O server.jar $URL\n\
        echo "eula=true" > eula.txt\n\
        chown trthaodev:trthaodev server.jar eula.txt\n\
        echo "✅ Tai xong!"\n\
    fi\n\
}\n\
\n\
# Ham khoi dong server trong Screen\n\
start_mc() {\n\
    check_install\n\
    if screen -list | grep -q "mc_server"; then\n\
        echo "⚠️ Server dang chay roi!"\n\
    else\n\
        echo "🚀 Dang bat Minecraft Server..."\n\
        # Chay duoi quyen user trthaodev de an toan\n\
        su - trthaodev -c "cd ~/minecraft && screen -dmS mc_server java -Xms$RAM -Xmx$RAM -jar server.jar nogui"\n\
        echo "✅ Server da chay ngam. Go lenh sau de xem: screen -r mc_server"\n\
    fi\n\
}\n\
\n\
start_mc\n\
' > /usr/local/bin/mc-autostart && chmod +x /usr/local/bin/mc-autostart

# --- 7. SCRIPT: ENTRYPOINT (CHẠY KHI KHỞI ĐỘNG CONTAINER) ---
RUN echo '#!/bin/bash' > /start.sh && \
    echo 'echo "=== SYSTEM STARTING ==="' >> /start.sh && \
    echo '' >> /start.sh && \
    # Fix quyền Docker Socket (quan trọng để chạy docker trong docker)
    echo 'if [ -S /var/run/docker.sock ]; then' >> /start.sh && \
    echo '  chmod 666 /var/run/docker.sock' >> /start.sh && \
    echo 'fi' >> /start.sh && \
    # 1. Start SSH
    echo 'service ssh start' >> /start.sh && \
    # 2. Start FileBrowser (Port 8080)
    echo 'nohup filebrowser -r /home/trthaodev -p 8080 --no-auth > /var/log/fb.log 2>&1 &' >> /start.sh && \
    # 3. Start Minecraft Auto
    echo '/usr/local/bin/mc-autostart' >> /start.sh && \
    # 4. Start Cloudflare Tunnel (Nếu có Token)
    echo 'if [ ! -z "$CF_TOKEN" ]; then' >> /start.sh && \
    echo '  echo "☁️ Dang ket noi Cloudflare..."' >> /start.sh && \
    echo '  cloudflared tunnel run --token $CF_TOKEN' >> /start.sh && \
    echo 'else' >> /start.sh && \
    echo '  echo "⚠️ Khong co CF_TOKEN -> Chi chay Local. Treo process de giu container..."' >> /start.sh && \
    echo '  tail -f /dev/null' >> /start.sh && \
    echo 'fi' >> /start.sh && \
    chmod +x /start.sh

# --- 8. FINALIZE ---
WORKDIR /home/trthaodev
EXPOSE 8080 22 25565
CMD ["/start.sh"]
