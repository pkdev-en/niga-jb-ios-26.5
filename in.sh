#!/bin/bash

clear

# ==========================================
# 🌟 COLOR CODES
# ==========================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

BASE_DIR="/home/daytona/vms"
IMAGE_BASE="/home/daytona/ubuntu22_base.qcow2"

if [ "$(id -u)" -eq 0 ]; then
    SUDO_CMD=""
else
    SUDO_CMD="sudo"
fi

$SUDO_CMD mkdir -p "$BASE_DIR" > /dev/null 2>&1

# ==========================================
# 🛠️ HELPER FUNCTIONS
# ==========================================
loading_bar() {
    local title="$1"
    echo -ne "${YELLOW}⏳ $title ${NC}[          ]"
    sleep 0.2
    echo -ne "\b\b\b\b\b\b\b\b\b\b\b[===       ]"
    sleep 0.2
    echo -ne "\b\b\b\b\b\b\b\b\b\b\b[======    ]"
    sleep 0.2
    echo -ne "\b\b\b\b\b\b\b\b\b\b\b[========= ]"
    sleep 0.2
    echo -ne "\b\b\b\b\b\b\b\b\b\b\b[==========]"
    echo -e " ${GREEN}DONE!${NC}"
}

ensure_base_image() {
    if [ ! -f "$IMAGE_BASE" ]; then
        echo -e "${YELLOW}📥 Downloading Base Ubuntu Image (One-time download)...${NC}"
        $SUDO_CMD wget -q --show-progress https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img -O "$IMAGE_BASE"
        $SUDO_CMD chmod 666 "$IMAGE_BASE"
    fi
}

# ==========================================
# 📊 MAIN MENU
# ==========================================
show_menu() {
    clear
    echo -e "${RED}==========================================================${NC}"
    echo -e "${WHITE}          [👹 MULTI-VM MANAGEMENT DASHBOARD 👹]          ${NC}"
    echo -e "${RED}==========================================================${NC}"
    echo ""
    echo -e "  ${CYAN}[1]${NC} 📌 Xem danh sách & Trạng thái tất cả Máy Ảo"
    echo -e "  ${CYAN}[2]${NC} ➕ Tạo Máy Ảo mới (Create New VM)"
    echo -e "  ${CYAN}[3]${NC} ▶️  Bật Máy Ảo (Start VM)"
    echo -e "  ${CYAN}[4]${NC} ⏸️  Tắt Máy Ảo (Stop VM)"
    echo -e "  ${CYAN}[5]${NC} 🗑️  Xóa Máy Ảo (Delete VM)"
    echo -e "  ${CYAN}[6]${NC} 🚪 Thoát"
    echo ""
    echo -e "${RED}==========================================================${NC}"
    echo -ne "${WHITE}🔹 Chọn chức năng [1-6]: ${NC}"
    read CHOICE
    
    case $CHOICE in
        1) list_vms; press_enter ;;
        2) create_vm ;;
        3) start_vm ;;
        4) stop_vm ;;
        5) delete_vm ;;
        6) exit 0 ;;
        *) echo -e "${RED}❌ Lựa chọn không hợp lệ!${NC}"; sleep 1; show_menu ;;
    esac
}

press_enter() {
    echo ""
    echo -ne "${WHITE}👉 Nhấn [ENTER] để quay lại Menu...${NC}"
    read
    show_menu
}

# ==========================================
# 1. DANH SÁCH MÁY ẢO
# ==========================================
list_vms() {
    clear
    echo -e "${CYAN}==========================================================${NC}"
    echo -e "${WHITE}📋 DANH SÁCH CÁC MÁY ẢO HIỆN CÓ:${NC}"
    echo -e "${CYAN}==========================================================${NC}"
    
    vms=$(ls "$BASE_DIR" 2>/dev/null)
    
    if [ -z "$vms" ]; then
        echo -e "${YELLOW}Chưa có máy ảo nào được tạo.${NC}"
        return
    fi
    
    printf "%-15s | %-8s | %-6s | %-10s | %-10s\n" "TÊN VM" "PORT" "RAM" "CPU" "TRẠNG THÁI"
    echo "----------------------------------------------------------"
    
    for vm in $vms; do
        if [ -f "$BASE_DIR/$vm/config.env" ]; then
            source "$BASE_DIR/$vm/config.env"
            
            # Kiểm tra VM có đang running không
            pid=$(pgrep -f "qemu.*$vm.qcow2")
            if [ -n "$pid" ]; then
                STATUS="${GREEN}RUNNING (PID $pid)${NC}"
            else
                STATUS="${RED}STOPPED${NC}"
            fi
            
            printf "%-15s | %-8s | %-6s | %-10s | %b\n" "$VM_NAME" "$TCP_HOST_PORT" "${RAM_GB}G" "${CPU_CORES} Cores" "$STATUS"
        fi
    done
}

# ==========================================
# 2. TẠO MÁY ẢO MỚI
# ==========================================
create_vm() {
    clear
    echo -e "${GREEN}==========================================================${NC}"
    echo -e "${WHITE}➕ TẠO MÁY ẢO UBUNTU MỚI${NC}"
    echo -e "${GREEN}==========================================================${NC}"
    echo ""
    
    echo -ne "${BLUE}🔹 Nhập tên Máy Ảo (Ví dụ: vm1, ubuntu2, dev): ${NC}"
    read VM_NAME
    VM_NAME=${VM_NAME:-vm1}
    
    VM_DIR="$BASE_DIR/$VM_NAME"
    if [ -d "$VM_DIR" ]; then
        echo -e "${RED}❌ Tên VM '$VM_NAME' đã tồn tại! Vui lòng chọn tên khác.${NC}"
        sleep 2
        show_menu
        return
    fi

    echo -ne "${BLUE}🔹 Cổng SSH ngoài (Host Port - Ví dụ: 2222, 2223, 2224): ${NC}"
    read TCP_HOST_PORT
    TCP_HOST_PORT=${TCP_HOST_PORT:-2222}

    echo -ne "${BLUE}🔹 Dung lượng RAM (GB - Ví dụ: 2, 4, 8): ${NC}"
    read RAM_GB
    RAM_GB=${RAM_GB:-4}

    echo -ne "${BLUE}🔹 Số CPU Cores (Ví dụ: 2, 4): ${NC}"
    read CPU_CORES
    CPU_CORES=${CPU_CORES:-2}

    echo -ne "${BLUE}🔹 Thêm dung lượng ổ cứng (GB - Ví dụ: 10, 20): ${NC}"
    read DISK_ADD
    DISK_ADD=${DISK_ADD:-10}

    echo -ne "${BLUE}🔹 Mật khẩu root/ubuntu (Mặc định: 1234): ${NC}"
    read USER_PASS
    USER_PASS=${USER_PASS:-1234}

    # Cài đặt gói nếu thiếu
    $SUDO_CMD apt-get update -y > /dev/null 2>&1
    $SUDO_CMD apt-get install -y qemu-system-x86 qemu-utils cloud-image-utils > /dev/null 2>&1

    ensure_base_image

    mkdir -p "$VM_DIR"
    
    loading_bar "Đang khởi tạo đĩa cứng cho $VM_NAME"
    $SUDO_CMD cp "$IMAGE_BASE" "$VM_DIR/$VM_NAME.qcow2"
    $SUDO_CMD chmod 666 "$VM_DIR/$VM_NAME.qcow2"
    $SUDO_CMD qemu-img resize "$VM_DIR/$VM_NAME.qcow2" +${DISK_ADD}G > /dev/null 2>&1

    loading_bar "Đang tạo file cấu hình Cloud-Init"
    cat <<EOF > "$VM_DIR/user-data"
#cloud-config
disable_root: false
ssh_pwauth: true
chpasswd:
  list: |
    root:${USER_PASS}
    ubuntu:${USER_PASS}
  expire: False
runcmd:
  - sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
  - sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
  - systemctl restart sshd || service ssh restart
EOF

    cloud-localds "$VM_DIR/seed.img" "$VM_DIR/user-data" > /dev/null 2>&1

    # Lưu thông số VM
    echo "VM_NAME=$VM_NAME" > "$VM_DIR/config.env"
    echo "TCP_HOST_PORT=$TCP_HOST_PORT" >> "$VM_DIR/config.env"
    echo "RAM_GB=$RAM_GB" >> "$VM_DIR/config.env"
    echo "CPU_CORES=$CPU_CORES" >> "$VM_DIR/config.env"
    echo "USER_PASS=$USER_PASS" >> "$VM_DIR/config.env"

    echo ""
    echo -e "${GREEN}✅ Khởi tạo máy ảo $VM_NAME thành công!${NC}"
    sleep 1
    
    echo -ne "${YELLOW}👉 Bạn có muốn BẬT máy ảo này ngay không? (y/n): ${NC}"
    read START_NOW
    if [ "$START_NOW" = "y" ] || [ "$START_NOW" = "Y" ]; then
        run_qemu "$VM_NAME"
    fi
    press_enter
}

# ==========================================
# THỰC THI CHẠY QEMU
# ==========================================
run_qemu() {
    local target_vm="$1"
    local VM_DIR="$BASE_DIR/$target_vm"

    if [ ! -f "$VM_DIR/config.env" ]; then
        echo -e "${RED}❌ Khởi động thất bại! Không tìm thấy cấu hình.${NC}"
        return
    fi

    source "$VM_DIR/config.env"

    # Tắt tiến trình cũ của VM này nếu có
    pkill -f "qemu.*$target_vm.qcow2" > /dev/null 2>&1

    nohup qemu-system-x86_64 \
        -hda "$VM_DIR/$target_vm.qcow2" \
        -m "${RAM_GB}G" \
        -smp "$CPU_CORES" \
        -drive file="$VM_DIR/seed.img",format=raw \
        -nographic \
        -netdev user,id=net0,hostfwd=tcp::${TCP_HOST_PORT}-:22 \
        -device e1000,netdev=net0 > /dev/null 2>&1 &

    echo ""
    echo -e "${GREEN}==========================================================${NC}"
    echo -e "🚀 MÁY ẢO [ $target_vm ] ĐÃ ĐƯỢC BẬT CHẠY ẨN!"
    echo -e "${GREEN}==========================================================${NC}"
    echo -e "👤 Username : ${CYAN}root${NC}"
    echo -e "🔑 Password : ${CYAN}${USER_PASS}${NC}"
    echo -e "🚀 Lệnh SSH : ${YELLOW}ssh root@localhost -p ${TCP_HOST_PORT}${NC}"
    echo -e "${GREEN}==========================================================${NC}"
}

# ==========================================
# 3. BẬT MÁY ẢO
# ==========================================
start_vm() {
    clear
    list_vms
    echo ""
    echo -ne "${BLUE}🔹 Nhập TÊN máy ảo bạn muốn BẬT: ${NC}"
    read TARGET
    if [ -d "$BASE_DIR/$TARGET" ]; then
        run_qemu "$TARGET"
    else
        echo -e "${RED}❌ Không tìm thấy máy ảo có tên: $TARGET${NC}"
    fi
    press_enter
}

# ==========================================
# 4. TẮT MÁY ẢO
# ==========================================
stop_vm() {
    clear
    list_vms
    echo ""
    echo -ne "${BLUE}🔹 Nhập TÊN máy ảo bạn muốn TẮT: ${NC}"
    read TARGET
    if [ -d "$BASE_DIR/$TARGET" ]; then
        pkill -f "qemu.*$TARGET.qcow2" > /dev/null 2>&1
        echo -e "${YELLOW}🛑 Đã tắt máy ảo: $TARGET${NC}"
    else
        echo -e "${RED}❌ Không tìm thấy máy ảo có tên: $TARGET${NC}"
    fi
    press_enter
}

# ==========================================
# 5. XÓA MÁY ẢO
# ==========================================
delete_vm() {
    clear
    list_vms
    echo ""
    echo -ne "${RED}⚠️  Nhập TÊN máy ảo bạn muốn XÓA VĨNH VIỄN: ${NC}"
    read TARGET
    if [ -d "$BASE_DIR/$TARGET" ]; then
        echo -ne "${RED}❗ Bạn có CỰC KỲ CHẮC CHẮN muốn xóa '$TARGET'? (yes/no): ${NC}"
        read CONFIRM
        if [ "$CONFIRM" = "yes" ]; then
            pkill -f "qemu.*$TARGET.qcow2" > /dev/null 2>&1
            rm -rf "$BASE_DIR/$TARGET"
            echo -e "${GREEN}✅ Đã xóa hoàn toàn máy ảo: $TARGET${NC}"
        else
            echo -e "${YELLOW}Đã hủy thao tác xóa.${NC}"
        fi
    else
        echo -e "${RED}❌ Không tìm thấy máy ảo có tên: $TARGET${NC}"
    fi
    press_enter
}

show_menu
