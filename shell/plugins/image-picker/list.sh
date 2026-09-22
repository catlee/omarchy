#!/bin/bash

image_dirs=${1:-}
cache_dir=${XDG_CACHE_HOME:-$HOME/.cache}/omarchy/image-selector

mkdir -p "$cache_dir"

is_video_path() {
  [[ ${1,,} =~ \.(mp4|m4v|mov|webm|mkv|avi)$ ]]
}

thumbnail_path_for() {
  local image="$1"
  local kind="still"

  if is_video_path "$image"; then
    kind="video"
  fi
  printf '%s/thumbnails/%s/%s.jpg' "$cache_dir" "$kind" "$(printf '%s' "$image" | sha256sum | cut -d ' ' -f 1)"
}

thumbnail_for() {
  local image="$1"
  local thumbnail

  thumbnail=$(thumbnail_path_for "$image") || return

  if is_video_path "$image" && [[ -f $thumbnail.failed ]]; then
    return
  elif [[ -f $thumbnail ]]; then
    printf '%s' "$thumbnail"
  elif ! is_video_path "$image"; then
    printf '%s' "$image"
  fi
}

mapfile -d '' -t images < <(
  while IFS= read -r dir; do
    [[ -n $dir && -d $dir ]] || continue
    find -L "$dir" -maxdepth 1 -type f \
      \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' -o -iname '*.bmp' -o -iname '*.webp' \
         -o -iname '*.mp4' -o -iname '*.m4v' -o -iname '*.mov' -o -iname '*.webm' -o -iname '*.mkv' -o -iname '*.avi' \) \
      -print0 2>/dev/null
  done <<<"$image_dirs" | sort -z
)

video_images=()
for image in "${images[@]}"; do
  is_video_path "$image" && video_images+=("$image")
done
if (( ${#video_images[@]} > 0 )); then
  video_jobs=$(( $(nproc) / 4 ))
  (( video_jobs > 0 )) || video_jobs=1
  for image in "${video_images[@]}"; do
    printf 'thumbnails/video/%s.jpg: ' "$(printf '%s' "$image" | sha256sum | cut -d ' ' -f 1)"
    printf '%q\n' "$image"
  done | "${OMARCHY_NEED_BIN:-need}" --file "$OMARCHY_PATH/needfile" --root "$cache_dir" -j "$video_jobs" get --from - >/dev/null 2>&1 || true
fi

for image in "${images[@]}"; do
  thumbnail=$(thumbnail_for "$image")
  [[ -n $thumbnail ]] || continue
  printf '%s\t%s\n' "$image" "$thumbnail"
done
