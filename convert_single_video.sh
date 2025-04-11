#!/bin/bash
set -e

INPUT_FILE="$1"

# === CONFIGURABLE OPTIONS ===
# Set to "source" to copy from source, or set specific value (e.g., "24", "1280:-1", etc.)
FPS="source"             # or e.g. "24"
RESOLUTION="source"      # or e.g. "1280:-1"
CRF=30
DEBLOCK="0:0"
RD=4
AUDIO_BITRATE="25k"
# ============================

# Install deps
sudo apt-get update
sudo apt-get install -y x265 jq

curl -L https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz -o ffmpeg.tar.xz
tar -xf ffmpeg.tar.xz
sudo mv ffmpeg-*-amd64-static/ffmpeg /usr/local/bin/
sudo chmod +x /usr/local/bin/ffmpeg

curl -L -o fdkaac.tar.gz https://github.com/N0rms1nk/vomiu/releases/download/v1.0.0/fdkaac_static.tar.gz
tar -xzf fdkaac.tar.gz
chmod +x fdkaac
sudo mv fdkaac /usr/local/bin/fdkaac

mkdir -p ~/.config/rclone
echo "${RCLONE_CONF}" > ~/.config/rclone/rclone.conf

# Prepare folders
mkdir -p input output wav wav_stereo m4a

# Download single file
rclone copy "BDoDrive:YT/Life/$INPUT_FILE" ./input --progress

# Get filename
f="./input/$INPUT_FILE"
filename=$(basename "$f")
name="${filename%.*}"

# Get source resolution and fps if needed
if [[ "$FPS" == "source" ]]; then
  FPS_FILTER=""
else
  FPS_FILTER="fps=${FPS}"
fi

if [[ "$RESOLUTION" == "source" ]]; then
  SCALE_FILTER=""
else
  SCALE_FILTER="scale=${RESOLUTION}"
fi

# Combine filters
FILTERS=$(IFS=, ; echo "${FPS_FILTER},${SCALE_FILTER}" | sed 's/^,//;s/,$//')

# Encode video
if [[ -z "$FILTERS" ]]; then
  echo "Encoding video without scaling or fps conversion..."
  ffmpeg -i "$f" -f yuv4mpegpipe -strict -1 - | \
    x265 - --crf "$CRF" --deblock "$DEBLOCK" --rd "$RD" --y4m --output "output/${name}.hevc"
else
  echo "Encoding video with filters: $FILTERS"
  ffmpeg -i "$f" -vf "$FILTERS" -f yuv4mpegpipe -strict -1 - | \
    x265 - --crf "$CRF" --deblock "$DEBLOCK" --rd "$RD" --y4m --output "output/${name}.hevc"
fi

# Audio
ffmpeg -i "$f" -vn -c:a pcm_s32le "wav/${name}.wav"
ffmpeg -i "wav/${name}.wav" -ac 2 -ar 44100 "wav_stereo/${name}_stereo.wav"
fdkaac --profile 29 -b "$AUDIO_BITRATE" -o "m4a/${name}.m4a" "wav_stereo/${name}_stereo.wav"

# Final mux
ffmpeg -i "output/${name}.hevc" -i "m4a/${name}.m4a" -c:v copy -c:a copy "output/${name}_x265.mp4"

# Upload to remote
rclone copy ./output BDoDrive:Here/Hevc --progress
