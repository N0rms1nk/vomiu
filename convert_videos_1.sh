#!/bin/bash
set -e

input="$1"
filename=$(basename "$input")
name="${filename%.*}"

# Customizable variables
fps="copy"            # Set to "copy" or number like 24
resolution="copy"     # Set to "copy" or format like 1280x720
crf=37
deblock="0:0"
rd=8
audio_bitrate="25k"

mkdir -p output wav wav_stereo m4a

# Build optional filters
vf_filter=""
[ "$fps" != "copy" ] && vf_filter="fps=$fps"
[ "$resolution" != "copy" ] && vf_filter="${vf_filter},scale=${resolution}"
vf_filter=$(echo "$vf_filter" | sed 's/^,//')

# Video conversion
ffmpeg -i "$input" ${vf_filter:+-vf "$vf_filter"} -f yuv4mpegpipe -strict -1 - | \
x265 - --crf "$crf" --deblock "$deblock" --rd "$rd" --y4m -o "output/${name}.hevc"

# Audio conversion
ffmpeg -i "$input" -vn -c:a pcm_s32le "wav/${name}.wav"
ffmpeg -i "wav/${name}.wav" -ac 2 -ar 44100 "wav_stereo/${name}_stereo.wav"
fdkaac --profile 29 -b "$audio_bitrate" -o "m4a/${name}.m4a" "wav_stereo/${name}_stereo.wav"

# Remux
ffmpeg -i "output/${name}.hevc" -i "m4a/${name}.m4a" -c:v copy -c:a copy "output/${name}_x265.mp4"

# Optional cleanups
rm -f "output/${name}.hevc" "wav/${name}.wav"
