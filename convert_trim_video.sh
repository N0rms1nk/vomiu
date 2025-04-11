#!/bin/bash
set -e

echo "Installing dependencies..."
sudo apt-get update && sudo apt-get install -y x265 jq curl tar xz-utils &

# Install ffmpeg
(
  echo "Downloading and installing ffmpeg..."
  curl -L https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz -o ffmpeg.tar.xz
  tar -xf ffmpeg.tar.xz
  sudo mv ffmpeg-*-amd64-static/ffmpeg /usr/local/bin/
  sudo chmod +x /usr/local/bin/ffmpeg
) &

# Install fdkaac
(
  echo "Downloading and installing fdkaac..."
  curl -L -o fdkaac.tar.gz https://github.com/N0rms1nk/vomiu/releases/download/v1.0.0/fdkaac_static.tar.gz
  tar -xzf fdkaac.tar.gz
  chmod +x fdkaac
  sudo mv fdkaac /usr/local/bin/fdkaac
) &

wait
echo "Setup completed."

INPUT_NAME="$1"
FILENAME=$(basename "$INPUT_NAME")
WORKDIR="$(pwd)/work"
OUTDIR="$(pwd)/output"

mkdir -p "$WORKDIR" "$OUTDIR"

echo "Processing: $FILENAME"

# Encoding Configs
FPS="24"
RESOLUTION="960:-1"
CRF="30"
RD="6"
DEBLOCK="1:1"
ABITRATE="25k"

# Trim per video
case "$FILENAME" in
  "[ANICHIN.CARE][Senior_Brother_is_Too_Steady][2023][82].[1080p].mp4")
    SS="120"
    T="982"
    ;;
  "[ANICHIN.CARE][Senior_Brother_is_Too_Steady][2023][83].[1080p].mp4")
    SS="120"
    T="956"
    ;;
  "[ANICHIN.CARE][Senior_Brother_is_Too_Steady][2023][84].[1080p].mp4")
    SS="120"
    T="963"
    ;;
  *)
    echo "No trim config for $FILENAME"
    exit 1
    ;;
esac

# Download input
echo "Downloading from BDoDrive:YT/Life/$FILENAME..."
rclone copy "BDoDrive:YT/Life/$FILENAME" "$WORKDIR" --progress

INPUT="$WORKDIR/$FILENAME"
BASENAME="${FILENAME%.*}"
RAW_VIDEO="$WORKDIR/$BASENAME.hevc"
RAW_AUDIO="$WORKDIR/$BASENAME.m4a"
FINAL_OUTPUT="$OUTDIR/$BASENAME.mp4"

# Extract resolution/fps if set to copy
WIDTH=""
HEIGHT=""
if [ "$RESOLUTION" = "copy" ]; then
  RESOLUTION_OPT=""
else
  RESOLUTION_OPT="-vf scale=$RESOLUTION"
fi

FPS_OPT=""
if [ "$FPS" != "copy" ]; then
  FPS_OPT="-r $FPS"
fi

# Encode video using x265 via ffmpeg pipe
echo "Encoding video..."
ffmpeg -hide_banner -loglevel error -y -ss "$SS" -t "$T" -i "$INPUT" $FPS_OPT $RESOLUTION_OPT -an \
  -pix_fmt yuv420p10le -f yuv4mpegpipe - | \
  x265 - --crf "$CRF" --deblock "$DEBLOCK" --rd "$RD" --y4m --frame-threads 16 --pools none --log-level 2 --output-depth 8 --profile main10 --high-tier --min-cu-size 8 --ctu 64 --qg-size 32 --no-opt-cu-delta-qp --tu-intra-depth 1 --tu-inter-depth 1 --limit-tu 0 --max-tu-size 32 --me hex --subme 2 --merange 57 --no-limit-modes --no-rect --no-amp --max-merge 3 --early-skip --rskip 1 --rdpenalty 0 --no-tskip --strong-intra-smoothing --no-constrained-intra --open-gop --opt-ref-list-length-pps --keyint 250 --min-keyint 23 --bframes 4 --no-weightb --bframe-bias 0 --b-adapt 2 --b-pyramid --ref 3 --weightp --rc-lookahead 20 --slices 1 --lookahead-threads 0 --scenecut 40 --scenecut-bias 5 --qpstep 4 --qpmin 0 --qpmax 69 --opt-qp-pps --no-rc-grain --cbqpoffs -2 --crqpoffs 0 --ipratio 1.4 --pbratio 1.3 --nr-intra 0 --nr-inter 0 --no-fast-intra --no-ssim-rd --no-rd-refine --psy-rd 0.40 --no-rdoq-level --no-psy-rdoq --signhide --qcomp 0.6 --no-aq-motion --aq-mode 2 --aq-strength 0.60 --cutree --no-cu-lossless --vbv-maxrate 0 --vbv-bufsize 0 --vbv-init 0.9 --no-hrd --no-aud --info --sao --no-sao-non-deblock --no-temporal-layers --log2-max-poc-lsb 8 --no-psnr --no-ssim --no-interlace --range limited --colorprim bt709 --transfer bt709 --colormatrix bt709 --max-cll "0,0" --hdr --temporal-mvp  --no-b-intra --lookahead-slices 0 --limit-refs 0 --no-repeat-headers \
       --output "$RAW_VIDEO" -

# Extract and encode audio
echo "Encoding audio..."
ffmpeg -hide_banner -loglevel error -y -ss "$SS" -t "$T" -i "$INPUT" -vn -c:a pcm_s32le -ac 2 -ar 44100 -f wav - | \
  fdkaac --profile 29 -b $ABITRATE -o "$RAW_AUDIO"

# Mux to MP4
echo "Muxing to MP4..."
ffmpeg -hide_banner -loglevel error -y \
  -i "$RAW_VIDEO" -i "$RAW_AUDIO" -c copy "$FINAL_OUTPUT"

# Upload output
echo "Uploading to BDoDrive:Here/Vid/$BASENAME.mp4..."
rclone copy "$FINAL_OUTPUT" "BDoDrive:Here/Vid" --progress

echo "Finished: $BASENAME.mp4"
