FROM ubuntu:22.04

# --- 1. CÀI ĐẶT MÔI TRƯỜNG & SSH ---
ENV DEBIAN_FRONTEND=noninteractive
ENV RESOLUTION=1920x1080

RUN apt-get update && apt-get install -y \
    xfce4 xfce4-goodies \
    tigervnc-standalone-server \
    novnc websockify \
    firefox \
    curl wget sudo nano unzip git \
    openjdk-21-jre \
    net-tools iputils-ping \
    openssh-server \
    dbus-x11 x11-utils \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir /var/run/sshd

# --- 2. CẤU HÌNH SSH ---
# Cho phép login bằng password
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# --- 3. CÀI CLOUDFLARED ---
RUN wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb && \
    dpkg -i cloudflared-linux-amd64.deb && \
    rm cloudflared-linux-amd64.deb

# --- 4. TẠO USER 'thaodev' ---
# Pass: thaodev | Sudo không cần pass
RUN useradd -m -s /bin/bash thaodev && \
    echo "thaodev:thaodev" | chpasswd && \
    usermod -aG sudo thaodev && \
    echo "thaodev ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    echo "root:123456" | chpasswd

# --- 5. CẤU HÌNH VNC ---
USER thaodev
WORKDIR /home/thaodev
RUN mkdir -p .vnc && \
    echo "thaodev" | vncpasswd -f > .vnc/passwd && \
    chmod 600 .vnc/passwd && \
    echo "#!/bin/bash" > .vnc/xstartup && \
    echo "xrdb \$HOME/.Xresources" >> .vnc/xstartup && \
    echo "startxfce4 &" >> .vnc/xstartup && \
    chmod +x .vnc/xstartup

# --- 6. SCRIPT KHỞI ĐỘNG (SSH + VNC + Cloudflare) ---
RUN echo '#!/bin/bash' > start.sh && \
    echo 'echo "=== KHOI DONG SYSTEM ==="' >> start.sh && \
    echo 'sudo rm -rf /tmp/.X1-lock /tmp/.X11-unix/X1' >> start.sh && \
    echo '' >> start.sh && \
    echo '# 1. Bat SSH Server' >> start.sh && \
    echo 'sudo service ssh start' >> start.sh && \
    echo '' >> start.sh && \
    echo '# 2. Bat VNC Server' >> start.sh && \
    echo 'vncserver :1 -geometry $RESOLUTION -depth 24' >> start.sh && \
    echo '' >> start.sh && \
    echo '# 3. Bat Web VNC (noVNC)' >> start.sh && \
    echo '/usr/share/novnc/utils/launch.sh --vnc localhost:5901 --listen 6080 &' >> start.sh && \
    echo '' >> start.sh && \
    echo '# 4. Ket noi Cloudflare' >> start.sh && \
    echo 'if [ ! -z "$CF_TOKEN" ]; then' >> start.sh && \
    echo '  cloudflared tunnel run --token $CF_TOKEN' >> start.sh && \
    echo 'else' >> start.sh && \
    echo '  echo "⚠️ Chay Local Mode. IP:6080 (Web) | IP:2222 (SSH)"' >> start.sh && \
    echo '  tail -f /dev/null' >> start.sh && \
    echo 'fi' >> start.sh && \
    chmod +x start.sh

# --- 7. START ---
EXPOSE 6080 5901 25565 22
CMD ["./start.sh"]
