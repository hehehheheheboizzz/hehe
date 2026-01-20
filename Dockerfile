# Sử dụng nền tảng Ubuntu chuẩn
FROM ubuntu:22.04

# --- 1. CÀI ĐẶT JAVA 21 VÀ CÁC CÔNG CỤ CẦN THIẾT ---
# Lệnh này giúp Java luôn có sẵn mỗi khi server bật lên
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    curl wget sudo nano unzip openssh-server \
    ca-certificates \
    openjdk-21-jre-headless \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir /var/run/sshd

# --- 2. CẤU HÌNH SSH (Mật khẩu: 123456) ---
RUN echo "root:123456" | chpasswd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# --- 3. TỰ ĐỘNG TẠO SCRIPT KHỞI ĐỘNG ---
# File này sẽ chạy ngay khi bạn nhấn Deploy
RUN printf '#!/bin/bash\n\
echo "🚀 DANG KHOI DONG MINECRAFT SERVER..."\n\
service ssh start\n\
\n\
# Dong y EULA tu dong\n\
echo "eula=true" > eula.txt\n\
\n\
# Kiem tra va chay server.jar\n\
if [ -f "server.jar" ]; then\n\
  java -Xmx1024M -Xms1024M -jar server.jar nogui\n\
else\n\
  echo "❌ Khong tim thay file server.jar! Dang treo de ban kiem tra..."\n\
  tail -f /dev/null\n\
fi' > /start.sh && chmod +x /start.sh

# --- 4. THIẾT LẬP CHẠY ---
WORKDIR /
EXPOSE 22 25565

# Chạy bằng bash để tránh lỗi Railpack
CMD ["/bin/bash", "/start.sh"]
