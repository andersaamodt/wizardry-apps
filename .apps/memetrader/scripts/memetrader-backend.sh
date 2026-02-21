#!/bin/sh

# Memetrader local-first protocol engine.
# Storage model: files, sidecars, xattrs; no database.

set -eu

json_escape() {
  printf '%s' "$1" | awk '
    BEGIN { ORS=""; first=1 }
    {
      gsub(/\\/, "\\\\")
      gsub(/"/, "\\\"")
      gsub(/\t/, "\\t")
      gsub(/\r/, "\\r")
      if (!first) {
        printf "\\n"
      }
      first=0
      printf "%s", $0
    }
  '
}

emit_error() {
  msg=$(json_escape "$1")
  printf '{"ok":false,"error":"%s"}\n' "$msg"
}

emit_ok_obj() {
  # payload must already be valid JSON object fields (without outer braces)
  printf '{"ok":true,%s}\n' "$1"
}

now_iso() {
  date -u '+%Y-%m-%dT%H:%M:%SZ'
}

now_epoch() {
  date +%s
}

sha256_file() {
  f=$1
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$f" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$f" | awk '{print $1}'
  else
    cksum "$f" | awk '{print $1}'
  fi
}

sha256_text() {
  txt=$1
  tmp=$(mktemp "${TMPDIR:-/tmp}/memetrader-hash.XXXXXX")
  printf '%s' "$txt" > "$tmp"
  out=$(sha256_file "$tmp")
  rm -f "$tmp"
  printf '%s' "$out"
}

random_hex() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 16
  else
    dd if=/dev/urandom bs=16 count=1 2>/dev/null | od -An -tx1 | tr -d ' \n'
  fi
}

safe_token() {
  token=$1
  printf '%s' "$token" | tr '[:upper:]' '[:lower:]' | sed 's#[^a-z0-9:_-]##g'
}

safe_name() {
  printf '%s' "$1" | sed 's#[^a-zA-Z0-9._-]#_#g'
}

normalize_csv_tokens() {
  raw=$1
  printf '%s' "$raw" | tr ';|' ',' | tr '[:upper:]' '[:lower:]' | tr ',' '\n' | awk '
    {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
      gsub(/[^a-z0-9:_-]/, "", $0)
      if ($0 == "") next
      if (!seen[$0]++) out[++n]=$0
    }
    END {
      for (i=1; i<=n; i++) {
        if (i>1) printf ","
        printf "%s", out[i]
      }
    }
  '
}

normalize_family_csv() {
  raw=$1
  csv=$(normalize_csv_tokens "$raw")
  if [ -z "$csv" ]; then
    printf ''
    return
  fi
  printf '%s' "$csv" | tr ',' '\n' | awk '
    {
      t=$0
      if (index(t, "family:") != 1) t="family:" t
      if (!seen[t]++) out[++n]=t
    }
    END {
      for (i=1; i<=n; i++) {
        if (i>1) printf ","
        printf "%s", out[i]
      }
    }
  '
}

config_get() {
  file=$1
  key=$2
  fallback=$3
  if [ ! -f "$file" ]; then
    printf '%s' "$fallback"
    return
  fi
  val=$(awk -F= -v k="$key" '$1==k {sub(/^[^=]*=/,""); print; found=1; exit} END { if (!found) print "" }' "$file")
  if [ -z "$val" ]; then
    printf '%s' "$fallback"
  else
    printf '%s' "$val"
  fi
}

config_set() {
  file=$1
  key=$2
  value=$3
  tmp=$(mktemp "${TMPDIR:-/tmp}/memetrader-config.XXXXXX")
  touch "$file"
  awk -F= -v k="$key" '$1 != k {print $0}' "$file" > "$tmp"
  printf '%s=%s\n' "$key" "$value" >> "$tmp"
  mv "$tmp" "$file"
}

config_set_default() {
  file=$1
  key=$2
  value=$3
  existing=$(config_get "$file" "$key" "")
  if [ -z "$existing" ]; then
    config_set "$file" "$key" "$value"
  fi
}

meta_get() {
  file=$1
  key=$2
  if [ ! -f "$file" ]; then
    printf ''
    return
  fi
  awk -F= -v k="$key" '$1==k {sub(/^[^=]*=/,""); print; exit}' "$file"
}

meta_set() {
  file=$1
  key=$2
  value=$3
  tmp=$(mktemp "${TMPDIR:-/tmp}/memetrader-meta.XXXXXX")
  touch "$file"
  awk -F= -v k="$key" '$1 != k {print $0}' "$file" > "$tmp"
  printf '%s=%s\n' "$key" "$value" >> "$tmp"
  mv "$tmp" "$file"
}

meta_set_if_missing() {
  file=$1
  key=$2
  value=$3
  cur=$(meta_get "$file" "$key")
  if [ -z "$cur" ]; then
    meta_set "$file" "$key" "$value"
  fi
}

append_unique_line() {
  file=$1
  line=$2
  touch "$file"
  if ! grep -F -x "$line" "$file" >/dev/null 2>&1; then
    printf '%s\n' "$line" >> "$file"
  fi
}

append_journal() {
  root=$1
  kind=$2
  payload=$3
  log="$root/journals/events.log"
  ts=$(now_iso)
  printf '%s\t%s\t%s\n' "$ts" "$kind" "$payload" >> "$log"
}

buyer_filter_file() {
  root=$1
  buyer=$2
  buyer_safe=$(safe_name "$buyer")
  printf '%s/buyers/%s.filters\n' "$root" "$buyer_safe"
}

buyer_blacklist_file() {
  root=$1
  buyer=$2
  buyer_safe=$(safe_name "$buyer")
  printf '%s/buyers/%s.blacklist\n' "$root" "$buyer_safe"
}

buyer_filter_get() {
  root=$1
  buyer=$2
  key=$3
  file=$(buyer_filter_file "$root" "$buyer")
  config_get "$file" "$key" ""
}

buyer_filter_set() {
  root=$1
  buyer=$2
  key=$3
  value=$4
  file=$(buyer_filter_file "$root" "$buyer")
  config_set "$file" "$key" "$value"
}

csv_has_token() {
  csv=$1
  needle=$2
  if [ -z "$csv" ] || [ -z "$needle" ]; then
    return 1
  fi
  printf '%s' "$csv" | tr ',' '\n' | awk -v n="$needle" '$0==n { found=1; exit } END { exit(found?0:1) }'
}

csv_has_prefix() {
  csv=$1
  value=$2
  if [ -z "$csv" ] || [ -z "$value" ]; then
    return 1
  fi
  printf '%s' "$csv" | tr ',' '\n' | awk -v v="$value" '
    {
      p=$0
      if (p == "") next
      if (index(v, p) == 1) { found=1; exit }
    }
    END { exit(found?0:1) }
  '
}

set_contains_sha() {
  set_file=$1
  sha=$2
  if [ ! -f "$set_file" ]; then
    return 1
  fi
  grep -F -x "$sha" "$set_file" >/dev/null 2>&1
}

ensure_root() {
  root=${1:-${MEMETRADER_HOME:-$HOME/.memes}}
  mkdir -p \
    "$root/artifacts/raw" \
    "$root/artifacts/canon" \
    "$root/meta" \
    "$root/votes" \
    "$root/msig" \
    "$root/graphs" \
    "$root/sorts" \
    "$root/patches/outbox" \
    "$root/patches/inbox" \
    "$root/trades/commits" \
    "$root/trades/reveals" \
    "$root/trades/receipts" \
    "$root/discovery" \
    "$root/buyers" \
    "$root/shops" \
    "$root/sets" \
    "$root/curation" \
    "$root/journals"

  touch "$root/msig/vocabulary.txt"
  touch "$root/msig/relations.tsv"
  touch "$root/graphs/lineage.tsv"
  touch "$root/graphs/relations.tsv"
  touch "$root/trades/journal.tsv"
  touch "$root/trades/acceptance.tsv"
  touch "$root/discovery/gossip_pubkeys.tsv"
  touch "$root/discovery/tag_bulletins.tsv"
  touch "$root/discovery/adverts.tsv"
  touch "$root/discovery/rendezvous.tsv"
  touch "$root/curation/curator-reputation.tsv"
  touch "$root/journals/events.log"

  shop_conf="$root/shops/shop.conf"
  config_set_default "$shop_conf" shop_name "Memetrader Local Shop"
  config_set_default "$shop_conf" shop_pubkey ""
  config_set_default "$shop_conf" listing_default "flat"
  config_set_default "$shop_conf" disclosure_mode "catalogue"
  config_set_default "$shop_conf" exposure_mode "full"
  config_set_default "$shop_conf" curated_set ""
  config_set_default "$shop_conf" temperature_tilt "0"
  config_set_default "$shop_conf" adaptive_pricing "0"
  config_set_default "$shop_conf" reputation_multiplier "0"

  printf '%s\n' "$root"
}

mime_of() {
  f=$1
  if command -v file >/dev/null 2>&1; then
    file --mime-type -b "$f" 2>/dev/null || printf 'application/octet-stream'
  else
    printf 'application/octet-stream'
  fi
}

kind_from_mime() {
  mime=$1
  case "$mime" in
    image/*) printf 'image' ;;
    video/*) printf 'video' ;;
    audio/*) printf 'audio' ;;
    *) printf 'binary' ;;
  esac
}

set_xattr_if_possible() {
  file=$1
  key=$2
  value=$3
  if command -v xattr >/dev/null 2>&1; then
    xattr -w "user.memetrader.$key" "$value" "$file" >/dev/null 2>&1 || true
  elif command -v setfattr >/dev/null 2>&1; then
    setfattr -n "user.memetrader.$key" -v "$value" "$file" >/dev/null 2>&1 || true
  fi
}

sample_hash() {
  f=$1
  tmp=$(mktemp "${TMPDIR:-/tmp}/memetrader-sample.XXXXXX")
  {
    wc -c < "$f" 2>/dev/null || printf '0'
    head -c 8192 "$f" 2>/dev/null || true
    tail -c 8192 "$f" 2>/dev/null || true
  } > "$tmp"
  out=$(sha256_file "$tmp")
  rm -f "$tmp"
  printf '%s' "$out"
}

is_animated_image() {
  src=$1
  mime=$2
  case "$mime" in
    image/gif|image/webp|image/apng) printf '1'; return ;;
  esac

  if command -v magick >/dev/null 2>&1; then
    n=$(magick identify -format '%n' "$src" 2>/dev/null | awk 'NR==1 {print $1}')
    case "$n" in
      ''|*[!0-9]*) printf '0' ;;
      *)
        if [ "$n" -gt 1 ]; then
          printf '1'
        else
          printf '0'
        fi
        ;;
    esac
    return
  fi

  if command -v identify >/dev/null 2>&1; then
    n=$(identify -format '%n' "$src" 2>/dev/null | awk 'NR==1 {print $1}')
    case "$n" in
      ''|*[!0-9]*) printf '0' ;;
      *)
        if [ "$n" -gt 1 ]; then
          printf '1'
        else
          printf '0'
        fi
        ;;
    esac
    return
  fi

  printf '0'
}

image_phash() {
  f=$1
  if command -v magick >/dev/null 2>&1; then
    bits=$(magick "$f[0]" -resize 8x8\! -colorspace Gray -depth 8 txt:- 2>/dev/null | awk '
      /gray\(/ {
        v=$0
        sub(/.*gray\(/, "", v)
        sub(/\).*/, "", v)
        arr[n]=v+0
        sum+=arr[n]
        n++
      }
      END {
        if (n == 0) {
          print ""
          exit
        }
        avg=sum/n
        for (i=0; i<n; i++) {
          if (arr[i] >= avg) printf "1"; else printf "0"
        }
      }
    ')
    if [ -n "$bits" ]; then
      printf '%s' "$bits" | if command -v shasum >/dev/null 2>&1; then shasum -a 256 | awk '{print substr($1,1,16)}'; else sha256sum | awk '{print substr($1,1,16)}'; fi
      return
    fi
  fi
  sample_hash "$f" | cut -c1-16
}

video_vhash() {
  f=$1
  if command -v ffprobe >/dev/null 2>&1; then
    ffprobe -v error -select_streams v:0 -show_frames -show_entries frame=key_frame,pkt_dts_time -of csv=p=0 "$f" 2>/dev/null \
      | awk -F, '$1 == 1 {print $2}' \
      | head -n 32 \
      | tr '\n' ',' \
      | if command -v shasum >/dev/null 2>&1; then shasum -a 256 | awk '{print substr($1,1,16)}'; else sha256sum | awk '{print substr($1,1,16)}'; fi
    return
  fi
  sample_hash "$f" | cut -c1-16
}

audio_ahash() {
  f=$1
  if command -v ffmpeg >/dev/null 2>&1 && command -v magick >/dev/null 2>&1; then
    tmp_png=$(mktemp "${TMPDIR:-/tmp}/memetrader-audio.XXXXXX.png")
    if ffmpeg -v error -i "$f" -lavfi showspectrumpic=s=128x128:legend=disabled -frames:v 1 "$tmp_png" -y >/dev/null 2>&1; then
      if [ -s "$tmp_png" ]; then
        out=$(image_phash "$tmp_png")
        rm -f "$tmp_png"
        printf '%s' "$out"
        return
      fi
    fi
    rm -f "$tmp_png"
  fi
  sample_hash "$f" | cut -c1-16
}

canonize() {
  src=$1
  kind=$2
  mime=$3
  canon_dir=$4

  profile='copy-fallback'

  case "$kind" in
    image)
      animated=$(is_animated_image "$src" "$mime")
      if [ "$animated" = '1' ]; then
        if command -v ffmpeg >/dev/null 2>&1; then
          out="$canon_dir/canon.apng"
          if ffmpeg -v error -i "$src" -plays 0 -f apng "$out" -y >/dev/null 2>&1; then
            profile='animated-apng'
          else
            cp "$src" "$out"
            profile='animated-copy'
          fi
        elif command -v magick >/dev/null 2>&1; then
          frames_dir="$canon_dir/frames"
          mkdir -p "$frames_dir"
          out="$canon_dir/canon-frame-stack.tar"
          if magick "$src" -coalesce "$frames_dir/frame-%06d.png" >/dev/null 2>&1; then
            tar -cf "$out" -C "$frames_dir" .
            profile='animated-frame-stack-tar'
          else
            cp "$src" "$out"
            profile='animated-copy'
          fi
        else
          out="$canon_dir/canon.bin"
          cp "$src" "$out"
          profile='animated-copy'
        fi
      else
        out="$canon_dir/canon.png"
        if command -v magick >/dev/null 2>&1; then
          magick "$src" -auto-orient "PNG:$out" >/dev/null 2>&1 || cp "$src" "$out"
          profile='image-png'
        elif command -v convert >/dev/null 2>&1; then
          convert "$src" "$out" >/dev/null 2>&1 || cp "$src" "$out"
          profile='image-png'
        else
          cp "$src" "$out"
          profile='image-copy'
        fi
      fi
      ;;
    video)
      out="$canon_dir/canon.mkv"
      if command -v ffmpeg >/dev/null 2>&1; then
        if ffmpeg -v error -i "$src" -map 0 -c:v ffv1 -level 3 -c:a flac -c:s copy "$out" -y >/dev/null 2>&1; then
          profile='video-ffv1-mkv'
        else
          cp "$src" "$out"
          profile='video-copy'
        fi
      else
        cp "$src" "$out"
        profile='video-copy'
      fi
      ;;
    audio)
      out="$canon_dir/canon.flac"
      if command -v ffmpeg >/dev/null 2>&1; then
        if ffmpeg -v error -i "$src" -map 0:a -c:a flac "$out" -y >/dev/null 2>&1; then
          profile='audio-flac'
        else
          cp "$src" "$out"
          profile='audio-copy'
        fi
      else
        cp "$src" "$out"
        profile='audio-copy'
      fi
      ;;
    *)
      out="$canon_dir/canon.bin"
      cp "$src" "$out"
      profile='binary-copy'
      ;;
  esac

  printf '%s\t%s\n' "$out" "$profile"
}

compute_temperature() {
  votes_file=$1
  now=$(now_epoch)
  score=$(awk -v now="$now" '
    BEGIN { s=0 }
    {
      if (NF < 2) next
      ts=$1+0
      v=$2
      age=(now-ts)/86400.0
      if (age < 0) age=0
      if (v == "up") {
        w=4-(age*0.4)
        if (w < 0) w=0
        s+=w
      } else if (v == "meh" || v == "down") {
        w=2-(age*0.3)
        if (w < 0) w=0
        s-=w
      }
    }
    END { printf "%.3f", s }
  ' "$votes_file" 2>/dev/null || printf '0.000')

  tier='cold'
  awk -v s="$score" 'BEGIN { if (s >= 8) exit 0; exit 1 }' && tier='hot'
  if [ "$tier" = 'cold' ]; then
    awk -v s="$score" 'BEGIN { if (s >= 3) exit 0; exit 1 }' && tier='warm'
  fi
  printf '%s\t%s\n' "$score" "$tier"
}

vote_counts_for_sha() {
  votes_file=$1
  if [ ! -f "$votes_file" ]; then
    printf '0\t0\n'
    return
  fi
  awk '
    BEGIN { up=0; down=0 }
    {
      if (NF < 2) next
      v=$2
      if (v == "up") up++
      else if (v == "down" || v == "meh") down++
    }
    END { printf "%d\t%d\n", up, down }
  ' "$votes_file"
}

update_vote_xattrs_and_meta() {
  root=$1
  sha=$2
  meta="$root/meta/$sha.meta"
  [ -f "$meta" ] || return 0

  votes_file="$root/votes/$sha.votes"
  counts=$(vote_counts_for_sha "$votes_file")
  up_count=$(printf '%s' "$counts" | awk -F'\t' '{print $1}')
  down_count=$(printf '%s' "$counts" | awk -F'\t' '{print $2}')
  case "$up_count" in ''|*[!0-9]*) up_count=0 ;; esac
  case "$down_count" in ''|*[!0-9]*) down_count=0 ;; esac

  meta_set "$meta" upvotes "$up_count"
  meta_set "$meta" downvotes "$down_count"

  raw_path=$(meta_get "$meta" raw_path)
  canon_path=$(meta_get "$meta" canon_path)
  for f in "$raw_path" "$canon_path"; do
    [ -n "$f" ] || continue
    [ -f "$f" ] || continue
    set_xattr_if_possible "$f" upvotes "$up_count"
    set_xattr_if_possible "$f" downvotes "$down_count"
  done
}

trash_path_for_meme() {
  path=$1
  [ -n "$path" ] || return 0
  [ -e "$path" ] || return 0

  if command -v trash-put >/dev/null 2>&1; then
    trash-put -- "$path" >/dev/null 2>&1 && return 0
  fi

  if command -v gio >/dev/null 2>&1; then
    gio trash "$path" >/dev/null 2>&1 && return 0
  fi

  if command -v kioclient5 >/dev/null 2>&1; then
    kioclient5 move "$path" trash:/ >/dev/null 2>&1 && return 0
  fi

  if [ "$(uname -s 2>/dev/null || printf unknown)" = "Darwin" ]; then
    trash_dir="${HOME}/.Trash"
    mkdir -p "$trash_dir"
    base=$(basename "$path")
    target="$trash_dir/$base"
    if [ -e "$target" ]; then
      n=1
      while [ -e "$trash_dir/$base.$n" ]; do
        n=$((n + 1))
      done
      target="$trash_dir/$base.$n"
    fi
    mv "$path" "$target"
    return 0
  fi

  return 1
}

recompute_temperature_for_sha() {
  root=$1
  sha=$2
  votes_file="$root/votes/$sha.votes"
  meta="$root/meta/$sha.meta"
  [ -f "$meta" ] || return 0

  if [ ! -f "$votes_file" ]; then
    meta_set "$meta" temp_score "0"
    meta_set "$meta" temperature "cold"
    return 0
  fi

  out=$(compute_temperature "$votes_file")
  score=$(printf '%s' "$out" | awk -F'\t' '{print $1}')
  tier=$(printf '%s' "$out" | awk -F'\t' '{print $2}')
  meta_set "$meta" temp_score "$score"
  meta_set "$meta" temperature "$tier"
}

random_index() {
  n=$1
  if [ "$n" -le 1 ]; then
    printf '0\n'
    return
  fi
  awk -v n="$n" 'BEGIN { srand(); print int(rand()*n) }'
}

acceptance_get() {
  root=$1
  cluster=$2
  file="$root/trades/acceptance.tsv"
  awk -F'\t' -v c="$cluster" '$1==c { print $2"\t"$3; found=1; exit } END { if (!found) print "0\t0" }' "$file"
}

acceptance_update() {
  root=$1
  cluster=$2
  accepted=$3
  file="$root/trades/acceptance.tsv"
  tmp=$(mktemp "${TMPDIR:-/tmp}/memetrader-acceptance.XXXXXX")

  cur=$(acceptance_get "$root" "$cluster")
  acc=$(printf '%s' "$cur" | awk -F'\t' '{print $1}')
  tot=$(printf '%s' "$cur" | awk -F'\t' '{print $2}')
  case "$acc" in ''|*[!0-9]*) acc=0 ;; esac
  case "$tot" in ''|*[!0-9]*) tot=0 ;; esac
  if [ "$accepted" = '1' ]; then
    acc=$((acc + 1))
  fi
  tot=$((tot + 1))

  awk -F'\t' -v c="$cluster" '$1 != c {print $0}' "$file" > "$tmp"
  printf '%s\t%s\t%s\n' "$cluster" "$acc" "$tot" >> "$tmp"
  mv "$tmp" "$file"
}

acceptance_rate_for_cluster() {
  root=$1
  cluster=$2
  row=$(acceptance_get "$root" "$cluster")
  acc=$(printf '%s' "$row" | awk -F'\t' '{print $1}')
  tot=$(printf '%s' "$row" | awk -F'\t' '{print $2}')
  case "$acc" in ''|*[!0-9]*) acc=0 ;; esac
  case "$tot" in ''|*[!0-9]*) tot=0 ;; esac
  awk -v a="$acc" -v t="$tot" 'BEGIN { if (t <= 0) { printf "0.500"; exit } printf "%.3f", a / t }'
}

curator_rep_update() {
  root=$1
  curator=$2
  accepted=$3
  file="$root/curation/curator-reputation.tsv"
  tmp=$(mktemp "${TMPDIR:-/tmp}/memetrader-curator-rep.XXXXXX")

  row=$(awk -F'\t' -v c="$curator" '$1==c { print $2"\t"$3; found=1; exit } END { if (!found) print "0\t0" }' "$file")
  acc=$(printf '%s' "$row" | awk -F'\t' '{print $1}')
  rej=$(printf '%s' "$row" | awk -F'\t' '{print $2}')
  case "$acc" in ''|*[!0-9]*) acc=0 ;; esac
  case "$rej" in ''|*[!0-9]*) rej=0 ;; esac

  if [ "$accepted" = '1' ]; then
    acc=$((acc + 1))
  else
    rej=$((rej + 1))
  fi

  awk -F'\t' -v c="$curator" '$1 != c {print $0}' "$file" > "$tmp"
  printf '%s\t%s\t%s\n' "$curator" "$acc" "$rej" >> "$tmp"
  mv "$tmp" "$file"
}

curator_rep_rate() {
  root=$1
  curator=$2
  file="$root/curation/curator-reputation.tsv"
  row=$(awk -F'\t' -v c="$curator" '$1==c { print $2"\t"$3; found=1; exit } END { if (!found) print "0\t0" }' "$file")
  acc=$(printf '%s' "$row" | awk -F'\t' '{print $1}')
  rej=$(printf '%s' "$row" | awk -F'\t' '{print $2}')
  case "$acc" in ''|*[!0-9]*) acc=0 ;; esac
  case "$rej" in ''|*[!0-9]*) rej=0 ;; esac
  awk -v a="$acc" -v r="$rej" 'BEGIN { t=a+r; if (t <= 0) { printf "0.500"; exit } printf "%.3f", a / t }'
}

payload_value() {
  payload=$1
  key=$2
  printf '%s' "$payload" | tr ',' '\n' | awk -F= -v k="$key" '$1==k { sub(/^[^=]*=/, ""); print; exit }'
}

include_by_exposure() {
  root=$1
  sha=$2
  exposure_mode=$3
  curated_set=$4

  case "$exposure_mode" in
    ''|full)
      return 0
      ;;
    curated)
      if [ -z "$curated_set" ]; then
        return 1
      fi
      set_file="$root/sets/$(safe_name "$curated_set").set"
      set_contains_sha "$set_file" "$sha"
      return $?
      ;;
    *)
      return 0
      ;;
  esac
}

inventory_rows() {
  root=$1
  buyer=$2
  exposure_mode=$3
  curated_set=$4
  out=$5

  exact=''
  perceptual=''
  blacklist=''

  if [ -n "$buyer" ]; then
    exact=$(buyer_filter_get "$root" "$buyer" exact_sha256)
    perceptual=$(buyer_filter_get "$root" "$buyer" perceptual_prefix)
    blacklist_file=$(buyer_blacklist_file "$root" "$buyer")
    if [ -f "$blacklist_file" ]; then
      blacklist=$(tr '\n' ',' < "$blacklist_file" | sed 's/,$//')
    fi
  fi

  : > "$out"
  for meta in "$root"/meta/*.meta; do
    [ -f "$meta" ] || continue
    sha=$(meta_get "$meta" sha256_canon)
    [ -n "$sha" ] || continue

    if ! include_by_exposure "$root" "$sha" "$exposure_mode" "$curated_set"; then
      continue
    fi

    phash=$(meta_get "$meta" perceptual_hash)
    if [ -n "$exact" ] && csv_has_token "$exact" "$sha"; then
      continue
    fi
    if [ -n "$perceptual" ] && csv_has_prefix "$perceptual" "$phash"; then
      continue
    fi
    if [ -n "$blacklist" ] && csv_has_token "$blacklist" "$sha"; then
      continue
    fi

    name=$(meta_get "$meta" filename)
    kind=$(meta_get "$meta" kind)
    cluster=$(meta_get "$meta" cluster)
    temp=$(meta_get "$meta" temperature)
    score=$(meta_get "$meta" temp_score)
    msig=$(meta_get "$meta" msig)
    families=$(meta_get "$meta" families)
    listing=$(meta_get "$meta" listing_type)
    price=$(meta_get "$meta" price_flat)
    ingested=$(meta_get "$meta" ingested_at)
    [ -n "$cluster" ] || cluster='00000000'
    [ -n "$temp" ] || temp='cold'
    [ -n "$score" ] || score='0'
    [ -n "$listing" ] || listing='flat'
    [ -n "$price" ] || price='1'

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$sha" "$name" "$kind" "$cluster" "$temp" "$score" "$msig" "$families" "$listing" "$price" "$ingested" >> "$out"
  done
}

list_json_from_inventory() {
  in_file=$1
  limit=$2
  tail -n "$limit" "$in_file" 2>/dev/null | awk -F'\t' '
    BEGIN { first=1; printf "[" }
    NF >= 11 {
      for (i=1; i<=11; i++) { gsub(/\\/, "\\\\", $i); gsub(/"/, "\\\"", $i) }
      if (!first) printf ","
      first=0
      printf "{\"sha\":\"%s\",\"name\":\"%s\",\"kind\":\"%s\",\"cluster\":\"%s\",\"temperature\":\"%s\",\"temp_score\":\"%s\",\"msig\":\"%s\",\"families\":\"%s\",\"listing_type\":\"%s\",\"price\":\"%s\",\"ingested_at\":\"%s\"}", $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11
    }
    END { printf "]" }
  '
}

browse_json_from_inventory() {
  in_file=$1
  limit=$2
  disclosure=$3
  shop_pubkey=$4

  tail -n "$limit" "$in_file" 2>/dev/null | awk -F'\t' -v mode="$disclosure" -v pub="$shop_pubkey" '
    BEGIN { first=1; printf "[" }
    NF >= 11 {
      sha=$1; name=$2; kind=$3; cluster=$4; temp=$5; score=$6; msig=$7; families=$8; listing=$9; price=$10; ingested=$11;
      gsub(/\\/, "\\\\", sha); gsub(/"/, "\\\"", sha)
      gsub(/\\/, "\\\\", name); gsub(/"/, "\\\"", name)
      gsub(/\\/, "\\\\", kind); gsub(/"/, "\\\"", kind)
      gsub(/\\/, "\\\\", cluster); gsub(/"/, "\\\"", cluster)
      gsub(/\\/, "\\\\", temp); gsub(/"/, "\\\"", temp)
      gsub(/\\/, "\\\\", score); gsub(/"/, "\\\"", score)
      gsub(/\\/, "\\\\", msig); gsub(/"/, "\\\"", msig)
      gsub(/\\/, "\\\\", families); gsub(/"/, "\\\"", families)
      gsub(/\\/, "\\\\", listing); gsub(/"/, "\\\"", listing)
      gsub(/\\/, "\\\\", price); gsub(/"/, "\\\"", price)
      gsub(/\\/, "\\\\", ingested); gsub(/"/, "\\\"", ingested)

      if (!first) printf ","
      first=0

      if (mode == "blind" || mode == "masked") {
        slot=substr(sha,1,4) substr(cluster,1,4)
        printf "{\"offer_id\":\"%s\",\"kind\":\"%s\",\"cluster\":\"%s\",\"temperature\":\"%s\",\"listing_type\":\"%s\",\"price_hint\":\"%s\"}", slot, kind, cluster, temp, listing, price
      } else if (mode == "sketched") {
        printf "{\"sha_short\":\"%s\",\"kind\":\"%s\",\"cluster\":\"%s\",\"temperature\":\"%s\",\"msig\":\"%s\",\"listing_type\":\"%s\",\"price\":\"%s\"}", substr(sha,1,12), kind, cluster, temp, msig, listing, price
      } else {
        printf "{\"sha\":\"%s\",\"name\":\"%s\",\"kind\":\"%s\",\"cluster\":\"%s\",\"temperature\":\"%s\",\"temp_score\":\"%s\",\"msig\":\"%s\",\"families\":\"%s\",\"listing_type\":\"%s\",\"price\":\"%s\",\"ingested_at\":\"%s\"}", sha,name,kind,cluster,temp,score,msig,families,listing,price,ingested
      }
    }
    END { printf "]" }
  '
}

clusters_json_from_inventory() {
  in_file=$1
  awk -F'\t' '
    NF >= 11 {
      c=$4
      temp=$5
      s=$6 + 0
      count[c]++
      sum[c]+=s
      if (temp == "hot") hot[c]++
      else if (temp == "warm") warm[c]++
      else cold[c]++
    }
    END {
      first=1
      printf "["
      for (c in count) {
        avg = 0
        if (count[c] > 0) avg = sum[c] / count[c]
        if (!first) printf ","
        first=0
        printf "{\"cluster\":\"%s\",\"count\":%d,\"hot\":%d,\"warm\":%d,\"cold\":%d,\"avg_score\":%.3f}", c, count[c], hot[c]+0, warm[c]+0, cold[c]+0, avg
      }
      printf "]"
    }
  ' "$in_file"
}

sort_next_pick() {
  root=$1
  inventory=$2
  tmp=$(mktemp "${TMPDIR:-/tmp}/memetrader-sort.XXXXXX")
  now=$(now_epoch)

  while IFS="$(printf '\t')" read -r sha name kind cluster temp score msig families listing price ingested; do
    [ -n "$sha" ] || continue
    meta="$root/meta/$sha.meta"
    last_seen=$(meta_get "$meta" sort_last_seen_epoch)
    seen_count=$(meta_get "$meta" sort_seen_count)
    case "$last_seen" in ''|*[!0-9]*) last_seen=0 ;; esac
    case "$seen_count" in ''|*[!0-9]*) seen_count=0 ;; esac

    if [ "$last_seen" -le 0 ]; then
      age_hours=72
    else
      delta=$((now - last_seen))
      if [ "$delta" -lt 0 ]; then delta=0; fi
      age_hours=$((delta / 3600))
      if [ "$age_hours" -lt 1 ]; then age_hours=1; fi
    fi

    temp_bonus=0
    case "$temp" in
      hot) temp_bonus=2 ;;
      warm) temp_bonus=1 ;;
      *) temp_bonus=0 ;;
    esac

    rand_part=$(awk 'BEGIN { srand(); printf "%.4f", rand() }')
    entropy=$(awk -v age="$age_hours" -v seen="$seen_count" -v bonus="$temp_bonus" -v rnd="$rand_part" 'BEGIN { printf "%.6f", (age / (seen + 1.0)) + bonus + rnd }')

    printf '%s\t%s\n' "$entropy" "$sha" >> "$tmp"
  done < "$inventory"

  best=$(sort -t "$(printf '\t')" -k1,1nr "$tmp" | head -n 1)
  rm -f "$tmp"
  printf '%s\n' "$best"
}

action=${1-}
if [ -z "$action" ]; then
  emit_error "action required"
  exit 2
fi
shift

case "$action" in
  help)
    emit_ok_obj '"actions":"init,status,ingest,list,browse,detail,clusters,draw,sort-next,mark-seen,vote,trash,temperature-recompute,tag,lineage,relate,timeline,graph,msig-vocab-add,msig-vocab-list,msig-relate,msig-relations,msig-suggest,families-suggest,shop-config-get,shop-config-set,set-listing,pricing-suggest,curated-set-save,curated-set-list,set-exposure,buyer-set-filters,buyer-get-filters,buyer-blacklist-add,buyer-blacklist-remove,buyer-blacklist-list,offer-preview,trade-commit,trade-reveal,trade-settle,trade-log,trade-receipt,acceptance-likelihood,courtesy-return,propose,patch-list,patch-decision,apply-patch,curator-reputation,gossip-add,gossip-list,bulletin-add,bulletin-list,advert-publish,advert-list,invite-create,rendezvous-add,rendezvous-list,journal-tail,remote-state"'
    ;;

  init)
    root=$(ensure_root "${1-}")
    emit_ok_obj "\"root\":\"$(json_escape "$root")\""
    ;;

  status)
    root=$(ensure_root "${1-}")
    total=$(find "$root/meta" -type f -name '*.meta' 2>/dev/null | wc -l | tr -d '[:space:]')
    hot=$(grep -h '^temperature=hot$' "$root"/meta/*.meta 2>/dev/null | wc -l | tr -d '[:space:]')
    warm=$(grep -h '^temperature=warm$' "$root"/meta/*.meta 2>/dev/null | wc -l | tr -d '[:space:]')
    cold=$(grep -h '^temperature=cold$' "$root"/meta/*.meta 2>/dev/null | wc -l | tr -d '[:space:]')
    msig_vocab=$(wc -l < "$root/msig/vocabulary.txt" | tr -d '[:space:]')
    trades=$(wc -l < "$root/trades/journal.tsv" | tr -d '[:space:]')
    disclosure=$(config_get "$root/shops/shop.conf" disclosure_mode catalogue)
    exposure=$(config_get "$root/shops/shop.conf" exposure_mode full)
    emit_ok_obj "\"root\":\"$(json_escape "$root")\",\"total\":$total,\"hot\":$hot,\"warm\":$warm,\"cold\":$cold,\"msig_vocab\":$msig_vocab,\"trades\":$trades,\"disclosure\":\"$disclosure\",\"exposure\":\"$exposure\""
    ;;

  ingest)
    root=$(ensure_root "${1-}")
    src=${2-}
    msig_in=${3-}
    families_in=${4-}
    listing_in=${5-}
    price_in=${6-}
    curator_in=${7-local}

    if [ -z "$src" ]; then
      emit_error "ingest requires FILE_PATH"
      exit 2
    fi
    if [ ! -f "$src" ]; then
      emit_error "file not found: $src"
      exit 1
    fi

    base=$(basename "$src")
    safe=$(safe_name "$base")
    mime=$(mime_of "$src")
    kind=$(kind_from_mime "$mime")

    sha_raw=$(sha256_file "$src")
    raw_dst="$root/artifacts/raw/${sha_raw}--$safe"
    if [ ! -f "$raw_dst" ]; then
      cp "$src" "$raw_dst"
    fi

    tmp_canon_dir=$(mktemp -d "${TMPDIR:-/tmp}/memetrader-canon.XXXXXX")
    canon_pair=$(canonize "$src" "$kind" "$mime" "$tmp_canon_dir")
    canon_tmp=$(printf '%s' "$canon_pair" | awk -F'\t' '{print $1}')
    canon_profile=$(printf '%s' "$canon_pair" | awk -F'\t' '{print $2}')

    sha_canon=$(sha256_file "$canon_tmp")
    canon_ext=$(printf '%s' "$canon_tmp" | awk -F. '{print $NF}')
    canon_dst="$root/artifacts/canon/${sha_canon}.${canon_ext}"
    if [ ! -f "$canon_dst" ]; then
      mv "$canon_tmp" "$canon_dst"
    fi
    rm -rf "$tmp_canon_dir"

    phash=$(image_phash "$canon_dst")
    [ -n "$phash" ] || phash=$(sample_hash "$canon_dst" | cut -c1-16)
    vhash=''
    ahash=''
    if [ "$kind" = 'video' ]; then
      vhash=$(video_vhash "$canon_dst")
    fi
    if [ "$kind" = 'audio' ]; then
      ahash=$(audio_ahash "$canon_dst")
    fi

    cluster=$(printf '%s' "$phash" | cut -c1-8)
    [ -n "$cluster" ] || cluster='00000000'

    msig=$(normalize_csv_tokens "$msig_in")
    families=$(normalize_family_csv "$families_in")

    listing_default=$(config_get "$root/shops/shop.conf" listing_default flat)
    listing_type=$listing_default
    if [ -n "$listing_in" ]; then
      listing_type=$(safe_token "$listing_in")
    fi
    case "$listing_type" in
      flat|pwyw|auction) ;;
      *) listing_type='flat' ;;
    esac

    price_flat=$price_in
    if [ -z "$price_flat" ]; then
      price_flat='1'
    fi
    case "$price_flat" in
      ''|*[^0-9.]* ) price_flat='1' ;;
    esac

    meta="$root/meta/${sha_canon}.meta"
    duplicate_exact=0
    if [ -f "$meta" ]; then
      duplicate_exact=1
    fi

    ts=$(now_iso)
    meta_set "$meta" sha256_raw "$sha_raw"
    meta_set "$meta" sha256_canon "$sha_canon"
    meta_set "$meta" identity "$sha_canon"
    meta_set "$meta" mime "$mime"
    meta_set "$meta" kind "$kind"
    meta_set "$meta" filename "$base"
    meta_set "$meta" raw_path "$raw_dst"
    meta_set "$meta" canon_path "$canon_dst"
    meta_set "$meta" canon_profile "$canon_profile"
    meta_set "$meta" perceptual_hash "$phash"
    meta_set "$meta" vhash "$vhash"
    meta_set "$meta" ahash "$ahash"
    meta_set "$meta" cluster "$cluster"
    meta_set "$meta" msig "$msig"
    meta_set "$meta" families "$families"
    meta_set "$meta" lineage ""
    meta_set "$meta" relations ""
    meta_set "$meta" listing_type "$listing_type"
    meta_set "$meta" price_flat "$price_flat"
    meta_set "$meta" curator "$curator_in"
    meta_set_if_missing "$meta" sort_seen_count "0"
    meta_set_if_missing "$meta" sort_last_seen_epoch "0"
    meta_set_if_missing "$meta" temp_score "0"
    meta_set_if_missing "$meta" temperature "cold"
    meta_set_if_missing "$meta" upvotes "0"
    meta_set_if_missing "$meta" downvotes "0"
    meta_set "$meta" ingested_at "$ts"

    if [ -n "$msig" ]; then
      printf '%s' "$msig" | tr ',' '\n' | while IFS= read -r tag; do
        [ -n "$tag" ] || continue
        append_unique_line "$root/msig/vocabulary.txt" "$tag"
      done
    fi

    set_xattr_if_possible "$raw_dst" sha256_raw "$sha_raw"
    set_xattr_if_possible "$raw_dst" sha256_canon "$sha_canon"
    set_xattr_if_possible "$raw_dst" perceptual_hash "$phash"
    set_xattr_if_possible "$raw_dst" cluster "$cluster"
    set_xattr_if_possible "$raw_dst" upvotes "0"
    set_xattr_if_possible "$raw_dst" downvotes "0"
    set_xattr_if_possible "$canon_dst" upvotes "0"
    set_xattr_if_possible "$canon_dst" downvotes "0"

    cluster_size=$(grep -h "^cluster=$cluster$" "$root"/meta/*.meta 2>/dev/null | wc -l | tr -d '[:space:]')

    append_journal "$root" "ingest" "$sha_canon"
    emit_ok_obj "\"sha256_raw\":\"$sha_raw\",\"sha256_canon\":\"$sha_canon\",\"kind\":\"$kind\",\"mime\":\"$mime\",\"cluster\":\"$cluster\",\"duplicate_exact\":$duplicate_exact,\"cluster_size\":$cluster_size"
    ;;

  detail)
    root=$(ensure_root "${1-}")
    sha=${2-}
    if [ -z "$sha" ]; then
      emit_error "detail requires SHA"
      exit 2
    fi
    meta="$root/meta/$sha.meta"
    if [ ! -f "$meta" ]; then
      emit_error "unknown meme: $sha"
      exit 1
    fi

    fields='sha256_raw sha256_canon identity mime kind filename raw_path canon_path canon_profile perceptual_hash vhash ahash cluster msig families lineage relations listing_type price_flat curator temp_score temperature upvotes downvotes ingested_at sort_seen_count sort_last_seen_epoch proposal_notes'
    out=''
    for key in $fields; do
      val=$(meta_get "$meta" "$key")
      esc=$(json_escape "$val")
      if [ -n "$out" ]; then
        out="$out,"
      fi
      out="$out\"$key\":\"$esc\""
    done
    emit_ok_obj "$out"
    ;;

  list)
    root=$(ensure_root "${1-}")
    limit=${2-200}
    buyer=${3-}
    disclosure=${4-catalogue}
    exposure_mode=${5-}
    curated_set=${6-}

    shop_conf="$root/shops/shop.conf"
    [ -n "$exposure_mode" ] || exposure_mode=$(config_get "$shop_conf" exposure_mode full)
    [ -n "$curated_set" ] || curated_set=$(config_get "$shop_conf" curated_set "")

    inv=$(mktemp "${TMPDIR:-/tmp}/memetrader-inventory.XXXXXX")
    inventory_rows "$root" "$buyer" "$exposure_mode" "$curated_set" "$inv"
    items=$(list_json_from_inventory "$inv" "$limit")
    rm -f "$inv"
    emit_ok_obj "\"items\":$items"
    ;;

  browse)
    root=$(ensure_root "${1-}")
    buyer=${2-}
    disclosure=${3-}
    exposure_mode=${4-}
    curated_set=${5-}
    limit=${6-200}

    shop_conf="$root/shops/shop.conf"
    [ -n "$disclosure" ] || disclosure=$(config_get "$shop_conf" disclosure_mode catalogue)
    [ -n "$exposure_mode" ] || exposure_mode=$(config_get "$shop_conf" exposure_mode full)
    [ -n "$curated_set" ] || curated_set=$(config_get "$shop_conf" curated_set "")
    shop_pubkey=$(config_get "$shop_conf" shop_pubkey "")

    inv=$(mktemp "${TMPDIR:-/tmp}/memetrader-browse.XXXXXX")
    inventory_rows "$root" "$buyer" "$exposure_mode" "$curated_set" "$inv"
    items=$(browse_json_from_inventory "$inv" "$limit" "$disclosure" "$shop_pubkey")
    rm -f "$inv"
    emit_ok_obj "\"disclosure\":\"$disclosure\",\"items\":$items"
    ;;

  clusters)
    root=$(ensure_root "${1-}")
    buyer=${2-}
    exposure_mode=${3-}
    curated_set=${4-}
    shop_conf="$root/shops/shop.conf"
    [ -n "$exposure_mode" ] || exposure_mode=$(config_get "$shop_conf" exposure_mode full)
    [ -n "$curated_set" ] || curated_set=$(config_get "$shop_conf" curated_set "")

    inv=$(mktemp "${TMPDIR:-/tmp}/memetrader-clusters.XXXXXX")
    inventory_rows "$root" "$buyer" "$exposure_mode" "$curated_set" "$inv"
    clusters=$(clusters_json_from_inventory "$inv")
    rm -f "$inv"
    emit_ok_obj "\"clusters\":$clusters"
    ;;

  draw)
    root=$(ensure_root "${1-}")
    temp_tilt=${2-0}
    buyer=${3-}
    exposure_mode=${4-}
    curated_set=${5-}

    shop_conf="$root/shops/shop.conf"
    [ -n "$exposure_mode" ] || exposure_mode=$(config_get "$shop_conf" exposure_mode full)
    [ -n "$curated_set" ] || curated_set=$(config_get "$shop_conf" curated_set "")
    if [ "$temp_tilt" = '' ]; then
      temp_tilt=$(config_get "$shop_conf" temperature_tilt 0)
    fi

    inv=$(mktemp "${TMPDIR:-/tmp}/memetrader-draw.XXXXXX")
    inventory_rows "$root" "$buyer" "$exposure_mode" "$curated_set" "$inv"

    total=$(wc -l < "$inv" | tr -d '[:space:]')
    if [ "${total:-0}" -le 0 ]; then
      rm -f "$inv"
      emit_error "inventory empty"
      exit 1
    fi

    uniq_clusters=$(mktemp "${TMPDIR:-/tmp}/memetrader-cluster-uniq.XXXXXX")
    cut -f4 "$inv" | sort -u > "$uniq_clusters"
    ccount=$(wc -l < "$uniq_clusters" | tr -d '[:space:]')
    cidx=$(random_index "$ccount")
    cluster=$(sed -n "$((cidx + 1))p" "$uniq_clusters")

    if [ "$temp_tilt" = '1' ]; then
      hot_cluster=$(awk -F'\t' '$5=="hot" {print $4}' "$inv" | sort | uniq -c | sort -nr | awk 'NR==1{print $2}')
      if [ -n "$hot_cluster" ]; then
        coin=$(random_index 100)
        if [ "$coin" -lt 60 ]; then
          cluster=$hot_cluster
        fi
      fi
    fi

    candidates=$(mktemp "${TMPDIR:-/tmp}/memetrader-candidates.XXXXXX")
    awk -F'\t' -v c="$cluster" '$4==c {print $0}' "$inv" > "$candidates"
    n=$(wc -l < "$candidates" | tr -d '[:space:]')
    pick=$(random_index "$n")
    row=$(sed -n "$((pick + 1))p" "$candidates")

    sha=$(printf '%s' "$row" | awk -F'\t' '{print $1}')
    temp=$(printf '%s' "$row" | awk -F'\t' '{print $5}')
    listing=$(printf '%s' "$row" | awk -F'\t' '{print $9}')
    price=$(printf '%s' "$row" | awk -F'\t' '{print $10}')

    rm -f "$inv" "$uniq_clusters" "$candidates"
    append_journal "$root" "draw" "$sha@$cluster"
    emit_ok_obj "\"sha\":\"$sha\",\"cluster\":\"$cluster\",\"temperature\":\"$temp\",\"listing_type\":\"$listing\",\"price\":\"$price\""
    ;;

  sort-next)
    root=$(ensure_root "${1-}")
    buyer=${2-}
    shop_conf="$root/shops/shop.conf"
    exposure_mode=$(config_get "$shop_conf" exposure_mode full)
    curated_set=$(config_get "$shop_conf" curated_set "")

    inv=$(mktemp "${TMPDIR:-/tmp}/memetrader-sort-next.XXXXXX")
    inventory_rows "$root" "$buyer" "$exposure_mode" "$curated_set" "$inv"

    total=$(wc -l < "$inv" | tr -d '[:space:]')
    if [ "${total:-0}" -le 0 ]; then
      rm -f "$inv"
      emit_error "inventory empty"
      exit 1
    fi

    best=$(sort_next_pick "$root" "$inv")
    score=$(printf '%s' "$best" | awk -F'\t' '{print $1}')
    sha=$(printf '%s' "$best" | awk -F'\t' '{print $2}')
    row=$(awk -F'\t' -v s="$sha" '$1==s {print; exit}' "$inv")

    meta="$root/meta/$sha.meta"
    last_seen=$(now_epoch)
    seen_count=$(meta_get "$meta" sort_seen_count)
    case "$seen_count" in ''|*[!0-9]*) seen_count=0 ;; esac
    seen_count=$((seen_count + 1))
    meta_set "$meta" sort_seen_count "$seen_count"
    meta_set "$meta" sort_last_seen_epoch "$last_seen"

    cluster=$(printf '%s' "$row" | awk -F'\t' '{print $4}')
    temp=$(printf '%s' "$row" | awk -F'\t' '{print $5}')
    msig=$(printf '%s' "$row" | awk -F'\t' '{print $7}')
    families=$(printf '%s' "$row" | awk -F'\t' '{print $8}')

    rm -f "$inv"
    append_journal "$root" "sort-next" "$sha:$score"
    emit_ok_obj "\"sha\":\"$sha\",\"cluster\":\"$cluster\",\"temperature\":\"$temp\",\"msig\":\"$(json_escape "$msig")\",\"families\":\"$(json_escape "$families")\",\"entropy\":\"$score\",\"seen_count\":$seen_count"
    ;;

  mark-seen)
    root=$(ensure_root "${1-}")
    sha=${2-}
    if [ -z "$sha" ]; then
      emit_error "mark-seen requires SHA"
      exit 2
    fi
    meta="$root/meta/$sha.meta"
    if [ ! -f "$meta" ]; then
      emit_error "unknown meme: $sha"
      exit 1
    fi
    seen_count=$(meta_get "$meta" sort_seen_count)
    case "$seen_count" in ''|*[!0-9]*) seen_count=0 ;; esac
    seen_count=$((seen_count + 1))
    meta_set "$meta" sort_seen_count "$seen_count"
    meta_set "$meta" sort_last_seen_epoch "$(now_epoch)"
    append_journal "$root" "mark-seen" "$sha"
    emit_ok_obj "\"sha\":\"$sha\",\"seen_count\":$seen_count"
    ;;

  vote)
    root=$(ensure_root "${1-}")
    sha=${2-}
    vote_type=${3-up}
    if [ -z "$sha" ]; then
      emit_error "vote requires SHA"
      exit 2
    fi
    case "$vote_type" in
      up|meh|down) ;;
      *) emit_error "vote must be up, down, or meh"; exit 2 ;;
    esac
    if [ "$vote_type" = 'meh' ]; then
      vote_type='down'
    fi

    meta="$root/meta/$sha.meta"
    if [ ! -f "$meta" ]; then
      emit_error "unknown meme: $sha"
      exit 1
    fi

    votes_file="$root/votes/$sha.votes"
    touch "$votes_file"

    now=$(now_epoch)
    if [ "$vote_type" = 'up' ]; then
      last_up=$(awk '$2=="up"{x=$1} END{print x+0}' "$votes_file")
      if [ "$last_up" -gt 0 ] && [ $((now - last_up)) -lt 86400 ]; then
        wait_for=$((86400 - (now - last_up)))
        emit_error "upvote cooldown active (${wait_for}s remaining)"
        exit 1
      fi
    fi

    printf '%s\t%s\n' "$now" "$vote_type" >> "$votes_file"
    recompute_temperature_for_sha "$root" "$sha"
    update_vote_xattrs_and_meta "$root" "$sha"
    score=$(meta_get "$meta" temp_score)
    tier=$(meta_get "$meta" temperature)

    append_journal "$root" "vote" "$sha:$vote_type"
    emit_ok_obj "\"sha\":\"$sha\",\"vote\":\"$vote_type\",\"temperature\":\"$tier\",\"temp_score\":$score"
    ;;

  trash)
    root=$(ensure_root "${1-}")
    sha=${2-}
    if [ -z "$sha" ]; then
      emit_error "trash requires SHA"
      exit 2
    fi
    meta="$root/meta/$sha.meta"
    if [ ! -f "$meta" ]; then
      emit_error "unknown meme: $sha"
      exit 1
    fi

    raw_path=$(meta_get "$meta" raw_path)
    canon_path=$(meta_get "$meta" canon_path)
    votes_file="$root/votes/$sha.votes"

    moved=0
    for p in "$raw_path" "$canon_path" "$votes_file" "$meta"; do
      [ -n "$p" ] || continue
      if [ -e "$p" ]; then
        if ! trash_path_for_meme "$p"; then
          emit_error "failed to move to trash: $p"
          exit 1
        fi
        moved=$((moved + 1))
      fi
    done

    append_journal "$root" "trash" "$sha:$moved"
    emit_ok_obj "\"sha\":\"$sha\",\"trashed\":$moved"
    ;;

  temperature-recompute)
    root=$(ensure_root "${1-}")
    sha=${2-}
    if [ -n "$sha" ]; then
      recompute_temperature_for_sha "$root" "$sha"
      meta="$root/meta/$sha.meta"
      score=$(meta_get "$meta" temp_score)
      tier=$(meta_get "$meta" temperature)
      emit_ok_obj "\"sha\":\"$sha\",\"temperature\":\"$tier\",\"temp_score\":\"$score\""
    else
      count=0
      for m in "$root"/meta/*.meta; do
        [ -f "$m" ] || continue
        s=$(meta_get "$m" sha256_canon)
        [ -n "$s" ] || continue
        recompute_temperature_for_sha "$root" "$s"
        count=$((count + 1))
      done
      emit_ok_obj "\"recomputed\":$count"
    fi
    ;;

  tag)
    root=$(ensure_root "${1-}")
    sha=${2-}
    msig_in=${3-}
    families_in=${4-}
    if [ -z "$sha" ]; then
      emit_error "tag requires SHA"
      exit 2
    fi
    meta="$root/meta/$sha.meta"
    if [ ! -f "$meta" ]; then
      emit_error "unknown meme: $sha"
      exit 1
    fi

    msig=$(normalize_csv_tokens "$msig_in")
    families=$(normalize_family_csv "$families_in")
    meta_set "$meta" msig "$msig"
    meta_set "$meta" families "$families"

    if [ -n "$msig" ]; then
      printf '%s' "$msig" | tr ',' '\n' | while IFS= read -r tag; do
        [ -n "$tag" ] || continue
        append_unique_line "$root/msig/vocabulary.txt" "$tag"
      done
    fi

    append_journal "$root" "tag" "$sha"
    emit_ok_obj "\"sha\":\"$sha\",\"msig\":\"$msig\",\"families\":\"$families\""
    ;;

  lineage)
    root=$(ensure_root "${1-}")
    sha=${2-}
    precursor=${3-}
    source=${4-curator}

    if [ -z "$sha" ] || [ -z "$precursor" ]; then
      emit_error "lineage requires SHA and PRECURSOR"
      exit 2
    fi
    meta="$root/meta/$sha.meta"
    if [ ! -f "$meta" ]; then
      emit_error "unknown meme: $sha"
      exit 1
    fi

    meta_set "$meta" lineage "$precursor"
    printf '%s\t%s\t%s\t%s\n' "$(now_iso)" "$precursor" "$sha" "$source" >> "$root/graphs/lineage.tsv"
    append_journal "$root" "lineage" "$precursor->$sha"
    emit_ok_obj "\"sha\":\"$sha\",\"precursor\":\"$precursor\",\"source\":\"$source\""
    ;;

  relate)
    root=$(ensure_root "${1-}")
    sha=${2-}
    rel=${3-}
    target=${4-}
    source=${5-auto}
    score=${6-0.0}

    if [ -z "$sha" ] || [ -z "$rel" ] || [ -z "$target" ]; then
      emit_error "relate requires SHA REL TARGET"
      exit 2
    fi
    case "$rel" in
      related|contrast|often-combined|visually-similar) ;;
      *) emit_error "unsupported relation: $rel"; exit 2 ;;
    esac

    meta="$root/meta/$sha.meta"
    if [ ! -f "$meta" ]; then
      emit_error "unknown meme: $sha"
      exit 1
    fi

    existing=$(meta_get "$meta" relations)
    next="$existing"
    [ -z "$next" ] || next="$next;"
    next="${next}${rel}:${target}"
    meta_set "$meta" relations "$next"

    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$(now_iso)" "$sha" "$rel" "$target" "$source" "$score" >> "$root/graphs/relations.tsv"
    append_journal "$root" "relation" "$sha $rel $target"
    emit_ok_obj "\"sha\":\"$sha\",\"relation\":\"$rel\",\"target\":\"$target\",\"source\":\"$source\""
    ;;

  timeline)
    root=$(ensure_root "${1-}")
    limit=${2-200}
    edges=$(tail -n "$limit" "$root/graphs/lineage.tsv" 2>/dev/null | awk -F'\t' '
      BEGIN { first=1; printf "[" }
      NF >= 4 {
        t=$1; p=$2; c=$3; s=$4
        gsub(/\\/, "\\\\", t); gsub(/"/, "\\\"", t)
        gsub(/\\/, "\\\\", p); gsub(/"/, "\\\"", p)
        gsub(/\\/, "\\\\", c); gsub(/"/, "\\\"", c)
        gsub(/\\/, "\\\\", s); gsub(/"/, "\\\"", s)
        if (!first) printf ","
        first=0
        printf "{\"ts\":\"%s\",\"precursor\":\"%s\",\"child\":\"%s\",\"source\":\"%s\"}", t,p,c,s
      }
      END { printf "]" }
    ')
    emit_ok_obj "\"edges\":$edges"
    ;;

  graph)
    root=$(ensure_root "${1-}")
    limit=${2-400}
    edges=$(tail -n "$limit" "$root/graphs/relations.tsv" 2>/dev/null | awk -F'\t' '
      BEGIN { first=1; printf "[" }
      NF >= 6 {
        t=$1; a=$2; r=$3; b=$4; s=$5; sc=$6
        for (i=1;i<=6;i++) { gsub(/\\/, "\\\\", $i); gsub(/"/, "\\\"", $i) }
        if (!first) printf ","
        first=0
        printf "{\"ts\":\"%s\",\"from\":\"%s\",\"relation\":\"%s\",\"to\":\"%s\",\"source\":\"%s\",\"score\":\"%s\"}", $1,$2,$3,$4,$5,$6
      }
      END { printf "]" }
    ')
    msig_rel=$(tail -n "$limit" "$root/msig/relations.tsv" 2>/dev/null | awk -F'\t' '
      BEGIN { first=1; printf "[" }
      NF >= 3 {
        for (i=1;i<=3;i++) { gsub(/\\/, "\\\\", $i); gsub(/"/, "\\\"", $i) }
        if (!first) printf ","
        first=0
        printf "{\"left\":\"%s\",\"relation\":\"%s\",\"right\":\"%s\"}", $1,$2,$3
      }
      END { printf "]" }
    ')
    emit_ok_obj "\"edges\":$edges,\"msig_relations\":$msig_rel"
    ;;

  msig-vocab-add)
    root=$(ensure_root "${1-}")
    tags=$(normalize_csv_tokens "${2-}")
    added=0
    if [ -n "$tags" ]; then
      printf '%s' "$tags" | tr ',' '\n' | while IFS= read -r tag; do
        [ -n "$tag" ] || continue
        append_unique_line "$root/msig/vocabulary.txt" "$tag"
      done
      added=$(printf '%s' "$tags" | tr ',' '\n' | grep -c . || true)
    fi
    append_journal "$root" "msig-vocab-add" "$tags"
    emit_ok_obj "\"added\":$added,\"tags\":\"$tags\""
    ;;

  msig-vocab-list)
    root=$(ensure_root "${1-}")
    items=$(awk '
      BEGIN { first=1; printf "[" }
      {
        t=$0
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", t)
        if (t == "") next
        gsub(/\\/, "\\\\", t)
        gsub(/"/, "\\\"", t)
        if (!first) printf ","
        first=0
        printf "\"%s\"", t
      }
      END { printf "]" }
    ' "$root/msig/vocabulary.txt")
    emit_ok_obj "\"tags\":$items"
    ;;

  msig-relate)
    root=$(ensure_root "${1-}")
    left=$(safe_token "${2-}")
    rel=${3-}
    right=$(safe_token "${4-}")
    case "$rel" in
      related|contrast|often-combined) ;;
      *) emit_error "msig-relate relation must be related|contrast|often-combined"; exit 2 ;;
    esac
    if [ -z "$left" ] || [ -z "$right" ]; then
      emit_error "msig-relate requires LEFT and RIGHT"
      exit 2
    fi
    append_unique_line "$root/msig/relations.tsv" "$left\t$rel\t$right"
    append_journal "$root" "msig-relate" "$left $rel $right"
    emit_ok_obj "\"left\":\"$left\",\"relation\":\"$rel\",\"right\":\"$right\""
    ;;

  msig-relations)
    root=$(ensure_root "${1-}")
    items=$(awk -F'\t' '
      BEGIN { first=1; printf "[" }
      NF >= 3 {
        for (i=1;i<=3;i++) { gsub(/\\/, "\\\\", $i); gsub(/"/, "\\\"", $i) }
        if (!first) printf ","
        first=0
        printf "{\"left\":\"%s\",\"relation\":\"%s\",\"right\":\"%s\"}", $1,$2,$3
      }
      END { printf "]" }
    ' "$root/msig/relations.tsv")
    emit_ok_obj "\"relations\":$items"
    ;;

  msig-suggest)
    root=$(ensure_root "${1-}")
    target=${2-}
    if [ -z "$target" ]; then
      emit_error "msig-suggest requires SHA_OR_PATH"
      exit 2
    fi

    probe_name=''
    cluster=''
    if [ -f "$target" ]; then
      probe_name=$(basename "$target")
    else
      meta="$root/meta/$target.meta"
      if [ -f "$meta" ]; then
        probe_name=$(meta_get "$meta" filename)
        cluster=$(meta_get "$meta" cluster)
      fi
    fi

    filename_tags=$(printf '%s' "$probe_name" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '\n' | awk 'length($0)>=3 { if (!seen[$0]++) out[++n]=$0 } END { for (i=1;i<=n;i++) { if (i>1) printf ","; printf "%s", out[i] } }')

    cluster_tags=''
    if [ -n "$cluster" ]; then
      cluster_tags=$(grep -h "^cluster=$cluster$" "$root"/meta/*.meta 2>/dev/null | wc -l | tr -d '[:space:]')
      cluster_tags=$(for m in "$root"/meta/*.meta; do
        [ -f "$m" ] || continue
        c=$(meta_get "$m" cluster)
        [ "$c" = "$cluster" ] || continue
        t=$(meta_get "$m" msig)
        [ -n "$t" ] || continue
        printf '%s\n' "$t"
      done | tr ',' '\n' | awk 'length($0)>=2 {count[$0]++} END { n=0; for (k in count) { n++; key[n]=k; val[n]=count[k] } for (i=1;i<=n;i++) for (j=i+1;j<=n;j++) if (val[j] > val[i]) { tv=val[i]; val[i]=val[j]; val[j]=tv; tk=key[i]; key[i]=key[j]; key[j]=tk } out=0; for (i=1;i<=n && i<=8;i++) { if (out>0) printf ","; printf "%s", key[i]; out++ } }')
    fi

    vocab_hits=$(printf '%s,%s' "$filename_tags" "$cluster_tags" | tr ',' '\n' | awk 'length($0)>=2 { if (!seen[$0]++) print $0 }' | awk 'BEGIN { first=1; while ((getline t < ARGV[1]) > 0) { if (t == "") continue; allowed[t]=1 } close(ARGV[1]); printf "" } { if (allowed[$0]) { if (!first) printf ","; first=0; printf "%s", $0 } }' "$root/msig/vocabulary.txt")

    suggestions=$(normalize_csv_tokens "$filename_tags,$cluster_tags,$vocab_hits")
    emit_ok_obj "\"suggestions\":\"$suggestions\",\"filename_tags\":\"$filename_tags\",\"cluster_tags\":\"$cluster_tags\""
    ;;

  families-suggest)
    root=$(ensure_root "${1-}")
    sha=${2-}
    if [ -z "$sha" ]; then
      emit_error "families-suggest requires SHA"
      exit 2
    fi
    meta="$root/meta/$sha.meta"
    if [ ! -f "$meta" ]; then
      emit_error "unknown meme: $sha"
      exit 1
    fi

    tags=$(meta_get "$meta" msig)
    suggestions=$(for m in "$root"/meta/*.meta; do
      [ -f "$m" ] || continue
      fam=$(meta_get "$m" families)
      mtags=$(meta_get "$m" msig)
      [ -n "$fam" ] || continue
      printf '%s\t%s\n' "$mtags" "$fam"
    done | awk -F'\t' -v tags="$tags" '
      BEGIN {
        n=split(tags, q, ",")
        for (i=1;i<=n;i++) if (q[i] != "") wanted[q[i]]=1
      }
      {
        split($1, t, ",")
        hit=0
        for (i in t) if (wanted[t[i]]) { hit=1; break }
        if (!hit) next
        split($2, f, ",")
        for (j in f) if (f[j] != "") count[f[j]]++
      }
      END {
        n=0
        for (k in count) {
          n++; key[n]=k; val[n]=count[k]
        }
        for (i=1;i<=n;i++) for (j=i+1;j<=n;j++) if (val[j] > val[i]) { tv=val[i]; val[i]=val[j]; val[j]=tv; tk=key[i]; key[i]=key[j]; key[j]=tk }
        out=0
        for (i=1;i<=n && i<=8;i++) {
          if (out>0) printf ","
          printf "%s", key[i]
          out++
        }
      }
    ')
    emit_ok_obj "\"sha\":\"$sha\",\"suggestions\":\"$suggestions\""
    ;;

  shop-config-get)
    root=$(ensure_root "${1-}")
    conf="$root/shops/shop.conf"
    out=''
    for k in shop_name shop_pubkey listing_default disclosure_mode exposure_mode curated_set temperature_tilt adaptive_pricing reputation_multiplier ui_theme ui_tab; do
      v=$(config_get "$conf" "$k" "")
      if [ "$k" = 'disclosure_mode' ] && [ "$v" = 'blind' ]; then
        v='masked'
      fi
      [ -z "$out" ] || out="$out,"
      out="$out\"$k\":\"$(json_escape "$v")\""
    done
    emit_ok_obj "$out"
    ;;

  shop-config-set)
    root=$(ensure_root "${1-}")
    key=${2-}
    value=${3-}
    if [ -z "$key" ]; then
      emit_error "shop-config-set requires KEY VALUE"
      exit 2
    fi
    conf="$root/shops/shop.conf"
    case "$key" in
      listing_default)
        case "$value" in flat|pwyw|auction) ;; *) emit_error "listing_default must be flat|pwyw|auction"; exit 2 ;; esac
        ;;
      disclosure_mode)
        case "$value" in blind) value='masked' ;; masked|sketched|catalogue) ;; *) emit_error "disclosure_mode must be masked|sketched|catalogue"; exit 2 ;; esac
        ;;
      exposure_mode)
        case "$value" in full|curated) ;; *) emit_error "exposure_mode must be full|curated"; exit 2 ;; esac
        ;;
      temperature_tilt|adaptive_pricing|reputation_multiplier)
        case "$value" in 0|1) ;; *) emit_error "$key must be 0 or 1"; exit 2 ;; esac
        ;;
      shop_name|shop_pubkey|curated_set)
        ;;
      ui_theme)
        case "$value" in ''|*[!a-zA-Z0-9_-]* ) emit_error "ui_theme must be alnum, dash, or underscore"; exit 2 ;; esac
        ;;
      ui_tab)
        case "$value" in sorting|browse|trading|myshop) ;; *) emit_error "ui_tab must be sorting|browse|trading|myshop"; exit 2 ;; esac
        ;;
      *) emit_error "unsupported config key: $key"; exit 2 ;;
    esac

    config_set "$conf" "$key" "$value"
    append_journal "$root" "shop-config-set" "$key=$value"
    emit_ok_obj "\"key\":\"$key\",\"value\":\"$(json_escape "$value")\""
    ;;

  set-listing)
    root=$(ensure_root "${1-}")
    sha=${2-}
    listing=${3-}
    price=${4-}
    if [ -z "$sha" ] || [ -z "$listing" ]; then
      emit_error "set-listing requires SHA LISTING_TYPE [PRICE]"
      exit 2
    fi
    case "$listing" in flat|pwyw|auction) ;; *) emit_error "listing type must be flat|pwyw|auction"; exit 2 ;; esac
    meta="$root/meta/$sha.meta"
    if [ ! -f "$meta" ]; then
      emit_error "unknown meme: $sha"
      exit 1
    fi
    meta_set "$meta" listing_type "$listing"
    if [ -n "$price" ]; then
      case "$price" in ''|*[^0-9.]* ) price='1' ;; esac
      meta_set "$meta" price_flat "$price"
    fi
    append_journal "$root" "set-listing" "$sha $listing"
    emit_ok_obj "\"sha\":\"$sha\",\"listing_type\":\"$listing\",\"price\":\"$(meta_get "$meta" price_flat)\""
    ;;

  pricing-suggest)
    root=$(ensure_root "${1-}")
    sha=${2-}
    buyer=${3-}
    if [ -z "$sha" ]; then
      emit_error "pricing-suggest requires SHA"
      exit 2
    fi
    meta="$root/meta/$sha.meta"
    if [ ! -f "$meta" ]; then
      emit_error "unknown meme: $sha"
      exit 1
    fi

    base=$(meta_get "$meta" price_flat)
    [ -n "$base" ] || base='1'
    case "$base" in ''|*[^0-9.]* ) base='1' ;; esac
    cluster=$(meta_get "$meta" cluster)
    curator=$(meta_get "$meta" curator)

    adaptive=$(config_get "$root/shops/shop.conf" adaptive_pricing 0)
    rep_mult=$(config_get "$root/shops/shop.conf" reputation_multiplier 0)

    factor='1.000'
    acc_rate=$(acceptance_rate_for_cluster "$root" "$cluster")
    if [ "$adaptive" = '1' ]; then
      factor=$(awk -v r="$acc_rate" 'BEGIN { f=0.8 + (r * 0.4); printf "%.3f", f }')
    fi

    rep_rate='0.500'
    if [ "$rep_mult" = '1' ]; then
      rep_rate=$(curator_rep_rate "$root" "$curator")
      factor=$(awk -v f="$factor" -v rr="$rep_rate" 'BEGIN { m=1 + ((rr - 0.5) * 0.4); printf "%.3f", f * m }')
    fi

    suggested=$(awk -v b="$base" -v f="$factor" 'BEGIN { s=b*f; if (s < 0.1) s=0.1; printf "%.2f", s }')
    emit_ok_obj "\"sha\":\"$sha\",\"base_price\":\"$base\",\"cluster\":\"$cluster\",\"acceptance_rate\":\"$acc_rate\",\"curator_rep_rate\":\"$rep_rate\",\"factor\":\"$factor\",\"suggested_price\":\"$suggested\""
    ;;

  curated-set-save)
    root=$(ensure_root "${1-}")
    set_name=$(safe_name "${2-}")
    sha_csv=$(normalize_csv_tokens "${3-}")
    if [ -z "$set_name" ]; then
      emit_error "curated-set-save requires SET_NAME"
      exit 2
    fi
    set_file="$root/sets/${set_name}.set"
    : > "$set_file"
    if [ -n "$sha_csv" ]; then
      printf '%s' "$sha_csv" | tr ',' '\n' | while IFS= read -r sha; do
        [ -n "$sha" ] || continue
        printf '%s\n' "$sha" >> "$set_file"
      done
    fi
    count=$(wc -l < "$set_file" | tr -d '[:space:]')
    append_journal "$root" "curated-set-save" "$set_name:$count"
    emit_ok_obj "\"set_name\":\"$set_name\",\"count\":$count"
    ;;

  curated-set-list)
    root=$(ensure_root "${1-}")
    items=$(find "$root/sets" -type f -name '*.set' 2>/dev/null | sort | awk '
      BEGIN { first=1; printf "[" }
      {
        file=$0
        name=file
        sub(/^.*\//, "", name)
        sub(/\.set$/, "", name)
        cmd = "wc -l < \"" file "\""
        cmd | getline cnt
        close(cmd)
        gsub(/[[:space:]]/, "", cnt)
        if (!first) printf ","
        first=0
        printf "{\"set_name\":\"%s\",\"count\":%s}", name, (cnt==""?0:cnt)
      }
      END { printf "]" }
    ')
    emit_ok_obj "\"sets\":$items"
    ;;

  set-exposure)
    root=$(ensure_root "${1-}")
    mode=${2-}
    set_name=$(safe_name "${3-}")
    case "$mode" in
      full)
        config_set "$root/shops/shop.conf" exposure_mode full
        config_set "$root/shops/shop.conf" curated_set ""
        ;;
      curated)
        if [ -z "$set_name" ]; then
          emit_error "set-exposure curated requires SET_NAME"
          exit 2
        fi
        config_set "$root/shops/shop.conf" exposure_mode curated
        config_set "$root/shops/shop.conf" curated_set "$set_name"
        ;;
      *)
        emit_error "set-exposure mode must be full|curated"
        exit 2
        ;;
    esac
    append_journal "$root" "set-exposure" "$mode:$set_name"
    emit_ok_obj "\"exposure_mode\":\"$mode\",\"curated_set\":\"$set_name\""
    ;;

  buyer-set-filters)
    root=$(ensure_root "${1-}")
    buyer=${2-}
    exact=$(normalize_csv_tokens "${3-}")
    perceptual=$(normalize_csv_tokens "${4-}")
    if [ -z "$buyer" ]; then
      emit_error "buyer-set-filters requires BUYER_ID"
      exit 2
    fi
    buyer_filter_set "$root" "$buyer" exact_sha256 "$exact"
    buyer_filter_set "$root" "$buyer" perceptual_prefix "$perceptual"
    append_journal "$root" "buyer-set-filters" "$buyer"
    emit_ok_obj "\"buyer\":\"$(json_escape "$buyer")\",\"exact_sha256\":\"$exact\",\"perceptual_prefix\":\"$perceptual\""
    ;;

  buyer-get-filters)
    root=$(ensure_root "${1-}")
    buyer=${2-}
    if [ -z "$buyer" ]; then
      emit_error "buyer-get-filters requires BUYER_ID"
      exit 2
    fi
    exact=$(buyer_filter_get "$root" "$buyer" exact_sha256)
    perceptual=$(buyer_filter_get "$root" "$buyer" perceptual_prefix)
    emit_ok_obj "\"buyer\":\"$(json_escape "$buyer")\",\"exact_sha256\":\"$exact\",\"perceptual_prefix\":\"$perceptual\""
    ;;

  buyer-blacklist-add)
    root=$(ensure_root "${1-}")
    buyer=${2-}
    sha=${3-}
    if [ -z "$buyer" ] || [ -z "$sha" ]; then
      emit_error "buyer-blacklist-add requires BUYER_ID SHA"
      exit 2
    fi
    file=$(buyer_blacklist_file "$root" "$buyer")
    append_unique_line "$file" "$sha"
    append_journal "$root" "buyer-blacklist-add" "$buyer:$sha"
    emit_ok_obj "\"buyer\":\"$(json_escape "$buyer")\",\"sha\":\"$sha\""
    ;;

  buyer-blacklist-remove)
    root=$(ensure_root "${1-}")
    buyer=${2-}
    sha=${3-}
    if [ -z "$buyer" ] || [ -z "$sha" ]; then
      emit_error "buyer-blacklist-remove requires BUYER_ID SHA"
      exit 2
    fi
    file=$(buyer_blacklist_file "$root" "$buyer")
    tmp=$(mktemp "${TMPDIR:-/tmp}/memetrader-blacklist.XXXXXX")
    touch "$file"
    awk -v s="$sha" '$0 != s {print $0}' "$file" > "$tmp"
    mv "$tmp" "$file"
    append_journal "$root" "buyer-blacklist-remove" "$buyer:$sha"
    emit_ok_obj "\"buyer\":\"$(json_escape "$buyer")\",\"sha\":\"$sha\""
    ;;

  buyer-blacklist-list)
    root=$(ensure_root "${1-}")
    buyer=${2-}
    if [ -z "$buyer" ]; then
      emit_error "buyer-blacklist-list requires BUYER_ID"
      exit 2
    fi
    file=$(buyer_blacklist_file "$root" "$buyer")
    touch "$file"
    list=$(awk '
      BEGIN { first=1; printf "[" }
      {
        t=$0
        if (t == "") next
        gsub(/\\/, "\\\\", t)
        gsub(/"/, "\\\"", t)
        if (!first) printf ","
        first=0
        printf "\"%s\"", t
      }
      END { printf "]" }
    ' "$file")
    emit_ok_obj "\"buyer\":\"$(json_escape "$buyer")\",\"items\":$list"
    ;;

  offer-preview)
    root=$(ensure_root "${1-}")
    sha=${2-}
    disclosure=${3-}
    buyer=${4-}

    if [ -z "$sha" ]; then
      emit_error "offer-preview requires SHA"
      exit 2
    fi
    meta="$root/meta/$sha.meta"
    if [ ! -f "$meta" ]; then
      emit_error "unknown meme: $sha"
      exit 1
    fi
    [ -n "$disclosure" ] || disclosure=$(config_get "$root/shops/shop.conf" disclosure_mode catalogue)

    kind=$(meta_get "$meta" kind)
    cluster=$(meta_get "$meta" cluster)
    temp=$(meta_get "$meta" temperature)
    name=$(meta_get "$meta" filename)
    msig=$(meta_get "$meta" msig)
    families=$(meta_get "$meta" families)
    listing=$(meta_get "$meta" listing_type)
    price=$(meta_get "$meta" price_flat)

    case "$disclosure" in
      blind|masked)
        disclosure='masked'
        payload="\"offer_id\":\"$(printf '%s' "$sha" | cut -c1-4)$(printf '%s' "$cluster" | cut -c1-4)\",\"kind\":\"$kind\",\"cluster\":\"$cluster\",\"temperature\":\"$temp\",\"listing_type\":\"$listing\",\"price_hint\":\"$price\""
        ;;
      sketched)
        payload="\"sha_short\":\"$(printf '%s' "$sha" | cut -c1-12)\",\"kind\":\"$kind\",\"cluster\":\"$cluster\",\"temperature\":\"$temp\",\"msig\":\"$(json_escape "$msig")\",\"listing_type\":\"$listing\",\"price\":\"$price\""
        ;;
      *)
        payload="\"sha\":\"$sha\",\"name\":\"$(json_escape "$name")\",\"kind\":\"$kind\",\"cluster\":\"$cluster\",\"temperature\":\"$temp\",\"msig\":\"$(json_escape "$msig")\",\"families\":\"$(json_escape "$families")\",\"listing_type\":\"$listing\",\"price\":\"$price\""
        ;;
    esac

    emit_ok_obj "\"disclosure\":\"$disclosure\",$payload"
    ;;

  trade-commit)
    root=$(ensure_root "${1-}")
    mode=${2-masked}
    seller=${3-seller}
    buyer=${4-buyer}
    payload=${5-}
    disclosure=${6-}

    case "$mode" in
      blind) mode='masked' ;;
      masked|single-commit|cluster-commit) ;;
      *) emit_error "trade-commit mode must be masked|single-commit|cluster-commit"; exit 2 ;;
    esac

    if [ -z "$payload" ]; then
      emit_error "trade-commit requires PAYLOAD"
      exit 2
    fi

    [ -n "$disclosure" ] || disclosure=$(config_get "$root/shops/shop.conf" disclosure_mode catalogue)

    trade_id="trade-$(random_hex | cut -c1-20)"
    nonce=$(random_hex)
    commit_hash=$(sha256_text "${payload}|${nonce}")
    ts=$(now_iso)
    trade_file="$root/trades/commits/${trade_id}.trade"

    {
      printf 'trade_id=%s\n' "$trade_id"
      printf 'mode=%s\n' "$mode"
      printf 'seller=%s\n' "$seller"
      printf 'buyer=%s\n' "$buyer"
      printf 'payload=%s\n' "$payload"
      printf 'nonce=%s\n' "$nonce"
      printf 'commit_hash=%s\n' "$commit_hash"
      printf 'disclosure=%s\n' "$disclosure"
      printf 'status=committed\n'
      printf 'created_at=%s\n' "$ts"
    } > "$trade_file"

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$ts" "$trade_id" "commit" "$mode" "$seller" "$buyer" "$commit_hash" >> "$root/trades/journal.tsv"
    append_journal "$root" "trade-commit" "$trade_id"

    emit_ok_obj "\"trade_id\":\"$trade_id\",\"mode\":\"$mode\",\"commit_hash\":\"$commit_hash\",\"created_at\":\"$ts\""
    ;;

  trade-reveal)
    root=$(ensure_root "${1-}")
    trade_id=${2-}
    payload=${3-}
    if [ -z "$trade_id" ] || [ -z "$payload" ]; then
      emit_error "trade-reveal requires TRADE_ID PAYLOAD"
      exit 2
    fi

    trade_file="$root/trades/commits/${trade_id}.trade"
    if [ ! -f "$trade_file" ]; then
      emit_error "unknown trade: $trade_id"
      exit 1
    fi

    nonce=$(config_get "$trade_file" nonce "")
    commit_hash=$(config_get "$trade_file" commit_hash "")
    mode=$(config_get "$trade_file" mode "masked")
    seller=$(config_get "$trade_file" seller "")
    buyer=$(config_get "$trade_file" buyer "")

    calc=$(sha256_text "${payload}|${nonce}")
    if [ "$calc" != "$commit_hash" ]; then
      emit_error "reveal hash mismatch"
      exit 1
    fi

    config_set "$trade_file" revealed_payload "$payload"
    config_set "$trade_file" status revealed
    config_set "$trade_file" revealed_at "$(now_iso)"

    reveal_file="$root/trades/reveals/${trade_id}.reveal"
    {
      printf 'trade_id=%s\n' "$trade_id"
      printf 'payload=%s\n' "$payload"
      printf 'revealed_at=%s\n' "$(now_iso)"
    } > "$reveal_file"

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$(now_iso)" "$trade_id" "reveal" "$mode" "$seller" "$buyer" "$calc" >> "$root/trades/journal.tsv"
    append_journal "$root" "trade-reveal" "$trade_id"

    emit_ok_obj "\"trade_id\":\"$trade_id\",\"verified\":true,\"mode\":\"$mode\",\"payload\":\"$(json_escape "$payload")\""
    ;;

  trade-settle)
    root=$(ensure_root "${1-}")
    trade_id=${2-}
    decision=${3-}
    sign_key=${4-}
    counterparty=${5-}

    if [ -z "$trade_id" ] || [ -z "$decision" ]; then
      emit_error "trade-settle requires TRADE_ID DECISION"
      exit 2
    fi
    case "$decision" in
      accept|reject|return) ;;
      *) emit_error "trade-settle decision must be accept|reject|return"; exit 2 ;;
    esac

    trade_file="$root/trades/commits/${trade_id}.trade"
    if [ ! -f "$trade_file" ]; then
      emit_error "unknown trade: $trade_id"
      exit 1
    fi

    payload=$(config_get "$trade_file" revealed_payload "")
    if [ -z "$payload" ]; then
      payload=$(config_get "$trade_file" payload "")
    fi

    config_set "$trade_file" status "$decision"
    config_set "$trade_file" settled_at "$(now_iso)"

    cluster=$(payload_value "$payload" cluster)
    if [ -n "$cluster" ]; then
      if [ "$decision" = 'accept' ]; then
        acceptance_update "$root" "$cluster" 1
      elif [ "$decision" = 'reject' ]; then
        acceptance_update "$root" "$cluster" 0
      fi
    fi

    receipt="$root/trades/receipts/${trade_id}.receipt"
    {
      printf 'trade_id=%s\n' "$trade_id"
      printf 'decision=%s\n' "$decision"
      printf 'settled_at=%s\n' "$(now_iso)"
      printf 'counterparty=%s\n' "$counterparty"
      printf 'payload=%s\n' "$payload"
    } > "$receipt"

    signature=''
    if [ -n "$sign_key" ] && [ -f "$sign_key" ] && command -v openssl >/dev/null 2>&1; then
      sig_file="$receipt.sig"
      if openssl dgst -sha256 -sign "$sign_key" -out "$sig_file" "$receipt" >/dev/null 2>&1; then
        signature="$sig_file"
      fi
    fi

    printf '%s\t%s\t%s\t%s\n' "$(now_iso)" "$trade_id" "settle" "$decision" >> "$root/trades/journal.tsv"
    append_journal "$root" "trade-settle" "$trade_id:$decision"

    emit_ok_obj "\"trade_id\":\"$trade_id\",\"decision\":\"$decision\",\"receipt\":\"$(json_escape "$receipt")\",\"signature\":\"$(json_escape "$signature")\""
    ;;

  trade-log)
    root=$(ensure_root "${1-}")
    limit=${2-200}
    entries=$(tail -n "$limit" "$root/trades/journal.tsv" 2>/dev/null | awk -F'\t' '
      BEGIN { first=1; printf "[" }
      {
        t=$1; id=$2; kind=$3; a=$4; b=$5; c=$6; d=$7
        for (i=1;i<=7;i++) { gsub(/\\/, "\\\\", $i); gsub(/"/, "\\\"", $i) }
        if (!first) printf ","
        first=0
        printf "{\"ts\":\"%s\",\"trade_id\":\"%s\",\"event\":\"%s\",\"a\":\"%s\",\"b\":\"%s\",\"c\":\"%s\",\"d\":\"%s\"}", $1,$2,$3,$4,$5,$6,$7
      }
      END { printf "]" }
    ')
    emit_ok_obj "\"entries\":$entries"
    ;;

  trade-receipt)
    root=$(ensure_root "${1-}")
    trade_id=${2-}
    if [ -z "$trade_id" ]; then
      emit_error "trade-receipt requires TRADE_ID"
      exit 2
    fi
    receipt="$root/trades/receipts/${trade_id}.receipt"
    if [ ! -f "$receipt" ]; then
      emit_error "receipt not found for trade: $trade_id"
      exit 1
    fi
    body=$(sed ':a;N;$!ba;s/\n/\\n/g' "$receipt")
    sig=''
    if [ -f "$receipt.sig" ]; then
      sig="$receipt.sig"
    fi
    emit_ok_obj "\"trade_id\":\"$trade_id\",\"receipt\":\"$(json_escape "$body")\",\"signature\":\"$(json_escape "$sig")\""
    ;;

  acceptance-likelihood)
    root=$(ensure_root "${1-}")
    cluster=${2-}
    if [ -z "$cluster" ]; then
      emit_error "acceptance-likelihood requires CLUSTER"
      exit 2
    fi
    rate=$(acceptance_rate_for_cluster "$root" "$cluster")
    row=$(acceptance_get "$root" "$cluster")
    acc=$(printf '%s' "$row" | awk -F'\t' '{print $1}')
    tot=$(printf '%s' "$row" | awk -F'\t' '{print $2}')
    emit_ok_obj "\"cluster\":\"$cluster\",\"accepted\":$acc,\"total\":$tot,\"rate\":\"$rate\""
    ;;

  courtesy-return)
    root=$(ensure_root "${1-}")
    buyer=${2-}
    sha=${3-}
    reason=${4-courtesy-return}
    if [ -z "$buyer" ] || [ -z "$sha" ]; then
      emit_error "courtesy-return requires BUYER_ID SHA"
      exit 2
    fi
    file=$(buyer_blacklist_file "$root" "$buyer")
    append_unique_line "$file" "$sha"
    append_journal "$root" "courtesy-return" "$buyer:$sha:$reason"
    emit_ok_obj "\"buyer\":\"$(json_escape "$buyer")\",\"sha\":\"$sha\",\"reason\":\"$(json_escape "$reason")\""
    ;;

  propose)
    root=$(ensure_root "${1-}")
    sha=${2-}
    curator=${3-anon}
    payload=${4-}
    if [ -z "$sha" ]; then
      emit_error "propose requires SHA"
      exit 2
    fi
    ts=$(date -u '+%Y%m%dT%H%M%SZ')
    out="$root/patches/outbox/${sha}--$(safe_name "$curator")--${ts}.patch"
    {
      printf 'schema=memetrader-patch-v1\n'
      printf 'sha256_canon=%s\n' "$sha"
      printf 'curator=%s\n' "$curator"
      printf 'created_at=%s\n' "$ts"
      printf 'payload=%s\n' "$payload"
    } > "$out"
    append_journal "$root" "patch-propose" "$out"
    emit_ok_obj "\"patch\":\"$(json_escape "$out")\""
    ;;

  patch-list)
    root=$(ensure_root "${1-}")
    box=${2-outbox}
    limit=${3-200}
    case "$box" in outbox|inbox) ;; *) emit_error "patch-list box must be outbox|inbox"; exit 2 ;; esac
    dir="$root/patches/$box"
    items=$(find "$dir" -type f -name '*.patch' 2>/dev/null | sort | tail -n "$limit" | awk '
      BEGIN { first=1; printf "[" }
      {
        p=$0
        gsub(/\\/, "\\\\", p)
        gsub(/"/, "\\\"", p)
        if (!first) printf ","
        first=0
        printf "\"%s\"", p
      }
      END { printf "]" }
    ')
    emit_ok_obj "\"box\":\"$box\",\"items\":$items"
    ;;

  patch-decision)
    root=$(ensure_root "${1-}")
    patch=${2-}
    decision=${3-}

    if [ -z "$patch" ] || [ ! -f "$patch" ]; then
      emit_error "patch-decision requires existing PATCH_PATH"
      exit 2
    fi
    case "$decision" in accept|reject) ;; *) emit_error "patch-decision decision must be accept|reject"; exit 2 ;; esac

    sha=$(config_get "$patch" sha256_canon "")
    curator=$(config_get "$patch" curator "anon")
    payload=$(config_get "$patch" payload "")
    meta="$root/meta/$sha.meta"
    if [ ! -f "$meta" ]; then
      emit_error "target meme not found for patch: $sha"
      exit 1
    fi

    if [ "$decision" = 'accept' ]; then
      existing=$(meta_get "$meta" proposal_notes)
      next="$existing"
      [ -z "$next" ] || next="$next;"
      next="${next}${payload}"
      meta_set "$meta" proposal_notes "$next"
      cp "$patch" "$root/patches/inbox/$(basename "$patch")"
      curator_rep_update "$root" "$curator" 1
    else
      curator_rep_update "$root" "$curator" 0
    fi

    append_journal "$root" "patch-decision" "$decision:$patch"
    emit_ok_obj "\"sha\":\"$sha\",\"decision\":\"$decision\",\"curator\":\"$(json_escape "$curator")\""
    ;;

  apply-patch)
    root=$(ensure_root "${1-}")
    patch=${2-}
    if [ -z "$patch" ] || [ ! -f "$patch" ]; then
      emit_error "apply-patch requires existing PATCH_PATH"
      exit 2
    fi
    exec "$0" patch-decision "$root" "$patch" accept
    ;;

  curator-reputation)
    root=$(ensure_root "${1-}")
    curator=${2-}
    file="$root/curation/curator-reputation.tsv"
    if [ -n "$curator" ]; then
      row=$(awk -F'\t' -v c="$curator" '$1==c {print; found=1; exit} END { if (!found) print c"\t0\t0" }' "$file")
      acc=$(printf '%s' "$row" | awk -F'\t' '{print $2}')
      rej=$(printf '%s' "$row" | awk -F'\t' '{print $3}')
      rate=$(curator_rep_rate "$root" "$curator")
      emit_ok_obj "\"curator\":\"$(json_escape "$curator")\",\"accepted\":$acc,\"rejected\":$rej,\"rate\":\"$rate\""
    else
      items=$(awk -F'\t' '
        BEGIN { first=1; printf "[" }
        NF >= 3 {
          c=$1; a=$2; r=$3
          t=a+r
          rate=0.5
          if (t > 0) rate=a/t
          gsub(/\\/, "\\\\", c)
          gsub(/"/, "\\\"", c)
          if (!first) printf ","
          first=0
          printf "{\"curator\":\"%s\",\"accepted\":%d,\"rejected\":%d,\"rate\":%.3f}", c, a+0, r+0, rate
        }
        END { printf "]" }
      ' "$file")
      emit_ok_obj "\"items\":$items"
    fi
    ;;

  gossip-add)
    root=$(ensure_root "${1-}")
    pubkey=${2-}
    note=${3-}
    if [ -z "$pubkey" ]; then
      emit_error "gossip-add requires PUBKEY"
      exit 2
    fi
    printf '%s\t%s\t%s\n' "$(now_iso)" "$pubkey" "$note" >> "$root/discovery/gossip_pubkeys.tsv"
    append_journal "$root" "gossip-add" "$pubkey"
    emit_ok_obj "\"pubkey\":\"$(json_escape "$pubkey")\""
    ;;

  gossip-list)
    root=$(ensure_root "${1-}")
    limit=${2-200}
    items=$(tail -n "$limit" "$root/discovery/gossip_pubkeys.tsv" 2>/dev/null | awk -F'\t' '
      BEGIN { first=1; printf "[" }
      NF >= 2 {
        t=$1; p=$2; n=$3
        for (i=1;i<=3;i++) { gsub(/\\/, "\\\\", $i); gsub(/"/, "\\\"", $i) }
        if (!first) printf ","
        first=0
        printf "{\"ts\":\"%s\",\"pubkey\":\"%s\",\"note\":\"%s\"}", $1,$2,$3
      }
      END { printf "]" }
    ')
    emit_ok_obj "\"items\":$items"
    ;;

  bulletin-add)
    root=$(ensure_root "${1-}")
    family=$(safe_token "${2-}")
    pubkey=${3-}
    strength=${4-1.0}
    if [ -z "$family" ] || [ -z "$pubkey" ]; then
      emit_error "bulletin-add requires FAMILY PUBKEY"
      exit 2
    fi
    printf '%s\t%s\t%s\t%s\n' "$(now_iso)" "$family" "$pubkey" "$strength" >> "$root/discovery/tag_bulletins.tsv"
    append_journal "$root" "bulletin-add" "$family:$pubkey"
    emit_ok_obj "\"family\":\"$family\",\"pubkey\":\"$(json_escape "$pubkey")\""
    ;;

  bulletin-list)
    root=$(ensure_root "${1-}")
    limit=${2-200}
    items=$(tail -n "$limit" "$root/discovery/tag_bulletins.tsv" 2>/dev/null | awk -F'\t' '
      BEGIN { first=1; printf "[" }
      NF >= 4 {
        for (i=1;i<=4;i++) { gsub(/\\/, "\\\\", $i); gsub(/"/, "\\\"", $i) }
        if (!first) printf ","
        first=0
        printf "{\"ts\":\"%s\",\"family\":\"%s\",\"pubkey\":\"%s\",\"strength\":\"%s\"}", $1,$2,$3,$4
      }
      END { printf "]" }
    ')
    emit_ok_obj "\"items\":$items"
    ;;

  advert-publish)
    root=$(ensure_root "${1-}")
    families=$(normalize_family_csv "${2-}")
    listing_types=$(normalize_csv_tokens "${3-}")
    msig_hist=${4-}
    cluster_centroids=${5-}

    shop_pubkey=$(config_get "$root/shops/shop.conf" shop_pubkey "")
    if [ -z "$shop_pubkey" ]; then
      shop_pubkey="local-$(hostname 2>/dev/null || printf 'shop')"
    fi

    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$(now_iso)" "$shop_pubkey" "$families" "$listing_types" "$msig_hist" "$cluster_centroids" >> "$root/discovery/adverts.tsv"
    append_journal "$root" "advert-publish" "$shop_pubkey"
    emit_ok_obj "\"shop_pubkey\":\"$(json_escape "$shop_pubkey")\",\"families\":\"$families\",\"listing_types\":\"$listing_types\""
    ;;

  advert-list)
    root=$(ensure_root "${1-}")
    limit=${2-200}
    items=$(tail -n "$limit" "$root/discovery/adverts.tsv" 2>/dev/null | awk -F'\t' '
      BEGIN { first=1; printf "[" }
      NF >= 6 {
        for (i=1;i<=6;i++) { gsub(/\\/, "\\\\", $i); gsub(/"/, "\\\"", $i) }
        if (!first) printf ","
        first=0
        printf "{\"ts\":\"%s\",\"shop_pubkey\":\"%s\",\"families\":\"%s\",\"listing_types\":\"%s\",\"msig_hist\":\"%s\",\"cluster_centroids\":\"%s\"}", $1,$2,$3,$4,$5,$6
      }
      END { printf "]" }
    ')
    emit_ok_obj "\"items\":$items"
    ;;

  invite-create)
    root=$(ensure_root "${1-}")
    shop_pubkey=${2-}
    host=${3-localhost}
    if [ -z "$shop_pubkey" ]; then
      shop_pubkey=$(config_get "$root/shops/shop.conf" shop_pubkey "")
      if [ -z "$shop_pubkey" ]; then
        shop_pubkey="local-$(hostname 2>/dev/null || printf 'shop')"
      fi
    fi
    token=$(random_hex | cut -c1-16)
    invite="memetrader://invite?shop=$(printf '%s' "$shop_pubkey" | sed 's/ /%20/g')&token=$token&host=$host"
    printf '%s\t%s\t%s\n' "$(now_iso)" "$shop_pubkey" "$invite" >> "$root/discovery/invites.tsv"
    append_journal "$root" "invite-create" "$shop_pubkey"
    emit_ok_obj "\"invite\":\"$(json_escape "$invite")\",\"shop_pubkey\":\"$(json_escape "$shop_pubkey")\""
    ;;

  rendezvous-add)
    root=$(ensure_root "${1-}")
    node=${2-}
    if [ -z "$node" ]; then
      emit_error "rendezvous-add requires NODE"
      exit 2
    fi
    append_unique_line "$root/discovery/rendezvous.tsv" "$node"
    append_journal "$root" "rendezvous-add" "$node"
    emit_ok_obj "\"node\":\"$(json_escape "$node")\""
    ;;

  rendezvous-list)
    root=$(ensure_root "${1-}")
    items=$(awk '
      BEGIN { first=1; printf "[" }
      {
        n=$0
        if (n == "") next
        gsub(/\\/, "\\\\", n)
        gsub(/"/, "\\\"", n)
        if (!first) printf ","
        first=0
        printf "\"%s\"", n
      }
      END { printf "]" }
    ' "$root/discovery/rendezvous.tsv")
    emit_ok_obj "\"items\":$items"
    ;;

  journal-tail)
    root=$(ensure_root "${1-}")
    limit=${2-200}
    entries=$(tail -n "$limit" "$root/journals/events.log" 2>/dev/null | awk -F'\t' '
      BEGIN { first=1; printf "[" }
      {
        t=$1; k=$2; p=$3
        for (i=1;i<=3;i++) { gsub(/\\/, "\\\\", $i); gsub(/"/, "\\\"", $i) }
        if (!first) printf ","
        first=0
        printf "{\"ts\":\"%s\",\"kind\":\"%s\",\"payload\":\"%s\"}", $1,$2,$3
      }
      END { printf "]" }
    ')
    emit_ok_obj "\"entries\":$entries"
    ;;

  remote-state)
    root=$(ensure_root "${1-}")
    buyer=${2-}
    disclosure=${3-}
    [ -n "$disclosure" ] || disclosure=$(config_get "$root/shops/shop.conf" disclosure_mode catalogue)

    total=$(find "$root/meta" -type f -name '*.meta' 2>/dev/null | wc -l | tr -d '[:space:]')
    clusters_count=$(awk -F= '/^cluster=/{print $2}' "$root"/meta/*.meta 2>/dev/null | sort -u | wc -l | tr -d '[:space:]')
    adverts_count=$(wc -l < "$root/discovery/adverts.tsv" | tr -d '[:space:]')
    gossip_count=$(wc -l < "$root/discovery/gossip_pubkeys.tsv" | tr -d '[:space:]')

    inv=$(mktemp "${TMPDIR:-/tmp}/memetrader-remote-state.XXXXXX")
    exposure_mode=$(config_get "$root/shops/shop.conf" exposure_mode full)
    curated_set=$(config_get "$root/shops/shop.conf" curated_set "")
    inventory_rows "$root" "$buyer" "$exposure_mode" "$curated_set" "$inv"
    browse=$(browse_json_from_inventory "$inv" 40 "$disclosure" "")
    clusters=$(clusters_json_from_inventory "$inv")
    rm -f "$inv"

    emit_ok_obj "\"total\":$total,\"clusters_count\":$clusters_count,\"adverts_count\":$adverts_count,\"gossip_count\":$gossip_count,\"disclosure\":\"$disclosure\",\"browse\":$browse,\"clusters\":$clusters"
    ;;

  *)
    emit_error "unknown action: $action"
    exit 2
    ;;
esac
