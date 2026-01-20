FROM ubuntu:22.04

# --- 1. CAI DAT HE THONG & MOI TRUONG ---
ENV DEBIAN_FRONTEND=noninteractive
ENV RESOLUTION=1280x720
ENV USER=thaodev
ENV PASSWORD=thaodev

# Cai dat cac goi can thiet: XFCE4, VNC, Firefox, Java 21, SSH...
RUN apt-get update && apt-get install -y \
    xfce4 xfce4-goodies \
    tigervnc-standalone-server \
    novnc websockify \
    firefox \
    curl wget sudo nano unzip git jq \
    openjdk-21-jre \
    net-tools iputils-ping \
    openssh-server \
    dbus-x11 x11-utils xterm \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir /var/run/sshd

# --- 2. CAI CLOUDFLARED ---
RUN wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb && \
    dpkg -i cloudflared-linux-amd64.deb && \
    rm cloudflared-linux-amd64.deb

# --- 3. CAU HINH SSH ---
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# --- 4. TAO USER & QUYEN ---
RUN useradd -m -s /bin/bash $USER && \
    echo "$USER:$PASSWORD" | chpasswd && \
    usermod -aG sudo $USER && \
    echo "$USER ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    echo "root:123456" | chpasswd

# --- 5. SETUP GIAO DIEN & MINECRAFT LOGIC ---
USER $USER
WORKDIR /home/$USER

# A. Cau hinh VNC
RUN mkdir -p .vnc && \
    echo "$PASSWORD" | vncpasswd -f > .vnc/passwd && \
    chmod 600 .vnc/passwd && \
    echo "#!/bin/bash" > .vnc/xstartup && \
    echo "unset SESSION_MANAGER" >> .vnc/xstartup && \
    echo "unset DBUS_SESSION_BUS_ADDRESS" >> .vnc/xstartup && \
    echo "startxfce4 &" >> .vnc/xstartup && \
    chmod +x .vnc/xstartup

# B. Tao thu muc Minecraft
RUN mkdir -p /home/$USER/minecraft && \
    mkdir -p /home/$USER/Desktop

# C. Script: Tu dong tai PaperMC va chay Server
# (Script nay se chay khi bam Icon)
RUN echo '#!/bin/bash\n\
MC_DIR="/home/'$USER'/minecraft"\n\
RAM="4G"\n\
cd $MC_DIR\n\
\n\
# Logic: Tai server neu chua co\n\
if [ ! -f "server.jar" ]; then\n\
    echo "📥 Thu muc trong! Dang tai PaperMC 1.20.4..."\n\
    VER="1.20.4"\n\
    BUILD=$(curl -s https://api.papermc.io/v2/projects/paper/versions/$VER/builds | jq -r .builds[-1].build)\n\
    URL="https://api.papermc.io/v2/projects/paper/versions/$VER/builds/$BUILD/downloads/paper-$VER-$BUILD.jar"\n\
    wget -O server.jar $URL\n\
    echo "eula=true" > eula.txt\n\
    \n\
    # Tao file run.sh\n\
    echo "#!/bin/bash" > run.sh\n\
    echo "java -Xms$RAM -Xmx$RAM -jar server.jar nogui" >> run.sh\n\
    chmod +x run.sh\n\
fi\n\
\n\
# Chay Server\n\
echo "🚀 Dang khoi dong Minecraft Server..."\n\
if [ -f "run.sh" ]; then\n\
    ./run.sh\n\
else\n\
    java -Xms$RAM -Xmx$RAM -jar server.jar nogui\n\
fi\n\
echo "⚠️ Server da tat. An Enter de thoat..."\n\
read temp\n\
' > /home/$USER/start_mc_logic.sh && chmod +x /home/$USER/start_mc_logic.sh

# D. Tao Shortcut ngoai Desktop
RUN echo '[Desktop Entry]\n\
Version=1.0\n\
Type=Application\n\
Name=START SERVER\n\
Comment=Bam de bat Minecraft Server\n\
Exec=xterm -fa "Monospace" -fs 14 -bg black -fg green -geometry 100x30 -title "Minecraft Console" -e "/home/'$USER'/start_mc_logic.sh"\n\
Icon=utilities-terminal\n\
Path=/home/'$USER'/minecraft\n\
Terminal=false\n\
StartupNotify=false' > /home/$USER/Desktop/StartServer.desktop && \
    chmod +x /home/$USER/Desktop/StartServer.desktop

# --- 6. SCRIPT KHOI DONG CONTAINER (Entrypoint) ---
# Chuyen ve root de bat dich vu he thong
USER root
RUN echo '#!/bin/bash' > /start.sh && \
    echo 'echo "=== SYSTEM BOOT ==="' >> /start.sh && \
    echo 'rm -rf /tmp/.X1-lock /tmp/.X11-unix/X1' >> /start.sh && \
    echo 'service ssh start' >> /start.sh && \
    echo 'su - '$USER' -c "vncserver :1 -geometry $RESOLUTION -depth 24"' >> /start.sh && \
    echo 'nohup /usr/share/novnc/utils/launch.sh --vnc localhost:5901 --listen 6080 > /var/log/novnc.log 2>&1 &' >> /start.sh && \
    echo 'if [ ! -z "$CF_TOKEN" ]; then' >> /start.sh && \
    echo '  echo "☁️ Connecting Cloudflare..."' >> /start.sh && \
    echo '  cloudflared tunnel run --token $CF_TOKEN &' >> /start.sh && \
    echo 'fi' >> /start.sh && \
    echo 'echo "✅ READY! Web: http://IP:6080 | SSH: Port 2222"' >> /start.sh && \
    echo 'tail -f /dev/null' >> /start.sh && \
    chmod +x /start.sh

# --- 7. START ---
EXPOSE 6080 5901 25565 22
CMD ["/start.sh"]
