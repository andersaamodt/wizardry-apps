#!/bin/sh

# Local-first backend for Memetrader.
# Stores files + metadata under ~/.memes by default.

set -eu

json_escape() {
  printf '%s' "$1" | awk '
    BEGIN { ORS=""; first=1 }
    {
      if (!first) { printf "\\n" }
      first=0
      gsub(/\\/, "\\\\")
      gsub(/"/, "\\\"")
      gsub(/\t/, "\\t")
      gsub(/\r/, "\\r")
      printf "%s", $0
    }
  '
}

emit_error() {
  msg=$(json_escape "$1")
  printf '{"ok":false,"error":"%s"}\n' "$msg"
}

emit_ok_obj() {
  printf '{"ok":true,%s}\n' "$1"
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

ensure_root() {
  root=${1:-${MEMETRADER_HOME:-$HOME/.memes}}
  mkdir -p "$root/artifacts/raw" "$root/artifacts/canon" "$root/meta" "$root/votes" "$root/journals" "$root/patches/outbox" "$root/patches/inbox"
  printf '%s\n' "$root"
}

safe_name() {
  base=$1
  printf '%s' "$base" | sed 's#[^a-zA-Z0-9._-]#_#g'
}

set_meta_field() {
  file=$1
  key=$2
  value=$3
  tmp=$(mktemp "${TMPDIR:-/tmp}/memetrader-meta.XXXXXX")
  touch "$file"
  awk -F= -v k="$key" '$1 != k {print $0}' "$file" > "$tmp"
  printf '%s=%s\n' "$key" "$value" >> "$tmp"
  mv "$tmp" "$file"
}

get_meta_field() {
  file=$1
  key=$2
  if [ ! -f "$file" ]; then
    return 0
  fi
  awk -F= -v k="$key" '$1 == k {sub(/^[^=]*=/, ""); print; exit}' "$file"
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
      return 0
    fi
  fi
  sample_hash "$f" | cut -c1-16
}

canonize() {
  src=$1
  kind=$2
  mime=$3
  canon_dir=$4

  canon_profile='copy-fallback'
  ext='bin'

  case "$kind" in
    image)
      ext='png'
      if command -v magick >/dev/null 2>&1; then
        out="$canon_dir/canon.png"
        magick "$src" -auto-orient "PNG:$out" >/dev/null 2>&1 || cp "$src" "$out"
        canon_profile='image-png'
      elif command -v convert >/dev/null 2>&1; then
        out="$canon_dir/canon.png"
        convert "$src" "$out" >/dev/null 2>&1 || cp "$src" "$out"
        canon_profile='image-png'
      else
        out="$canon_dir/canon.$ext"
        cp "$src" "$out"
      fi
      ;;
    video)
      ext='mkv'
      out="$canon_dir/canon.$ext"
      if command -v ffmpeg >/dev/null 2>&1; then
        ffmpeg -v error -i "$src" -map 0 -c:v ffv1 -level 3 -c:a flac -c:s copy "$out" -y >/dev/null 2>&1 || cp "$src" "$out"
        canon_profile='video-ffv1-mkv'
      else
        cp "$src" "$out"
      fi
      ;;
    audio)
      ext='flac'
      out="$canon_dir/canon.$ext"
      if command -v ffmpeg >/dev/null 2>&1; then
        ffmpeg -v error -i "$src" -map 0:a -c:a flac "$out" -y >/dev/null 2>&1 || cp "$src" "$out"
        canon_profile='audio-flac'
      else
        cp "$src" "$out"
      fi
      ;;
    *)
      ext='bin'
      out="$canon_dir/canon.$ext"
      cp "$src" "$out"
      ;;
  esac

  printf '%s\t%s\n' "$out" "$canon_profile"
}

append_journal() {
  j_root=$1
  j_kind=$2
  j_payload=$3
  log="$j_root/journals/events.log"
  ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  printf '%s\t%s\t%s\n' "$ts" "$j_kind" "$j_payload" >> "$log"
}

compute_temperature() {
  votes_file=$1
  now=$(date +%s)
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
      } else if (v == "meh") {
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

random_index() {
  n=$1
  if [ "$n" -le 1 ]; then
    printf '0\n'
    return
  fi
  awk -v n="$n" 'BEGIN { srand(); print int(rand()*n) }'
}

action=${1-}
if [ -z "$action" ]; then
  emit_error "action required"
  exit 2
fi
shift

case "$action" in
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
    emit_ok_obj "\"root\":\"$(json_escape "$root")\",\"total\":$total,\"hot\":$hot,\"warm\":$warm,\"cold\":$cold"
    ;;

  ingest)
    root=$(ensure_root "${1-}")
    src=${2-}
    msig=${3-}
    families=${4-}
    listing_type=${5-flat}
    price_flat=${6-1}

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
    canon_and_profile=$(canonize "$src" "$kind" "$mime" "$tmp_canon_dir")
    canon_tmp=$(printf '%s' "$canon_and_profile" | awk -F'\t' '{print $1}')
    canon_profile=$(printf '%s' "$canon_and_profile" | awk -F'\t' '{print $2}')

    sha_canon=$(sha256_file "$canon_tmp")
    canon_ext=$(printf '%s' "$canon_tmp" | awk -F. '{print $NF}')
    canon_dst="$root/artifacts/canon/${sha_canon}.${canon_ext}"
    if [ ! -f "$canon_dst" ]; then
      mv "$canon_tmp" "$canon_dst"
    fi
    rm -rf "$tmp_canon_dir"

    phash=$(image_phash "$canon_dst")
    vhash=''
    ahash=''
    if [ "$kind" = 'video' ]; then
      if command -v ffprobe >/dev/null 2>&1; then
        vhash=$(ffprobe -v error -select_streams v:0 -show_frames -show_entries frame=key_frame,pkt_dts_time -of csv=p=0 "$canon_dst" 2>/dev/null | awk -F, '$1 == 1 {print $2}' | head -n 24 | tr '\n' ',' | if command -v shasum >/dev/null 2>&1; then shasum -a 256 | awk '{print substr($1,1,16)}'; else sha256sum | awk '{print substr($1,1,16)}'; fi)
      else
        vhash=$(sample_hash "$canon_dst" | cut -c1-16)
      fi
    fi
    if [ "$kind" = 'audio' ]; then
      ahash=$(sample_hash "$canon_dst" | cut -c1-16)
    fi

    cluster=$(printf '%s' "$phash" | cut -c1-8)
    [ -n "$cluster" ] || cluster='00000000'

    meta="$root/meta/${sha_canon}.meta"
    now_iso=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

    set_meta_field "$meta" sha256_raw "$sha_raw"
    set_meta_field "$meta" sha256_canon "$sha_canon"
    set_meta_field "$meta" identity "$sha_canon"
    set_meta_field "$meta" mime "$mime"
    set_meta_field "$meta" kind "$kind"
    set_meta_field "$meta" filename "$base"
    set_meta_field "$meta" raw_path "$raw_dst"
    set_meta_field "$meta" canon_path "$canon_dst"
    set_meta_field "$meta" perceptual_hash "$phash"
    set_meta_field "$meta" vhash "$vhash"
    set_meta_field "$meta" ahash "$ahash"
    set_meta_field "$meta" cluster "$cluster"
    set_meta_field "$meta" msig "$msig"
    set_meta_field "$meta" families "$families"
    set_meta_field "$meta" lineage ""
    set_meta_field "$meta" relations ""
    set_meta_field "$meta" listing_type "$listing_type"
    set_meta_field "$meta" price_flat "$price_flat"
    set_meta_field "$meta" canon_profile "$canon_profile"
    set_meta_field "$meta" temperature cold
    set_meta_field "$meta" temp_score 0
    set_meta_field "$meta" ingested_at "$now_iso"

    set_xattr_if_possible "$raw_dst" sha256_raw "$sha_raw"
    set_xattr_if_possible "$raw_dst" sha256_canon "$sha_canon"
    set_xattr_if_possible "$raw_dst" perceptual_hash "$phash"
    set_xattr_if_possible "$raw_dst" cluster "$cluster"

    append_journal "$root" "ingest" "$sha_canon"

    emit_ok_obj "\"sha256_raw\":\"$sha_raw\",\"sha256_canon\":\"$sha_canon\",\"cluster\":\"$cluster\",\"kind\":\"$kind\",\"meta\":\"$(json_escape "$meta")\""
    ;;

  list)
    root=$(ensure_root "${1-}")
    limit=${2-120}
    tmp=$(mktemp "${TMPDIR:-/tmp}/memetrader-list.XXXXXX")
    find "$root/meta" -type f -name '*.meta' 2>/dev/null | while IFS= read -r meta; do
      sha=$(get_meta_field "$meta" sha256_canon)
      name=$(get_meta_field "$meta" filename)
      cluster=$(get_meta_field "$meta" cluster)
      temp=$(get_meta_field "$meta" temperature)
      msig=$(get_meta_field "$meta" msig)
      fam=$(get_meta_field "$meta" families)
      kind=$(get_meta_field "$meta" kind)
      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$sha" "$name" "$cluster" "$temp" "$msig" "$fam" "$kind"
    done > "$tmp"

    lines=$(tail -n "$limit" "$tmp" 2>/dev/null || true)
    rm -f "$tmp"
    payload=$(printf '%s\n' "$lines" | awk -F'\t' '
      BEGIN { first=1; printf "[" }
      NF >= 7 {
        gsub(/\\/, "\\\\", $0)
        for (i=1; i<=7; i++) { gsub(/"/, "\\\"", $i) }
        if (!first) printf ","
        first=0
        printf "{\"sha\":\"%s\",\"name\":\"%s\",\"cluster\":\"%s\",\"temperature\":\"%s\",\"msig\":\"%s\",\"families\":\"%s\",\"kind\":\"%s\"}", $1,$2,$3,$4,$5,$6,$7
      }
      END { printf "]" }
    ')
    emit_ok_obj "\"items\":$payload"
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
      up|meh) ;;
      *) emit_error "vote must be up or meh"; exit 2 ;;
    esac

    votes_file="$root/votes/$sha.votes"
    touch "$votes_file"

    now=$(date +%s)
    if [ "$vote_type" = 'up' ]; then
      last_up=$(awk '$2=="up"{x=$1} END{print x+0}' "$votes_file")
      if [ "$last_up" -gt 0 ] && [ $((now - last_up)) -lt 86400 ]; then
        wait_for=$((86400 - (now - last_up)))
        emit_error "upvote cooldown active (${wait_for}s remaining)"
        exit 1
      fi
    fi

    printf '%s\t%s\n' "$now" "$vote_type" >> "$votes_file"

    temp_out=$(compute_temperature "$votes_file")
    score=$(printf '%s' "$temp_out" | awk -F'\t' '{print $1}')
    tier=$(printf '%s' "$temp_out" | awk -F'\t' '{print $2}')

    meta="$root/meta/$sha.meta"
    if [ -f "$meta" ]; then
      set_meta_field "$meta" temp_score "$score"
      set_meta_field "$meta" temperature "$tier"
    fi

    append_journal "$root" "vote" "$sha:$vote_type"
    emit_ok_obj "\"sha\":\"$sha\",\"vote\":\"$vote_type\",\"temperature\":\"$tier\",\"temp_score\":$score"
    ;;

  tag)
    root=$(ensure_root "${1-}")
    sha=${2-}
    msig=${3-}
    families=${4-}
    if [ -z "$sha" ]; then
      emit_error "tag requires SHA"
      exit 2
    fi
    meta="$root/meta/$sha.meta"
    if [ ! -f "$meta" ]; then
      emit_error "unknown meme: $sha"
      exit 1
    fi
    set_meta_field "$meta" msig "$msig"
    set_meta_field "$meta" families "$families"
    append_journal "$root" "tag" "$sha"
    emit_ok_obj "\"sha\":\"$sha\""
    ;;

  lineage)
    root=$(ensure_root "${1-}")
    sha=${2-}
    precursor=${3-}
    meta="$root/meta/$sha.meta"
    if [ -z "$sha" ] || [ ! -f "$meta" ]; then
      emit_error "lineage requires known SHA"
      exit 1
    fi
    set_meta_field "$meta" lineage "$precursor"
    append_journal "$root" "lineage" "$sha->$precursor"
    emit_ok_obj "\"sha\":\"$sha\",\"precursor\":\"$precursor\""
    ;;

  relate)
    root=$(ensure_root "${1-}")
    sha=${2-}
    rel=${3-}
    target=${4-}
    meta="$root/meta/$sha.meta"
    if [ -z "$sha" ] || [ ! -f "$meta" ]; then
      emit_error "relate requires known SHA"
      exit 1
    fi
    case "$rel" in
      related|contrast|often-combined|visually-similar) ;;
      *) emit_error "unsupported relation: $rel"; exit 2 ;;
    esac
    existing=$(get_meta_field "$meta" relations)
    next="$existing"
    [ -z "$next" ] || next="$next;"
    next="${next}${rel}:${target}"
    set_meta_field "$meta" relations "$next"
    append_journal "$root" "relation" "$sha $rel $target"
    emit_ok_obj "\"sha\":\"$sha\",\"relation\":\"$rel\",\"target\":\"$target\""
    ;;

  draw)
    root=$(ensure_root "${1-}")
    temp_tilt=${2-0}
    tmp=$(mktemp -d "${TMPDIR:-/tmp}/memetrader-draw.XXXXXX")
    clusters="$tmp/clusters.tsv"

    find "$root/meta" -type f -name '*.meta' 2>/dev/null | while IFS= read -r meta; do
      sha=$(get_meta_field "$meta" sha256_canon)
      cl=$(get_meta_field "$meta" cluster)
      [ -n "$cl" ] || cl='00000000'
      temp=$(get_meta_field "$meta" temperature)
      score=$(get_meta_field "$meta" temp_score)
      [ -n "$score" ] || score=0
      printf '%s\t%s\t%s\t%s\n' "$cl" "$sha" "$temp" "$score"
    done > "$clusters"

    total=$(wc -l < "$clusters" | tr -d '[:space:]')
    if [ "${total:-0}" -le 0 ]; then
      rm -rf "$tmp"
      emit_error "inventory empty"
      exit 1
    fi

    uniq_clusters="$tmp/uniq.tsv"
    cut -f1 "$clusters" | sort -u > "$uniq_clusters"
    count=$(wc -l < "$uniq_clusters" | tr -d '[:space:]')
    idx=$(random_index "$count")
    cluster=$(sed -n "$((idx + 1))p" "$uniq_clusters")

    if [ "$temp_tilt" = '1' ]; then
      hot_cluster=$(awk -F'\t' '$3=="hot" {print $1}' "$clusters" | sort | uniq -c | sort -nr | awk 'NR==1{print $2}')
      if [ -n "$hot_cluster" ]; then
        coin=$(random_index 100)
        if [ "$coin" -lt 60 ]; then
          cluster=$hot_cluster
        fi
      fi
    fi

    candidates="$tmp/candidates.tsv"
    awk -F'\t' -v c="$cluster" '$1==c {print $0}' "$clusters" > "$candidates"
    n=$(wc -l < "$candidates" | tr -d '[:space:]')
    pick=$(random_index "$n")
    row=$(sed -n "$((pick + 1))p" "$candidates")
    sha=$(printf '%s' "$row" | awk -F'\t' '{print $2}')
    temp=$(printf '%s' "$row" | awk -F'\t' '{print $3}')

    rm -rf "$tmp"
    append_journal "$root" "draw" "$sha@$cluster"
    emit_ok_obj "\"sha\":\"$sha\",\"cluster\":\"$cluster\",\"temperature\":\"$temp\""
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
    out="$root/patches/outbox/${sha}--${curator}--${ts}.patch"
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

  apply-patch)
    root=$(ensure_root "${1-}")
    patch=${2-}
    if [ -z "$patch" ] || [ ! -f "$patch" ]; then
      emit_error "apply-patch requires existing PATCH_PATH"
      exit 2
    fi
    sha=$(awk -F= '$1=="sha256_canon" {print $2; exit}' "$patch")
    payload=$(awk -F= '$1=="payload" {sub(/^[^=]*=/,""); print; exit}' "$patch")
    meta="$root/meta/$sha.meta"
    if [ ! -f "$meta" ]; then
      emit_error "target meme not found for patch: $sha"
      exit 1
    fi
    existing=$(get_meta_field "$meta" proposal_notes)
    next="$existing"
    [ -z "$next" ] || next="$next;"
    next="${next}${payload}"
    set_meta_field "$meta" proposal_notes "$next"
    cp "$patch" "$root/patches/inbox/$(basename "$patch")"
    append_journal "$root" "patch-apply" "$patch"
    emit_ok_obj "\"sha\":\"$sha\""
    ;;

  *)
    emit_error "unknown action: $action"
    exit 2
    ;;
esac
