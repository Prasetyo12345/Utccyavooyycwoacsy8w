#!/usr/bin/env bash
set -euo pipefail

KEYS_DIR="./keys"
DB_FILE="$KEYS_DIR/keys.db"

mkdir -p "$KEYS_DIR"
touch "$DB_FILE"

now() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

# RANDOM KEY default 32 chars
rand_key() {
  tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32
  echo
}

sha256() {
  echo -n "$1" | openssl dgst -sha256 | awk '{print $2}'
}

# CREATE KEY ENTRY
add_key() {
  local key="$1"
  local maxdev="$2"
  local days="$3"

  local created=$(now)
  local expiry=$(date -d "+${days} days" +"%Y-%m-%d")
  local hash=$(sha256 "$key")

  echo "{\"key\":\"$key\",\"hash\":\"$hash\",\"maxdev\":$maxdev,\"days\":$days,\"created\":\"$created\",\"expiry\":\"$expiry\",\"revoked\":false}" >> "$DB_FILE"

  echo ""
  echo "=== KEY CREATED ==="
  echo "KEY        : $key"
  echo "MAX DEV    : $maxdev"
  echo "DAYS       : $days"
  echo "EXPIRED    : $expiry"
}

# READ ALL KEYS INTO ARRAY
read_keys() {
  mapfile -t KEYS < "$DB_FILE"
}

# PRINT LIST RAPI
print_list() {
  read_keys
  if [ ${#KEYS[@]} -eq 0 ]; then
    echo "Belum ada key."
    return
  fi

  index=1
  for row in "${KEYS[@]}"; do
    key=$(echo "$row" | sed -n 's/.*"key":"\([^"]*\)".*/\1/p')
    maxdev=$(echo "$row" | sed -n 's/.*"maxdev":\([^,]*\).*/\1/p')
    days=$(echo "$row" | sed -n 's/.*"days":\([^,]*\).*/\1/p')
    expiry=$(echo "$row" | sed -n 's/.*"expiry":"\([^"]*\)".*/\1/p')
    revoked=$(echo "$row" | sed -n 's/.*"revoked":\([^}]*\).*/\1/p')

    if [ "$revoked" = "true" ]; then
      status="BANNED"
    else
      status="ACTIVE"
    fi

    echo "[$index]"
    echo "Key       : $key"
    echo "Max Dev   : $maxdev"
    echo "Days      : $days"
    echo "Expired   : $expiry"
    echo "Status    : $status"
    echo "------------------------------"

    index=$((index+1))
  done
}

# BAN KEY
ban_key() {
  read_keys
  print_list
  echo ""
  read -p "Pilih nomor key yang ingin di-BAN: " num

  if ! [[ "$num" =~ ^[0-9]+$ ]]; then
    echo "Input salah."
    return
  fi

  line="${KEYS[$((num-1))]}"
  if [ -z "$line" ]; then
    echo "Key tidak ditemukan."
    return
  fi

  tmp=$(mktemp)

  index=1
  while read -r row; do
    if [ $index -eq $num ]; then
      row=$(echo "$row" | sed 's/"revoked":false/"revoked":true/')
    fi
    echo "$row" >> "$tmp"
    index=$((index+1))
  done < "$DB_FILE"

  mv "$tmp" "$DB_FILE"
  echo "Key nomor $num berhasil di-BANNED."
}

# DELETE KEY
delete_key() {
  read_keys
  print_list
  echo ""
  read -p "Pilih nomor key yang ingin dihapus: " num

  if ! [[ "$num" =~ ^[0-9]+$ ]]; then
    echo "Input salah."
    return
  fi

  sed -i "${num}d" "$DB_FILE"

  echo "Key nomor $num berhasil dihapus."
}

export_keys() {
  cp "$DB_FILE" keys_export.json
  echo "Export → keys_export.json"
}

github_push() {
  git add "$DB_FILE"
  git commit -m "update keys $(now)" || true
  git push origin main
}

# ========= MENU INTERAKTIF ==========
menu() {
  clear
  echo "============================"
  echo "         KEYGEN MENU"
  echo "============================"
  echo "1) Generate Random Key"
  echo "2) Generate Custom Key"
  echo "3) List Keys"
  echo "4) Ban Key"
  echo "5) Delete Key"
  echo "6) Export Keys"
  echo "7) Push to GitHub"
  echo "0) Exit"
  echo "============================"
  read -p "Pilih: " opt

  case "$opt" in
    1)
      read -p "Max Device: " maxdev
      read -p "Expired Days: " days
      key=$(rand_key)
      add_key "$key" "$maxdev" "$days"
      read -p "Enter untuk lanjut..."
      menu
      ;;
    2)
      read -p "Custom Key: " key
      read -p "Max Device: " maxdev
      read -p "Expired Days: " days
      add_key "$key" "$maxdev" "$days"
      read -p "Enter untuk lanjut..."
      menu
      ;;
    3)
      print_list
      read -p "Enter untuk lanjut..."
      menu
      ;;
    4)
      ban_key
      read -p "Enter untuk lanjut..."
      menu
      ;;
    5)
      delete_key
      read -p "Enter untuk lanjut..."
      menu
      ;;
    6)
      export_keys
      read -p "Enter untuk lanjut..."
      menu
      ;;
    7)
      github_push
      read -p "Enter untuk lanjut..."
      menu
      ;;
    0)
      exit 0
      ;;
    *)
      echo "Pilihan salah."
      sleep 1
      menu
      ;;
  esac
}

if [ $# -eq 0 ]; then
  menu
fi
