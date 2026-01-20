# Sử dụng Ubuntu 22.04 làm nền tảng
FROM ubuntu:22.04

# --- 1. CÀI ĐẶT JAVA 21 & CÔNG CỤ HỆ THỐNG ---
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    curl wget sudo nano unzip openssh-server \
    ca-certificates \
    # Cài Java 21 - Bắt buộc để chạy Minecraft 1.21.1
    openjdk-21-jre-headless \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir /var/run/sshd

# --- 2. CẤU HÌNH SSH & ROOT (Mật khẩu: 123456) ---
RUN echo "root:123456" | chpasswd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# --- 3. TẠO SCRIPT KHỞI ĐỘNG (ENTRYPOINT) TRỰC TIẾP ---
# Đoạn này sẽ tự tạo file /start.sh bên trong container khi build
RUN printf '#!/bin/bash\n\
echo "🚀 ĐANG KHỞI ĐỘNG MINECRAFT SERVER..."\n\
service ssh start\n\
\n\
# Tự động tạo và đồng ý EULA để tránh lỗi Exit Code 128\n\
echo "eula=true" > eula.txt\n\
\n\
# Kiểm tra file server.jar và chạy\n\
if [ -f "server.jar" ]; then\n\
  echo "✅ Tìm thấy server.jar, đang thực thi lệnh Java..."\n\
  java -Xmx1024M -Xms1024M -jar server.jar nogui\n\
else\n\
  echo "❌ KHÔNG TÌM THẤY server.jar TRONG THƯ MỤC GỐC!"\n\
  echo "Vui lòng kiểm tra lại tên file hoặc upload file vào thư mục gốc."\n\
  tail -f /dev/null\n\
fi' > /start.sh && chmod +x /start.sh

# --- 4. THIẾT LẬP MÔI TRƯỜNG LÀM VIỆC ---
WORKDIR /
EXPOSE 22 25565

# --- 5. LỆNH CHẠY CHÍNH ---
# Dùng bash để chạy start.sh giúp Railpack nhận diện được script khởi động
CMD ["/bin/bash", "/start.sh"]
