# FZF

if command -v fd >/dev/null 2>&1; then
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --strip-cwd-prefix'
elif command -v fdfind >/dev/null 2>&1; then
  export FZF_DEFAULT_COMMAND='fdfind --type f --hidden --strip-cwd-prefix'
fi

export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

# ---------------------------------------------------------------------------
# Preview renderer
# ---------------------------------------------------------------------------

export _FZF_PREVIEW='
  f=$1
  [ -e "$f" ] || exit 0

  if [ -d "$f" ]; then
    ls -A --color=always -- "$f"
    exit 0
  fi

  w=$(( ${FZF_PREVIEW_COLUMNS:-80} - 2 ))
  h=$(( ${FZF_PREVIEW_LINES:-25} - 2 ))
  [ "$w" -lt 1 ] && w=1
  [ "$h" -lt 1 ] && h=1

  show() {
    if [ "$w" -lt 4 ] || [ "$h" -lt 3 ]; then
      basename "$f"
      return 0
    fi
    kitten icat --image-id 9137 --transfer-mode=memory --unicode-placeholder \
      --scale-up --stdin=no --place="${w}x${h}@1x1" "$1" | head -c -1
  }

  as_text() {
    bat --style=numbers --color=always --line-range=:300 --paging=never -- "$f"
  }

  cdir=${XDG_CACHE_HOME:-$HOME/.cache}/fzf-preview
  ckey=$(printf "%s" "$f$(stat -c %Y.%s -- "$f" 2>/dev/null)" | md5sum | cut -d" " -f1)
  cache=$cdir/$ckey.png
  mkdir -p "$cdir"

  mime=$(file -Lb --mime-type -- "$f")

  case "$mime" in
    image/svg+xml)
      [ -s "$cache" ] || rsvg-convert -w 900 -a -o "$cache" -- "$f" 2>/dev/null
      [ -s "$cache" ] && show "$cache" || as_text
      ;;
    image/*)
      show "$f"
      ;;
    video/*)
      [ -s "$cache" ] || ffmpeg -v error -y -ss 1 -i "$f" -frames:v 1 \
        -vf "scale=900:-2" "$cache" </dev/null >/dev/null 2>&1
      [ -s "$cache" ] || ffmpeg -v error -y -i "$f" -frames:v 1 \
        -vf "scale=900:-2" "$cache" </dev/null >/dev/null 2>&1
      [ -s "$cache" ] && show "$cache" || file -Lb -- "$f"
      ;;
    application/pdf)
      [ -s "$cache" ] || pdftoppm -png -r 120 -f 1 -l 1 -singlefile -- "$f" "${cache%.png}" 2>/dev/null
      [ -s "$cache" ] && show "$cache" || pdftotext -l 5 -- "$f" -
      ;;
    audio/*)
      ffprobe -v error -show_entries format=duration,bit_rate \
        -show_entries format_tags=title,artist,album -of default=nw=1 -- "$f" 2>/dev/null \
        || file -Lb -- "$f"
      ;;
    application/zip|application/x-tar|application/gzip|application/x-xz|\
    application/x-bzip2|application/zstd|application/x-7z-compressed|application/x-rar)
      bsdtar -tf "$f" 2>/dev/null | head -200 || 7z l -ba -- "$f" 2>/dev/null | head -200
      ;;
    inode/x-empty)
      echo "(empty file)"
      ;;
    text/*|application/json|application/javascript|application/xml|*+xml|application/x-shellscript)
      as_text
      ;;
    *)
      file -Lb -- "$f"
      ;;
  esac
'

_fzf_header='ctrl-p copy'
export _FZF_HEADER="$_fzf_header"

# ---------------------------------------------------------------------------
# Copy helper
# ---------------------------------------------------------------------------
export _FZF_COPY='
  f=$1
  [ -f "$f" ] || { echo "not a file"; exit 0; }

  size=$(stat -c %s -- "$f" 2>/dev/null || echo 0)
  human=$(numfmt --to=iec --suffix=B "$size" 2>/dev/null || echo "${size}B")

  restore_later() {
    [ -n "$FZF_PORT" ] || return 0
    { sleep 3
      curl -s -XPOST "localhost:$FZF_PORT" \
        --data "change-header($_FZF_HEADER)"
    } >/dev/null 2>&1 &
  }

  mime=$(file -Lb --mime-type -- "$f")

  case "$mime" in
    image/svg+xml)
      # Copy as a file URI. WhatsApp and Photopea treat this as a direct file drag-and-drop.
      printf "file://%s" "$(readlink -f -- "$f")" | wl-copy --type text/uri-list
      msg="copied SVG as file link"
      ;;
    image/*)
      # PNGs and JPEGs copy natively as standard image data
      wl-copy --type "$mime" < "$f" && msg="copied as image ($mime)"
      ;;
    text/*|*+xml|application/json|application/javascript|application/x-shellscript)
      # Text files copy as standard raw text
      wl-copy -n --type text/plain < "$f" && msg="copied text content"
      ;;
    application/pdf)
      # PDFs copy as a file URI
      printf "file://%s" "$(readlink -f -- "$f")" | wl-copy --type text/uri-list
      msg="copied PDF as file link"
      ;;
    *)
      if [ "$size" -gt 20971520 ]; then
        printf "file://%s" "$(readlink -f -- "$f")" | wl-copy --type text/uri-list
        msg="copied file link ($human too large to inline)"
      else
        wl-copy --type "$mime" < "$f" && msg="copied $human as $mime"
      fi
      ;;
  esac

  restore_later
  echo "${msg:-copy failed}"
'

_fzf_preview_opts=(
  --preview 'sh -c "$_FZF_PREVIEW" _ {}'
  --preview-window 'right:50%:border-left'
  --bind 'resize:refresh-preview'
  --bind 'ctrl-p:transform-header(sh -c "$_FZF_COPY" _ {})'
  --bind "focus:change-header($_fzf_header)"
  --listen
  --header "$_fzf_header"
)

export FZF_DEFAULT_OPTS='
--height 46%
--layout=reverse
--border
'

export FZF_CTRL_T_OPTS="${(j: :)${(qq)_fzf_preview_opts[@]}}"
export FZF_ALT_C_OPTS="--preview 'ls -A --color=always {}' --preview-window right:50%:border-left"

# CTRL + F file picker excluding hidden files

_fzf_file_picker() {
  local cmd result
  cmd="${FZF_DEFAULT_COMMAND/--hidden /}"

  result=$(eval "${cmd:-find . -type f}" | fzf "${_fzf_preview_opts[@]}") \
    && LBUFFER+="${(q)result}"

  zle reset-prompt
}
zle -N _fzf_file_picker