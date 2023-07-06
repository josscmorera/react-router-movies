#!/bin/bash

#  Function to communicate with API
# communicate_with_api() {
#     curl -d "id=${video_id}" -X POST "https://digiload.co/upload/video-encoded"
# }

# Function to handle errors
handle_error() {
    echo "An error occurred while executing the function at line: $1"
    exit 1
}

# Function to check if a command succeeded
check_command_success() {
    if [ $? -ne 0 ]; then
        handle_error $1
    fi
}

# Function to print usage
print_usage() {
    printf "Usage: $0 [-i inputfile] [-o output_directory] [-s segment_length]\n"
}

# Basic config
output_directory=${output_directory:-'./output'} 

# Change this if you want to specify a path to use a specific version of FFMPeg
ffmpeg=${ffmpeg:-'ffmpeg'}  

# Number of threads which will be used for transcoding. For CPU, use number of cores.
numthreads=${numthreads:-"32"}  

# Video codec for the output video. Will be used as an value for the -vcodec argument
video_codec=${video_codec:-"libx265"}  

# Audio codec for the output video. Will be used as an value for the -acodec argument
audio_codec=${audio_codec:-"aac"}  

# Additional flags for ffmpeg
ffmpeg_flags=${ffmpeg_flags:-"-strict -2 -ac 2 -sc_threshold 0 -tune animation -x265-params deblock=1,1:b-adapt=1:weightb=1:8x8dct=1:trellis=2:mixed_ref=1:b-pyramid=2:direct=3:partitions=i4x4,i8x8,p8x8,b8x8 -me_method umh -subq 8 -aq-mode 3 -pix_fmt yuv420p"}

# If the input is a live stream (i.e. linear video) this should be 1
live_stream=${live_stream:-0}  

# Video bitrates to use in output (comma separated list if you want to create an adaptive stream.)
# leave null to use the input bitrate
op_bitrates=${op_bitrates:-''}   

# Determines whether the processing for adaptive streams should run sequentially or not
no_fork=${no_fork:-0}   

# Path Prefix (Not incl. Key)
path_prefix=${path_prefix:-''}  

# Key Path Prefix 
key_prefix=${key_prefix:-''}

# Error handling
trap 'handle_error $LINENO' ERR

# Check we've got the arguments we need
if [[ -z "$inputfile" ]] || [[ -z "$seglength" ]]
then
    print_usage
fi

# FFMpeg is a pre-requisite, so let's check for it
if hash $ffmpeg 2> /dev/null
then
    # FFMpeg exists
    printf "ffmpeg command found.... continuing\n"
else
    # FFMPeg doesn't exist, uh-oh!
    printf "Error: FFmpeg doesn't appear to exist in your PATH. Please address and try again\n"
    exit 1
fi

# Check whether the input is a named pipe
if [[ -p "$inputfile" ]] 
then
    printf "Warning: Input is FIFO - EXPERIMENTAL\n"
    is_fifo=1
fi

# Make sure that the trailing slashes are added
if [[ -n "$path_prefix" ]] && [[ "${path_prefix:$length:1}" != "/" ]]
then
    path_prefix+="/"
fi

if [[ -n "$key_prefix" ]] && [[ "${key_prefix:$length:1}" != "/" ]]
then
    key_prefix+="/"
fi

# Check output directory exists otherwise create it 
if [[ ! -w $output_directory ]]
then
    printf "Creating $output_directory\n"
    mkdir -p $output_directory
    check_command_success $LINENO
fi 

createStream () {
    playlist_name="$1"
    output_name="$2"
    bitrate="$3"
    infile="$4"
    
    key_frames_interval="$(echo `ffprobe ${infile} 2>&1 | grep -oE '[[:digit:]]+(.[[:digit:]]+)? fps' | grep -oE '[[:digit:]]+(.[[:digit:]]+)?'`*2 | bc || echo '')"
    key_frames_interval=${key_frames_interval:-50}
    key_frames_interval=$(echo `printf "%.1f\n" $(bc -l <<<"$key_frames_interval/10")`*10 | bc) # round
    key_frames_interval=${key_frames_interval%.*} # truncate to integer
    
    if [ "$bit_depth" == "8" ]
    then
        ffmpeg_codec="h264_cuvid"
    else
        ffmpeg_codec="hevc_cuvid"
    fi

    local passvar=
    if $twopass; then
        local logfile="$output_directory/bitrate$br"
        passvar="-passlogfile \"$logfile\" -pass 2"
        
        $ffmpeg -i "$infile" \
        -pass 1 \
        -passlogfile "$logfile" \
        -an \
        -vcodec libx264 \
        -f mpegts \
        -g $key_frames_interval \
        -keyint_min $key_frames_interval \
        $bitrate \
        $resolution \
        $ffmpeg_additional \
        -loglevel error -y \
        /dev/null
    fi
    
    if [ "$bit_depth" == "8" ] && [ "$video_format" != "MPEG-4 Visual" ]
    then
        $ffmpeg -hide_banner -hwaccel_device 0 -hwaccel nvdec -c:v $ffmpeg_codec -i "$infile" \
        $passvar \
        -y \
        -max_muxing_queue_size 1024 \
        -threads "$numthreads" \
        -codec:v "$video_codec" \
        -codec:a "$audio_codec" \
        -map 0:v \
        -map 0:a? \
        -flags \
        -global_header \
        -f segment \
        -segment_list "$playlist_name" \
        -segment_time "$seglength" \
        -segment_format mpeg_ts \
        -g "$key_frames_interval" \
        -keyint_min "$key_frames_interval" \
        $resolution \
        $bitrate \
        $ffmpeg_additional \
        $ffmpeg_flags \
        "$output_directory/$output_name"
    else
        $ffmpeg -hide_banner -hwaccel_device 0 -hwaccel nvdec -i "$infile" \
        $passvar \
        -y \
        -max_muxing_queue_size 1024 \
        -threads "$numthreads" \
        -codec:v "$video_codec" \
        -codec:a "$audio_codec" \
        -map 0:v \
        -map 0:a? \
        -flags \
        -global_header \
        -f segment \
        -segment_list "$playlist_name" \
        -segment_time "$seglength" \
        -segment_format mpeg_ts \
        -g "$key_frames_interval" \
        -keyint_min "$key_frames_interval" \
        $resolution \
        $bitrate \
        $ffmpeg_additional \
        $ffmpeg_flags \
        "$output_directory/$output_name"
    fi
}


createVariantPlaylist () {
    playlist_name="$1"
    echo "#EXTM3U" > "$playlist_name"
}


appendVariantPlaylistentry () {
    playlist_name=$1
    playlist_path=$2
    bw_statement=$3
    m3u8_resolution=''
    
    if [[ "$bw_statement" == *"-"* ]]
    then
        m3u8_resolution=",RESOLUTION=$(echo "$bw_statement" | cut -d- -f2)"
        bw_statement=$(echo "$bw_statement" | cut -d- -f1)
    fi
    
    playlist_bw=$(( $bw_statement * 1000 )) # bits not bytes :)
    
cat << EOM >> "$playlist_name"
#EXT-X-STREAM-INF:BANDWIDTH=$playlist_bw$m3u8_resolution
$path_prefix$playlist_path
EOM
    
}


awaitCompletion () {
    # Monitor the encoding pids for their completion status
    while [ ${#PIDS[@]} -ne 0 ]; do
        # Calculate the length of the array
        pid_length=$((${#PIDS[@]} - 1))
        
        # Check each PID in the array
        for i in `seq 0 $pid_length`
        do
            # Test whether the pid is still active
            if ! kill -0 ${PIDS[$i]} 2> /dev/null
            then
                echo "Encoding for bitrate ${BITRATE_PROCESSES[$i]}k completed"
                
                if [ "$live_stream" == "1" ] && [ `grep 'EXT-X-ENDLIST' "$output_directory/${playlist_prefix}_${BITRATE_PROCESSES[$i]}.m3u8" | wc -l ` == "0" ]
                then
                    # Correctly terminate the manifest. See HLS-15 for info on why
                    echo "#EXT-X-ENDLIST" >> "$output_directory/${playlist_prefix}_${BITRATE_PROCESSES[$i]}.m3u8"
                fi
                
                unset BITRATE_PROCESSES[$i]
                unset PIDS[$i]
            fi
        done
        PIDS=("${PIDS[@]}") # remove any nulls
        BITRATE_PROCESSES=("${BITRATE_PROCESSES[@]}") # remove any nulls
        sleep 1
    done
}

encrypt () {
    # Encrypt the generated segments with AES-128 bits
    
    
    # Only run the encryption routine if it's been enabled  (and not blocked)
    if [ ! "$ENCRYPT" == "1" ] || [ "$live_stream" == "1" ]
    then
        return
    fi
    
    echo "Generating Encryption Key"
    KEY_FILE="$output_directory/${KEY_NAME}.key"
    
    openssl rand 16 > $KEY_FILE
    ENCRYPTION_KEY=$(cat $KEY_FILE | hexdump -e '16/1 "%02x"')
    
    echo "Encrypting Segments"
    for SEGMENT_FILE in ${output_directory}/*.ts
    do
        SEG_NO=$( echo "$SEGMENT_FILE" | grep -o -P '_[0-9]+\.ts' | tr -dc '0-9' )
        ENC_FILENAME="$output_directory/${SEGMENT_PREFIX}_enc_${SEG_NO}".ts
        
        # Strip leading 0's so printf doesn't think it's octal
        #SEG_NO=${SEG_NO##+(0)} # Doesn't work for some reason - need to check shopt to look further into it
        SEG_NO=$(echo $SEG_NO | sed 's/^0*//' )
        
        # Convert the segment number to an IV.
        INIT_VECTOR=$(printf '%032x' $SEG_NO)
        openssl aes-128-cbc -e -in $SEGMENT_FILE -out $ENC_FILENAME -nosalt -iv $INIT_VECTOR -K $ENCRYPTION_KEY
        
        # Move encrypted file to the original filename, so that the m3u8 file does not have to be changed
        mv $ENC_FILENAME $SEGMENT_FILE
        
    done
    
    echo "Updating Manifests"
    # this isn't technically correct as we needn't write into the master, but should still work
    for manifest in ${output_directory}/*.m3u8
    do
        # Insert the KEY at the 5'th line in the m3u8 file
        sed -i "5i #EXT-X-KEY:METHOD=AES-128,URI=\""${key_prefix}${KEY_NAME}.key"\"" "$manifest"
    done
}

# This is used internally, if the user wants to specify their own flags they should be
# setting FFMPEG_FLAGS
ffmpeg_additional=''
live_segment_count=0
is_fifo=0
tmpdir=${tmpdir:-"/tmp"}
mypid=$$
twopass=false
quality=
constant=false
# Get the input data

# This exists to maintain b/c
legacy_args=1

# If even one argument is supplied, switch off legacy argument style
while getopts "i:o:s:c:b:p:t:S:q:u:k:K:v:m:Clfe2" flag
do
    legacy_args=0
    case "$flag" in
        i) inputfile="$OPTARG";;
        o) output_directory="$OPTARG";;
        s) seglength="$OPTARG";;
        v) video_id="$OPTARG";;
        m) cloud_output="$OPTARG";;
        l) live_stream=1;;
        c) live_segment_count="$OPTARG";;
        b) op_bitrates="$OPTARG";;
        f) no_fork=1;;
        p) playlist_prefix="$OPTARG";;
        t) segment_prefix="$OPTARG";;
        S) segment_directory="$OPTARG";;
        e) encrypt=1;;
        2) twopass=true;;
        q) quality="$OPTARG";;
        C) constant=true;;
        u) path_prefix="$OPTARG";;
        k) key_prefix="$OPTARG";;
        K) key_name="$OPTARG";;
    esac
done


if [ "$legacy_args" == "1" ]
then
    # Old Basic Usage is
    # cmd.sh inputfile segmentlength
    
    inputfile=${inputfile:-$1}
    seglength=${seglength:-$2}
    if ! [ -z "$3" ]
    then
        output_directory=$3
    fi
fi


# Check we've got the arguments we need
if [[ -z "$inputfile" ]] || [[ -z "$seglength" ]]
then
    print_usage
    exit 1
fi

# FFMpeg is a pre-requisite, so let check for it
if hash $ffmpeg 2> /dev/null
then
    # FFMpeg exists
    printf "ffmpeg command found.... continuing\n"
else
    # FFMPeg doesn't exist, uh-oh!
    printf "Error: FFmpeg doesn't appear to exist in your PATH. Please address and try again\n"
    exit 1
fi

# Check whether the input is a named pipe
if [ -p "$inputfile" ]
then
    printf "Warning: Input is FIFO - EXPERIMENTAL\n"
    is_fifo=1
fi

# Make sure that the trailing slashes are added
if [ "$path_prefix" != "" ] && [ "${path_prefix:$length:1}" != "/" ]
then
    path_prefix+="/"
fi

if [ "$key_prefix" != "" ] && [ "${key_prefix:$length:1}" != "/" ]
then
    key_prefix+="/"
fi

# Check output directory exists otherwise create it
if [ ! -w $output_directory ]
then
    printf "Creating $output_directory\n"
    mkdir -p $output_directory
    check_command_success $LINENO
fi

if [ "$live_stream" == "1" ]
then
    ffmpeg_additional+="-segment_list_flags +live"
    
    if [ "$live_segment_count" -gt 0 ]
    then
        wrap_point=$(($live_segment_count * 2)) # Wrap the segment numbering after 2 manifest lengths - prevents disks from filling
        ffmpeg_additional+=" -segment_list_size $live_segment_count -segment_wrap $wrap_point"
    fi
fi


# Pulls file name from inputfile which may be an absolute or relative path.
inputfilename=${inputfile##*/}

# MEDIAINFO
media_info=$(echo `mediainfo --Inform="Video;%BitDepth%~%Format%" ${inputfile}`)
bit_depth=$(echo "$media_info" | cut -d~ -f1)
video_format=$(echo "$media_info" | cut -d~ -f2)

# If a prefix hasn't been specified, use the input filename
playlist_prefix=${playlist_prefix:-$inputfilename}
segment_prefix=${segment_prefix:-$playlist_prefix}
key_name=${key_name:-$playlist_prefix}

# The 'S' option allows segments and bitrate specific manifests to be placed in a subdir
segment_directory=${segment_directory:-''}

if [ ! "$segment_directory" == "" ]
then
    
    if [ ! -d "${output_directory}/${segment_directory}" ]
    then
        mkdir "${output_directory}/${segment_directory}"
        check_command_success $LINENO
    fi
    
    segment_directory+="/"
    output_directory+="/"
fi

# Set the bitrate
if [ ! "$op_bitrates" == "" ]
then
    # Make the bitrate list easier to parse
    op_bitrates=${op_bitrates//,/$'\n'}
    
    # Create an array to house the pids for backgrounded tasks
    declare -a PIDS
    declare -a BITRATE_PROCESSES
    
    # Get the variant playlist created
    createVariantPlaylist "$output_directory/${playlist_prefix}_master.m3u8"
    for br in $op_bitrates
    do
        bw=$br
        if [[ "$br" == *"-"* ]]
        then
            bw=$(echo "$br" | cut -d- -f1)
        fi
        
        appendVariantPlaylistentry "$output_directory/${playlist_prefix}_master.m3u8" "${segment_directory}${playlist_prefix}_${bw}.m3u8" "$br"
    done
    
    output_directory+=$segment_directory
    
    # Now for the longer running bit, transcode the video
    for br in $op_bitrates
    do
        
        # Check whether there's a resolution included in the bitrate string
        #
        # See HLS-27
        if [[ "$br" == *"-"* ]]
        then
            if [ "$bit_depth" == "8" ]
            then
                resolution="-vf hwupload_cuda,scale_npp=-2:720:format=nv12:interp_algo=lanczos,hwdownload,format=nv12"
            else
                resolution="-vf scale=-2:720"
            fi
            br=$(echo "$br" | cut -d- -f1)
        fi
        
        if [ -z $quality ]; then
            if $constant; then
                bitrate="-b:v ${br}k -bufsize ${br}k -minrate ${br}k -maxrate ${br}k"
            else
                bitrate="-b:v ${br}k"
            fi
        else
            maxrate="$(echo "`echo ${br} | grep -oE '[[:digit:]]+'`*1.07" | bc)"
            bufsize="$(echo "`echo ${br} | grep -oE '[[:digit:]]+'`*1.5" | bc)"
            bitrate="-cq $quality -maxrate ${maxrate}k -bufsize ${bufsize}k"
            if [ $video_codec = "libx265" ]; then
                bitrate="$bitrate -x265-params --vbv-maxrate ${br}k --vbv-bufsize ${br}k"
            fi
        fi
        echo "Bitrate options: $bitrate"
        # Finally, lets build the output filename format
        out_name="${segment_prefix}_${br}_%05d.ts"
        playlist_name="$output_directory/${playlist_prefix}_${br}.m3u8"
        source_file="$inputfile"
        echo "Generating HLS segments for bitrate ${br}k - this may take some time"
        echo "Bit Depth: $bit_depth"
        echo "Video Format: $video_format"

        if [ "$no_fork" == "0" ] || [ "$live_stream" == "1" ]
        then
            # Processing Starts
            if [ "$is_fifo" == "1" ]
            then
                # Create a FIFO specially for this bitrate
                source_file="$tmpdir/hlsc.encode.$mypid.$br"
                mknod "$source_file" p
            fi
            
            # Schedule the encode
            createStream "$playlist_name" "$out_name" "$bitrate" "$source_file" &
            PID=$!
            PIDS=(${PIDS[@]} $PID)
            BITRATE_PROCESSES=(${BITRATE_PROCESSES[@]} $br)
        else
            createStream "$playlist_name" "$out_name" "$bitrate" "$source_file"
        fi
        
    done
    
    if [ "$is_fifo" == "1" ]
    then
        # If the input was a FIFO we need to read from it and push into the new FIFOs
        cat "$inputfile" | tee $(for br in $op_bitrates; do echo "$tmpdir/hlsc.encode.$mypid.$br"; done) > /dev/null &
        tee_pid=$!
    fi
    
    if [ "$no_fork" == "0" ] || [ "$live_stream" == "1" ]
    then
        # Monitor the background tasks for completion
        echo "All transcoding processes started, awaiting completion"
        awaitCompletion
        
        # As of HLS-20 encrypt will only run if the relevant vars are set
        encrypt
        
#         #communicate with API
#         curl -d "id=${video_id}" -X POST "https://digiload.co/upload/video-encoded"
   fi
    
#     if [ "$is_fifo" == "1" ]
#     then
#         for br in $op_bitrates
#         do
#             rm -f "$tmpdir/hlsc.encode.$mypid.$br";
#         done
#         # If we were interrupted, tee may still be running
#         kill $tee_pid 2> /dev/null
#     fi
    
#     gsutil -m cp -r "streams/${video_id}" gs://${cloud_output}
#     rm -rf "streams/${video_id}"
#     curl -d "id=${video_id}" -X POST "https://digiload.co/upload/video-encoded"
    
# else
    
#     output_directory+=$segment_directory
#     # No bitrate specified
    
#     # Finally, lets build the output filename format
#     out_name="${segment_prefix}_%05d.ts"
#     playlist_name="$output_directory/${playlist_prefix}.m3u8"
    
#     echo "Generating HLS segments - this may take some time"
    
#     # Processing Starts
    
#     createStream "$playlist_name" "$out_name" "$bitrate" "$inputfile"
#     gsutil -m cp -r "streams/${video_id}" gs://${cloud_output}
#     rm -rf "streams/${video_id}"
#     #communicate with API
#     curl -d "id=${video_id}" -X POST "https://digiload.co/upload/video-encoded"
    
#     # As of HLS-20 encrypt will only run if the relevant vars are set
#     encrypt
# fi