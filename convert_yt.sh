#!/bin/bash
set -e

# CONFIGURATION
fps=""                # Leave empty to copy from source
resolution=""         # Leave empty to copy from source
crf=28
audio_bitrate="32k"
deblock="0:0"
rd=4
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

# Get filename
for f in ./input/*; do
  filename=$(basename "$f")
  name="${filename%.*}"

  echo "Processing: $filename"

  # Build filter string
  filter=""
  [ -n "$fps" ] && filter+="fps=$fps"
  [ -n "$resolution" ] && filter+=",scale=$resolution"
  filter="${filter#,}"  # Remove leading comma

  # Step 1: Encode video to HEVC
  if [ -n "$filter" ]; then
    ffmpeg -i "$f" -vf "$filter" -f yuv4mpegpipe -strict -1 - | x265 - --crf "$crf" --deblock "$deblock" --rd "$rd" --y4m --frame-threads 16 --pools none --log-level 2 --output-depth 8 --profile main10 --high-tier --min-cu-size 8 --ctu 64 --qg-size 32 --no-opt-cu-delta-qp --tu-intra-depth 1 --tu-inter-depth 1 --limit-tu 0 --max-tu-size 32 --me hex --subme 2 --merange 57 --no-limit-modes --no-rect --no-amp --max-merge 3 --early-skip --rskip 1 --rdpenalty 0 --no-tskip --strong-intra-smoothing --no-constrained-intra --open-gop --opt-ref-list-length-pps --keyint 250 --min-keyint 23 --bframes 4 --no-weightb --bframe-bias 0 --b-adapt 2 --b-pyramid --ref 3 --weightp --rc-lookahead 20 --slices 1 --lookahead-threads 0 --scenecut 40 --scenecut-bias 5 --qpstep 4 --qpmin 0 --qpmax 69 --opt-qp-pps --no-rc-grain --cbqpoffs -2 --crqpoffs 0 --ipratio 1.4 --pbratio 1.3 --nr-intra 0 --nr-inter 0 --no-fast-intra --no-ssim-rd --no-rd-refine --psy-rd 0.40 --no-rdoq-level --no-psy-rdoq --signhide --qcomp 0.6 --no-aq-motion --aq-mode 2 --aq-strength 0.60 --cutree --no-cu-lossless --vbv-maxrate 0 --vbv-bufsize 0 --vbv-init 0.9 --no-hrd --no-aud --info --sao --no-sao-non-deblock --no-temporal-layers --log2-max-poc-lsb 8 --no-psnr --no-ssim --no-interlace --range limited --colorprim bt709 --transfer bt709 --colormatrix bt709 --max-cll "0,0" --hdr --temporal-mvp  --no-b-intra --lookahead-slices 0 --limit-refs 0 --no-repeat-headers -o "output/${name}.hevc"
  else
    ffmpeg -i "$f" -f yuv4mpegpipe -strict -1 - | x265 - --crf "$crf" --deblock "$deblock" --rd "$rd" --y4m --frame-threads 16 --pools none --log-level 2 --output-depth 8 --profile main10 --high-tier --min-cu-size 8 --ctu 64 --qg-size 32 --no-opt-cu-delta-qp --tu-intra-depth 1 --tu-inter-depth 1 --limit-tu 0 --max-tu-size 32 --me hex --subme 2 --merange 57 --no-limit-modes --no-rect --no-amp --max-merge 3 --early-skip --rskip 1 --rdpenalty 0 --no-tskip --strong-intra-smoothing --no-constrained-intra --open-gop --opt-ref-list-length-pps --keyint 250 --min-keyint 23 --bframes 4 --no-weightb --bframe-bias 0 --b-adapt 2 --b-pyramid --ref 3 --weightp --rc-lookahead 20 --slices 1 --lookahead-threads 0 --scenecut 40 --scenecut-bias 5 --qpstep 4 --qpmin 0 --qpmax 69 --opt-qp-pps --no-rc-grain --cbqpoffs -2 --crqpoffs 0 --ipratio 1.4 --pbratio 1.3 --nr-intra 0 --nr-inter 0 --no-fast-intra --no-ssim-rd --no-rd-refine --psy-rd 0.40 --no-rdoq-level --no-psy-rdoq --signhide --qcomp 0.6 --no-aq-motion --aq-mode 2 --aq-strength 0.60 --cutree --no-cu-lossless --vbv-maxrate 0 --vbv-bufsize 0 --vbv-init 0.9 --no-hrd --no-aud --info --sao --no-sao-non-deblock --no-temporal-layers --log2-max-poc-lsb 8 --no-psnr --no-ssim --no-interlace --range limited --colorprim bt709 --transfer bt709 --colormatrix bt709 --max-cll "0,0" --hdr --temporal-mvp  --no-b-intra --lookahead-slices 0 --limit-refs 0 --no-repeat-headers -o "output/${name}.hevc"
  fi

  # Step 2: Extract audio and encode to HE-AACv2
  ffmpeg -i "$f" -vn -c:a pcm_s32le "wav/${name}.wav"
  ffmpeg -i "wav/${name}.wav" -ac 2 -ar 44100 "wav_stereo/${name}_stereo.wav"
  fdkaac --profile 29 -b "$audio_bitrate" -o "m4a/${name}.m4a" "wav_stereo/${name}_stereo.wav"

  # Step 3: Remux to MP4
  ffmpeg -i "output/${name}.hevc" -i "m4a/${name}.m4a" -c:v copy -c:a copy "output/${name}_x265.mp4"

  # Cleanup
  rm "output/${name}.hevc" "wav/${name}.wav" "wav_stereo/${name}_stereo.wav"

  # Upload to remote
  rclone copy ./output BDoDrive:Here/ytsh --progress
done
