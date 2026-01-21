#!/bin/bash

# Convert MOV video to smaller, optimized GIF for GitHub
INPUT_FILE="warp-demo.mov"
OUTPUT_FILE="warp-demo-small.gif"
PALETTE_FILE="palette-small.png"

if [ ! -f "$INPUT_FILE" ]; then
	echo "Error: Input file '$INPUT_FILE' not found!"
	exit 1
fi

if ! command -v ffmpeg &>/dev/null; then
	echo "Error: ffmpeg is not installed. Please install it first."
	exit 1
fi

echo "Creating smaller GIF (optimized for GitHub)..."
echo "Settings: 800px width, 8 fps, optimized palette"

echo "Step 1: Generating optimized palette..."
ffmpeg -i "$INPUT_FILE" \
	-vf "fps=8,scale=800:-1:flags=lanczos,palettegen=stats_mode=diff" \
	-y "$PALETTE_FILE"

if [ $? -ne 0 ]; then
	echo "Error: Failed to generate palette"
	exit 1
fi

echo "Step 2: Creating optimized GIF..."
ffmpeg -i "$INPUT_FILE" \
	-i "$PALETTE_FILE" \
	-filter_complex "fps=8,scale=800:-1:flags=lanczos[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=3:diff_mode=rectangle" \
	"$OUTPUT_FILE"

if [ $? -eq 0 ]; then
	echo "Success! Optimized GIF created: $OUTPUT_FILE"
	ls -lh "$OUTPUT_FILE"
	echo "Cleaning up palette file..."
	rm "$PALETTE_FILE"
	echo ""
	echo "File size comparison:"
	echo "Original: $(ls -lh warp-demo.gif | awk '{print $5}')"
	echo "Optimized: $(ls -lh $OUTPUT_FILE | awk '{print $5}')"
else
	echo "Error: Failed to create GIF"
	exit 1
fi
