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
echo "${RCLONE_CONF}" | base64 -d > ~/.config/rclone/rclone.conf

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
    x265 - --crf "$CRF" --deblock "$DEBLOCK" --rd "$RD" --y4m --frame-threads 16 --pools none --log-level 2 --output-depth 8 --profile main10 --high-tier --min-cu-size 8 --ctu 64 --qg-size 32 --no-opt-cu-delta-qp --tu-intra-depth 1 --tu-inter-depth 1 --limit-tu 0 --max-tu-size 32 --me hex --subme 2 --merange 57 --no-limit-modes --no-rect --no-amp --max-merge 3 --early-skip --rskip 1 --rdpenalty 0 --no-tskip --strong-intra-smoothing --no-constrained-intra --open-gop --opt-ref-list-length-pps --keyint 250 --min-keyint 23 --bframes 4 --no-weightb --bframe-bias 0 --b-adapt 2 --b-pyramid --ref 3 --weightp --rc-lookahead 20 --slices 1 --lookahead-threads 0 --scenecut 40 --scenecut-bias 5 --qpstep 4 --qpmin 0 --qpmax 69 --opt-qp-pps --no-rc-grain --cbqpoffs -2 --crqpoffs 0 --ipratio 1.4 --pbratio 1.3 --nr-intra 0 --nr-inter 0 --no-fast-intra --no-ssim-rd --no-rd-refine --psy-rd 0.40 --no-rdoq-level --no-psy-rdoq --signhide --qcomp 0.6 --no-aq-motion --aq-mode 2 --aq-strength 0.60 --cutree --no-cu-lossless --vbv-maxrate 0 --vbv-bufsize 0 --vbv-init 0.9 --no-hrd --no-aud --info --sao --no-sao-non-deblock --no-temporal-layers --log2-max-poc-lsb 8 --no-psnr --no-ssim --no-interlace --range limited --colorprim bt709 --transfer bt709 --colormatrix bt709 --max-cll "0,0" --hdr --temporal-mvp  --no-b-intra --lookahead-slices 0 --limit-refs 0 --no-repeat-headers --output "output/${name}.hevc"
else
  echo "Encoding video with filters: $FILTERS"
  ffmpeg -i "$f" -vf "$FILTERS" -f yuv4mpegpipe -strict -1 - | \
    x265 - --crf "$CRF" --deblock "$DEBLOCK" --rd "$RD" --y4m --frame-threads 16 --pools none --log-level 2 --output-depth 8 --profile main10 --high-tier --min-cu-size 8 --ctu 64 --qg-size 32 --no-opt-cu-delta-qp --tu-intra-depth 1 --tu-inter-depth 1 --limit-tu 0 --max-tu-size 32 --me hex --subme 2 --merange 57 --no-limit-modes --no-rect --no-amp --max-merge 3 --early-skip --rskip 1 --rdpenalty 0 --no-tskip --strong-intra-smoothing --no-constrained-intra --open-gop --opt-ref-list-length-pps --keyint 250 --min-keyint 23 --bframes 4 --no-weightb --bframe-bias 0 --b-adapt 2 --b-pyramid --ref 3 --weightp --rc-lookahead 20 --slices 1 --lookahead-threads 0 --scenecut 40 --scenecut-bias 5 --qpstep 4 --qpmin 0 --qpmax 69 --opt-qp-pps --no-rc-grain --cbqpoffs -2 --crqpoffs 0 --ipratio 1.4 --pbratio 1.3 --nr-intra 0 --nr-inter 0 --no-fast-intra --no-ssim-rd --no-rd-refine --psy-rd 0.40 --no-rdoq-level --no-psy-rdoq --signhide --qcomp 0.6 --no-aq-motion --aq-mode 2 --aq-strength 0.60 --cutree --no-cu-lossless --vbv-maxrate 0 --vbv-bufsize 0 --vbv-init 0.9 --no-hrd --no-aud --info --sao --no-sao-non-deblock --no-temporal-layers --log2-max-poc-lsb 8 --no-psnr --no-ssim --no-interlace --range limited --colorprim bt709 --transfer bt709 --colormatrix bt709 --max-cll "0,0" --hdr --temporal-mvp  --no-b-intra --lookahead-slices 0 --limit-refs 0 --no-repeat-headers --output "output/${name}.hevc"
fi

# Audio
ffmpeg -i "$f" -vn -c:a pcm_s32le "wav/${name}.wav"
ffmpeg -i "wav/${name}.wav" -ac 2 -ar 44100 "wav_stereo/${name}_stereo.wav"
fdkaac --profile 29 -b "$AUDIO_BITRATE" -o "m4a/${name}.m4a" "wav_stereo/${name}_stereo.wav"

# Final mux
ffmpeg -i "output/${name}.hevc" -i "m4a/${name}.m4a" -c:v copy -c:a copy "output/${name}_x265.mp4"

# Cleanup
rm "output/${name}.hevc" "wav/${name}.wav" "wav_stereo/${name}_stereo.wav"

# Upload to remote
rclone copy ./output BDoDrive:Here/Hevc --progress
