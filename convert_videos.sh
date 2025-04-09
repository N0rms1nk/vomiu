#!/bin/bash

# Ensure the directories exist
mkdir -p input output

# Download videos from rclone remote
echo "Downloading videos..."
rclone copy DBOX:DL ./input --include "*.mp4" --include "*.mkv" --include "*.avi" --include "*.mov" --include "*.webm" --progress

# Check if files were downloaded
echo "Files in input directory:"
ls -lh ./input

# Loop through all video files in the input directory
for f in ./input/*; do
  filename=$(basename "$f")
  name="${filename%.*}"

  # Encode video using ffmpeg piped to x265 with HE-AACv2 audio
  echo "Converting $f to HEVC..."
  ffmpeg -i "$f" -map 0 -c:a libfdk_aac -profile:a aac_he_v2 -b:a 48k -c:s copy -f yuv4mpegpipe -pix_fmt yuv420p -strict -1 | \
  x265 --y4m --crf 28 --preset slow --output-depth 8 --profile main10 --high-tier --min-cu-size 8 --ctu 64 --qg-size 32 --me hex --subme 2 --merange 57 --keyint 250 --min-keyint 23 --bframes 4 --b-adapt 2 --b-pyramid --ref 3 --weightp --rc-lookahead 20 --slices 1 --scenecut 40 --scenecut-bias 5 --qpstep 4 --qpmin 0 --qpmax 69 --opt-qp-pps --no-rc-grain --cbqpoffs -2 --crqpoffs 0 --ipratio 1.4 --pbratio 1.3 --nr-intra 0 --nr-inter 0 --rd 4 --no-fast-intra --no-ssim-rd --no-rd-refine --psy-rd 0.40 --no-rdoq-level --no-psy-rdoq --signhide --qcomp 0.6 --no-aq-motion --aq-mode 2 --aq-strength 0.60 --cutree --no-cu-lossless --vbv-maxrate 0 --vbv-bufsize 0 --vbv-init 0.9 --no-hrd --no-aud --info --sao --no-sao-non-deblock --no-temporal-layers --log2-max-poc-lsb 8 --no-psnr --no-ssim --no-interlace --range limited --colorprim bt709 --transfer bt709 --colormatrix bt709 --max-cll "0,0" --hdr --temporal-mvp --no-b-intra --lookahead-slices 0 --limit-refs 0 --no-repeat-headers -o "output/${name}.hevc" - || echo "x265 failed for $f"

  # Remux everything back into mp4 with metadata and subtitles
  echo "Remuxing $f into MP4..."
  ffmpeg -i "$f" -i "output/${name}.hevc" -map 0 -map -0:v -map 1:v -c copy "output/${name}_x265.mp4" || echo "Remuxing failed for $f"

  # Clean intermediate .hevc file
  rm "output/${name}.hevc"
done

# Check the output directory
echo "Files in output directory after conversion:"
ls -lh ./output

# Upload the converted files to rclone remote
echo "Uploading to rclone remote..."
rclone copy ./output BDoDrive:Here/Hevc --progress || echo "Rclone upload failed"
echo "Upload completed"
