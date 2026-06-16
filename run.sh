#!/bin/sh
set -e
if [ ! -f /db/ffplayout.db ]; then
    ffplayout -i \
        -u "${FFPLAYOUT_ADMIN_USER:-admin}" \
        -p "${FFPLAYOUT_ADMIN_PASS:-admin}" \
        -m "${FFPLAYOUT_ADMIN_EMAIL:-admin@memepipe.tv}" \
        --storage /tv-media \
        --playlists /playlists \
        --public /public \
        --logs /logging \
        --smtp-server "" --smtp-user "" --smtp-password "" --smtp-port 0 --smtp-starttls false
fi

# Pin channel 1's output to the MediaMTX RTMP ingest with stream-copy.
# RTMP beat the alternatives:
#   - RTSP trips "AAC with no global headers" because ffplayout's
#     decoder pipes through MPEG-TS (AAC in ADTS) and ffmpeg's RTSP
#     muxer won't reconstruct the MP4 AudioSpecificConfig fast enough
#     for the writer. aac_adtstoasc alone didn't fix it.
#   - SRT/MPEG-TS drops Opus in this MediaMTX build and hits "frame is
#     too big" packetization issues on large keyframes.
#   - FLV/RTMP carries AAC's config in-band (Sequence Header tag), so
#     stream-copy works cleanly for H.264 + AAC.
#
# Stream mode is selected via configurations.output_id=2 ("stream" row
# in outputs). Running the UPDATE every boot keeps the params matched
# to whatever the compose network expects.
#
# MediaMTX now requires a password to publish (see configs/mediamtx/
# mediamtx.yml authInternalUsers). MediaMTX reads RTMP credentials from
# the URL QUERY STRING (?user=&pass=), NOT the user:pass@host userinfo
# form — ffmpeg sends userinfo but MediaMTX ignores it, so userinfo
# silently fails auth. The credential is STREAM_PUBLISH_PASS from
# docker/.env, the same secret mediamtx gets (single source, can't
# drift). user is "publisher". Keep the secret hex/alphanumeric: it's
# interpolated into the single-quoted SQL UPDATE below, so a quote (or a
# space) would break it.
RTMP_PARAMS="-c copy -f flv rtmp://mediamtx:1935/live?user=publisher&pass=${STREAM_PUBLISH_PASS}"
sqlite3 /db/ffplayout.db \
    "UPDATE outputs SET parameters = '${RTMP_PARAMS}' WHERE id = 2;
     UPDATE configurations SET output_id = 2 WHERE channel_id = 1;"

exec /usr/bin/ffplayout -l 0.0.0.0:8787
