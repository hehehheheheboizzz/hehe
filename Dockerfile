FROM ubuntu:22.04

# --- 1. CÀI ĐẶT JAVA 21, WGET, CURL VÀ SSH ---
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    curl wget sudo nano unzip openssh-server \
    openjdk-21-jre-headless \
    jq \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /var/run/sshd

# --- 2. CẤU HÌNH SSH (Mật khẩu: 123456) ---
# LƯU Ý: Mật khẩu này cực kỳ không an toàn nếu mở port 22 ra Internet
RUN echo "root:123456" | chpasswd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# --- 3. TẠO THƯ MỤC LÀM VIỆC ---
WORKDIR /minecraft

# --- 4. TẠO SCRIPT KHỞI ĐỘNG THÔNG MINH ---
RUN printf '#!/bin/bash\n\
echo "🚀 KHOI DONG HE THONG..."\n\
service ssh start\n\
\n\
# Dong y EULA\n\
echo "eula=true" > eula.txt\n\
\n\
# KIEM TRA VA TAI SERVER.JAR NEU CHUA CO\n\
if [ ! -f "server.jar" ]; then\n\
  echo "📥 Chua thay server.jar, dang tai PaperMC moi nhat (1.20.4)..."\n\
  # Tu dong lay link tai ban build moi nhat cua 1.20.4\n\
  VER="1.20.4"\n\
  URL="https://api.papermc.io/v2/projects/paper/versions/$VER/builds/$(curl -s https://api.papermc.io/v2/projects/paper/versions/$VER | jq -r .builds[-1])/downloads/paper-$VER-$(curl -s https://api.papermc.io/v2/projects/paper/versions/$VER | jq -r .builds[-1]).jar"\n\
  wget -O server.jar $URL\n\
  echo "✅ Da tai xong!"\n\
fi\n\
\n\
# CHAY SERVER\n\
echo "🔥 Dang bat Minecraft Server..."\n\
java -Xmx2G -Xms2G -jar server.jar nogui\n\
' > /start.sh && chmod +x /start.sh

# --- 5. THIẾT LẬP CHẠY ---
EXPOSE 22 25565

CMD ["/bin/bash", "/start.sh"]
