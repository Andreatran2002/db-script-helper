#!/bin/bash

# Thư mục chứa backup (cập nhật đường dẫn phù hợp)
BACKUP_DIR="directus-uat"
HOST="100.64.0.46"
PGPASSWORD="VlPXfknHciLeFvnKaz62k7Ihd15frYsEpeB7dUHibRFq8K1DAOcODWeM4oRUykV7"
USER="postgres"
# Tên database cần restore
DB_NAME="directus"

SLEEP_TIME=2

# Danh sách các bảng cần skip
SKIP_TABLES=()

# Hàm kiểm tra kết nối đến database
check_db_connection() {
    echo "🔄 Đang kiểm tra kết nối đến database..."
    PGPASSWORD="$PGPASSWORD" psql -d "$DB_NAME" -U $USER -h $HOST -p 5432 -c "\q"
    if [ $? -eq 0 ]; then
        echo "✅ Kết nối thành công đến database: $DB_NAME"
    else
        echo "❌ Kết nối thất bại đến database: $DB_NAME"
        exit 1
    fi
}

# Hàm lấy danh sách các bảng trong backup
get_tables_list() {
    echo "🔄 Đang lấy danh sách bảng từ database..."
    TABLES=$(pg_restore -l $BACKUP_DIR | awk '/TABLE DATA/ {print $7}')
    echo "Danh sách bảng sẽ được restore:"
    echo "$TABLES"
}


get_sequences_list() {
    echo "🔄 Đang lấy danh sách sequence từ database..."
    SEQUENCES=$(pg_restore -l $BACKUP_DIR | awk '/SEQUENCE SET/ {print $7}')
    echo "Danh sách sequence sẽ được restore:"
    echo "$SEQUENCES"
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
    echo "🔄 Đang restore schema..."
    PGPASSWORD="$PGPASSWORD" pg_restore -d "$DB_NAME" -U $USER -h $HOST -p 5432 -Fd "$BACKUP_DIR" --schema-only
    echo "🎉 Restore schema hoàn tất!"
    sleep $SLEEP_TIME
}

# Hàm restore các bảng
restore_tables() {
    local total_tables=$(echo "$TABLES" | wc -l)
    local restored_count=0

    for TABLE in $TABLES; do
        TABLE=$(echo $TABLE | xargs) # Trim whitespace
        if is_table_skipped "$TABLE"; then
            echo "⏭️ Bỏ qua bảng: $TABLE"
            continue
        fi
        echo "⏳ Đang restore bảng: $TABLE ..."
        PGPASSWORD="$PGPASSWORD" pg_restore -d "$DB_NAME" -U $USER -h $HOST -p 5432 -Fd "$BACKUP_DIR" --table="$TABLE" --disable-triggers --data-only
        
        if [ $? -eq 0 ]; then
            restored_count=$((restored_count + 1))
            echo "✅ Restore thành công bảng: $TABLE ($restored_count/$total_tables)"
        else
            echo "❌ Restore thất bại bảng: $TABLE"
        fi

        # Chờ 10 giây trước khi tiếp tục bảng tiếp theo
        echo "⏸️ Đợi $SLEEP_TIME giây trước khi restore bảng tiếp theo..."
        sleep $SLEEP_TIME
    done
    echo "🎉 Quá trình restore hoàn tất!"
}

restore_sequence() {
    local total_tables=$(echo "$SEQUENCES" | wc -l)
    local restored_count=0

    for SEQUENCE in $SEQUENCES; do
        SEQUENCE=$(echo $SEQUENCE | xargs) # Trim whitespace
        if is_table_skipped "$SEQUENCE"; then
            echo "⏭️ Bỏ qua bảng: $SEQUENCE"
            continue
        fi
        echo "🔄 Đang restore sequence cho bảng: $SEQUENCE ..."
        PGPASSWORD="$PGPASSWORD" psql -d "$DB_NAME" -U $USER -h $HOST -p 5432 -c "SELECT SETVAL('${SEQUENCE}', MAX(id)) FROM ${SEQUENCE%_id_seq};"
        
        if [ $? -eq 0 ]; then
            restored_count=$((restored_count + 1))
            echo "✅ Restore sequence thành công cho bảng: $SEQUENCE ($restored_count/$total_tables)"
        else
            echo "❌ Restore sequence thất bại cho bảng: $SEQUENCE"
        fi

        # Chờ 10 giây trước khi tiếp tục bảng tiếp theo
        echo "⏸️ Đợi $SLEEP_TIME giây trước khi restore sequence bảng tiếp theo..."
        sleep $SLEEP_TIME
    done
    echo "🎉 Quá trình restore sequence hoàn tất!"
   
}

# Thực thi các hàm
check_db_connection
# get_tables_list
# restore_schema
# restore_tables 
get_sequences_list
restore_sequence