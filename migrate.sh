#!/bin/bash

# Đường dẫn tới thư mục gốc cần kiểm tra
ROOT_DIR="/home/canvas/public_html/tmp/files/0000"
# Đường dẫn tới bucket S3
S3_BUCKET="s3://fidt-lms/account_1/canvas/prd"

# Hàm đệ quy để kiểm tra và tải lên các tệp
upload_files() {
    local current_dir="$1"
    
    for file in "$current_dir"/*; do
        if [ -d "$file" ]; then
            # Nếu là thư mục, gọi đệ quy
            upload_files "$file"
        else
            # Lấy tên tệp và đường dẫn tương đối
            relative_path=$(echo "${file#$ROOT_DIR/}" | sed 's/^0*//')
            s3_path="$S3_BUCKET/$relative_path" 
            
            # Kiểm tra xem tệp đã tồn tại trên S3 chưa
            if aws s3 ls --profile=aws "$s3_path" > /dev/null 2>&1; then
                echo "⏭️ Tệp $relative_path đã tồn tại trên S3, bỏ qua."
            else
                echo "⬆️ Đang tải lên tệp $relative_path ... lên $s3_path"
                aws s3 --profile=aws cp "$file" "$s3_path"
                
                if [ $? -eq 0 ]; then
                    echo "✅ Tải lên thành công: $relative_path"
                else
                    echo "❌ Tải lên thất bại: $relative_path"
                fi
            fi
        fi
    done
}

# Bắt đầu từ thư mục gốc
upload_files "$ROOT_DIR"