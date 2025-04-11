#!/bin/bash
set -e

input="$1"
filename=$(basename "$input")
name="${filename%.*}"

# Configurable options
fps_mode="copy"       # "copy" or set like "24"
res_mode="copy"       # "copy" or set like "1280x720"
crf="28"
audio_bitrate="25k"
deblock="0:0"
rd="4"

# Output directories
mkdir -p output wav wav_stereo m4a

echo "Processing: $filename"

# FPS and resolution flags
fps_flag=""
res_flag=""

if [[ "$fps_mode" != "copy" ]]; then
  fps_flag="-r $fps_mode"
fi

if [[ "$res_mode" != "copy" ]]; then
  res_flag="-s $res_mode"
fi

# Step 1: Encode video stream
ffmpeg -i "$input" $fps_flag $res_flag -f yuv4mpegpipe -strict -1 - | \
x265 - --crf "$crf" --deblock=$deblock --rd "$rd" --y4m --frame-threads 16 --pools none --log-level 2 --output-depth 8 --profile main10 --high-tier --min-cu-size 8 --ctu 64 --qg-size 32 --no-opt-cu-delta-qp --tu-intra-depth 1 --tu-inter-depth 1 --limit-tu 0 --max-tu-size 32 --me hex --subme 2 --merange 57 --no-limit-modes --no-rect --no-amp --max-merge 3 --early-skip --rskip 1 --rdpenalty 0 --no-tskip --strong-intra-smoothing --no-constrained-intra --open-gop --opt-ref-list-length-pps --keyint 250 --min-keyint 23 --bframes 4 --no-weightb --bframe-bias 0 --b-adapt 2 --b-pyramid --ref 3 --weightp --rc-lookahead 20 --slices 1 --lookahead-threads 0 --scenecut 40 --scenecut-bias 5 --qpstep 4 --qpmin 0 --qpmax 69 --opt-qp-pps --no-rc-grain --cbqpoffs -2 --crqpoffs 0 --ipratio 1.4 --pbratio 1.3 --nr-intra 0 --nr-inter 0 --no-fast-intra --no-ssim-rd --no-rd-refine --psy-rd 0.40 --no-rdoq-level --no-psy-rdoq --signhide --qcomp 0.6 --no-aq-motion --aq-mode 2 --aq-strength 0.60 --cutree --no-cu-lossless --vbv-maxrate 0 --vbv-bufsize 0 --vbv-init 0.9 --no-hrd --no-aud --info --sao --no-sao-non-deblock --no-temporal-layers --log2-max-poc-lsb 8 --no-psnr --no-ssim --no-interlace --range limited --colorprim bt709 --transfer bt709 --colormatrix bt709 --max-cll "0,0" --hdr --temporal-mvp  --no-b-intra --lookahead-slices 0 --limit-refs 0 --no-repeat-headers -o "output/${name}.hevc"

# Step 2: Extract audio to WAV
ffmpeg -i "$input" -vn -c:a pcm_s32le "wav/${name}.wav"

# Step 3: Downmix to stereo WAV
ffmpeg -i "wav/${name}.wav" -ac 2 -ar 44100 "wav_stereo/${name}_stereo.wav"

# Step 4: Encode audio using fdkaac HE-AACv2
fdkaac --profile 29 -b "$audio_bitrate" -o "m4a/${name}.m4a" "wav_stereo/${name}_stereo.wav"

# Step 5: Remux to final MP4
ffmpeg -i "output/${name}.hevc" -i "m4a/${name}.m4a" -c copy "output/${name}_x265.mp4"

# Optional cleanup
rm "output/${name}.hevc" "wav/${name}.wav"
