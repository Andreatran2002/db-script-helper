#!/bin/bash
# Load environment variables from .env file if it exists
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

# Thư mục chứa backup (cập nhật đường dẫn phù hợp)
BACKUP_DIR="${BACKUP_DIR:-}"
HOST="${HOST:-localhost}"
PGPASSWORD="${PGPASSWORD:-localhost}"
USER="${USER:-postgres}"
PORT="${PORT:-5432}"
# Tên database cần restore
DB_NAME="${DB_NAME:-postgres}"

SLEEP_TIME=1

# Danh sách các bảng cần skip
SKIP_TABLES=()

# Tạo thư mục log nếu chưa tồn tại
mkdir -p ./log

# Tên file log
LOG_FILE="./log/${HOST}-${DB_NAME}-$(date +%Y%m%d).log"

# Hàm ghi log
log_message() {
    echo "$1" | tee -a "$LOG_FILE"
}

# Hàm kiểm tra kết nối đến database
check_db_connection() {
    log_message "🔄 Đang kiểm tra kết nối đến database..."
    PGPASSWORD="$PGPASSWORD" psql -d "$DB_NAME" -U $USER -h $HOST -p $PORT -c "\q"
    if [ $? -eq 0 ]; then
        log_message "✅ Kết nối thành công đến database: $DB_NAME"
    else
        log_message "❌ Kết nối thất bại đến database: $DB_NAME"
        exit 1
    fi
}

# Hàm lấy danh sách các bảng trong backup
get_tables_list() {
    log_message "🔄 Đang lấy danh sách bảng từ database..."
    TABLES=$(pg_restore -l $BACKUP_DIR | awk '/TABLE DATA/ {print $7}')
    log_message "Danh sách bảng sẽ được restore:"
    log_message "$TABLES"
}

get_sequences_list() {
    log_message "🔄 Đang lấy danh sách sequence từ database..."
    SEQUENCES=$(pg_restore -l $BACKUP_DIR | awk '/SEQUENCE SET/ {print $7}')
    log_message "Danh sách sequence sẽ được restore:"
    log_message "$SEQUENCES"
}

# Hàm kiểm tra xem bảng có trong danh sách skip không
is_table_skipped() {
    local table=$1
    for skip_table in "${SKIP_TABLES[@]}"; do
        if [ "$table" == "$skip_table" ]; then
            return 0
        fi
    done
    return 1
}

restore_schema() {
    log_message "🔄 Đang restore schema..."
    PGPASSWORD="$PGPASSWORD" pg_restore -d "$DB_NAME" -U $USER -h $HOST -p $PORT -Fd "$BACKUP_DIR" --schema-only
    log_message "🎉 Restore schema hoàn tất!"
    sleep $SLEEP_TIME
}

# Hàm restore các bảng
restore_tables() {
    local total_tables=$(echo "$TABLES" | wc -l)
    local restored_count=0

    for TABLE in $TABLES; do
        TABLE=$(echo $TABLE | xargs) # Trim whitespace
        if is_table_skipped "$TABLE"; then
            log_message "⏭️ Bỏ qua bảng: $TABLE"
            continue
        fi
        log_message "⏳ Đang restore bảng: $TABLE ..."
        PGPASSWORD="$PGPASSWORD" pg_restore -d "$DB_NAME" -U $USER -h $HOST -p $PORT -Fd "$BACKUP_DIR" --table="$TABLE" --disable-triggers --data-only
        
        if [ $? -eq 0 ]; then
            restored_count=$((restored_count + 1))
            log_message "✅ Restore thành công bảng: $TABLE ($restored_count/$total_tables)"
        else
            log_message "❌ Restore thất bại bảng: $TABLE"
        fi

        # Chờ 10 giây trước khi tiếp tục bảng tiếp theo
        log_message "⏸️ Đợi $SLEEP_TIME giây trước khi restore bảng tiếp theo..."
        sleep $SLEEP_TIME
    done
    log_message "🎉 Quá trình restore hoàn tất!"
}

restore_sequence() {
    local total_tables=$(echo "$SEQUENCES" | wc -l)
    local restored_count=0

    for SEQUENCE in $SEQUENCES; do
        SEQUENCE=$(echo $SEQUENCE | xargs) # Trim whitespace
        if is_table_skipped "$SEQUENCE"; then
            log_message "⏭️ Bỏ qua bảng: $SEQUENCE"
            continue
        fi
        log_message "🔄 Đang restore sequence cho bảng: $SEQUENCE ..."
        PGPASSWORD="$PGPASSWORD" psql -d "$DB_NAME" -U $USER -h $HOST -p $PORT -c "SELECT SETVAL('${SEQUENCE}', MAX(id)) FROM \"${SEQUENCE%_id_seq}\";"
        
        if [ $? -eq 0 ]; then
            restored_count=$((restored_count + 1))
            log_message "✅ Restore sequence thành công cho bảng: $SEQUENCE ($restored_count/$total_tables)"
        else
            log_message "❌ Restore sequence thất bại cho bảng: $SEQUENCE"
        fi

        # Chờ 10 giây trước khi tiếp tục bảng tiếp theo
        log_message "⏸️ Đợi $SLEEP_TIME giây trước khi restore sequence bảng tiếp theo..."
        sleep $SLEEP_TIME
    done
    log_message "🎉 Quá trình restore sequence hoàn tất!"
}

# Thực thi các hàm
check_db_connection
# get_tables_list
# restore_schema
# restore_tables 
get_sequences_list
restore_sequence