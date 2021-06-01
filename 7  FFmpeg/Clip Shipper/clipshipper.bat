@echo off
:: Hardware acceleration
:: Available options (same as in ffmpeg -hwaccel):
:: cpu (none)
:: NVIDIA (NVDEC/ENC)
:: AMD (d3d11va+AMF)
:: Intel (d3d11va+QSV)
:: any other hwaccel
:: Available codecs:
:: HEVC
:: H264
::
set hwaccel=cpu
set codec=HEVC
set cpupreset=veryfast
set enablecpuwarning=yes
::
:: ADVANCED OPTIONS
:: Be careful, only change them if you know what they do!
::
set audioencoderopts=-c:a libopus -b:a 320k
set container=mkv
set forcepreset=no
set forcequality=no
set presetcommand=-preset 
set forcedencoderopts=no
set customvideofilters=,mpdecimate=max=6
:: DON'T TOUCH ANYTHING BEYOND THIS POINT
color 0f
:: Input check
if %1check == check (
    echo ERROR: no input file
    echo Drag this .bat into the SendTo folder - press Windows + R and type in shell:sendto
    echo After that, right click on your video, drag over to Send To and click on this bat there.
    pause
    exit
)
:: CPU check
if %hwaccel% == cpu (
    if %enablecpuwarning% == yes (
        echo Warning: this script is using your CPU by default. Please open it and change hardware acceleration, or set enablecpuwarning to no.
        pause
    )
)
:: Questions
echo All times are in seconds
set /p audiofile=What audio file should be added? no to keep original audio: 
if NOT %audiofile% == no (
    set /p audiostarttime=Where do you want the audio file to start: 
    set /p weights=How loud do you want the music to be? 0-200, 100 is input clip volume: 
)
set /p starttime=Where do you want your clip to start: 
set /p time=How long should the clip be: 
set /p short=Should the clip be cropped to YouTube shorts size? yes or no: 
set /p upscaleto4k=Do you want to upscale to 4K? yes or no: 
set /p fadeintime=How long do you want the clip to fade in? 0 = disabled: 
set /p fadeouttime=How long do you want the clip to fade out? 0 = disabled: 
:: Encoder options
if %forcedencoderopts% == no (
    :: Choosing encoder
    if %hwaccel% == cpu (
        if %codec% == H264 (
            set encoderopts=-c:v libx264
            set encpreset=%cpupreset%
            set qualityarg=-crf
            set quality=16
        )
        if %codec% == HEVC (
            set encoderopts=-c:v libx265
            set encpreset=%cpupreset%
            set qualityarg=-crf
            set quality=18
        )
    )
    if %hwaccel% == NVIDIA (
        set hwaccelarg=-hwaccel cuda
        if %codec% == H264 (
            set encoderopts=-c:v h264_nvenc -rc constqp
            set encpreset=p7
            set qualityarg=-qp
            set quality=18
        )
        if %codec% == HEVC (
            set encoderopts=-c:v hevc_nvenc -rc constqp
            set encpreset=p7
            set qualityarg=-qp
            set quality=21
        )
    )
    if %hwaccel% == AMD (
        set hwaccelarg=-hwaccel d3d11va
        if %codec% == H264 (
            set encoderopts=-c:v h264_amf
            set encpreset=quality
            set quality=16
            set amd=yes
        )
        if %codec% == HEVC (
            set encoderopts=-c:v hevc_amf
            set encpreset=quality
            set quality=19
            set amd=yes
        )
    )
    if %hwaccel% == Intel (
        set hwaccelarg=-hwaccel d3d11va
        if %codec% == H264 (
            set encoderopts=-c:v h264_qsv
            set encpreset=veryslow
            set qualityarg=-global_quality:v
            set quality=18
        )
        if %codec% == HEVC (
            set encoderopts=-c:v hevc_qsv
            set encpreset=veryslow
            set qualityarg=-global_quality:v
            set quality=22
        )
    )
    :: Fuck you batch
    set recreatecommand=yes
) else (
    :: Ability to force encoder options
    set encoderarg=%forcedencoderopts%
    set recreatecommand=no
)
if NOT %forcepreset% == no (
    set encpreset=%forcepreset%
)
set globaloptions=-g 600
if %recreatecommand% == yes (
    if %amd%1 == yes1 (
        set encoderarg=%encoderopts% -qp_i %quality% -qp_p %quality% -qp_b %quality% %globaloptions% -quality %encpreset%
    ) else (
        set encoderarg=%encoderopts% %qualityarg% %quality% %globaloptions% %presetcommand% %encpreset%
    )
)
:: FFmpeg command creation
:: Input filters
set filterinput=[0:v]format=yuv420p[input]
set filterchaininput=input
:: Audio mix
if %audiofile% == no (
    set filteramix=
    set amixoutputname=0:a:0
) else (
    set filteramix=;[0:a:0][1:a:0]amix=inputs=2:duration=longest:normalize=1:weights='100 %weights%'[mixedaudio]
    set amixoutputname=mixedaudio
)
:: Cropping to Shorts size
if %short%0 == yes0 (
    set filtershorts=;[%filterchaininput%]crop='in_h*0.5625'[cropped]
    set shortsoutputname=cropped
) else (
    set filtershorts=
    set shortsoutputname=%filterchaininput%
)
:: Fading
:: Directions
set /A endfadestarttime=%time%-%fadeouttime%
if NOT %fadeintime%0 == 00 (
    set fadeinafilter=afade=t=in:st=0:d=%fadeintime%
    set fadeinvfilter=fade=t=in:st=0:d=%fadeintime%
)
if NOT %fadeouttime%0 == 00 (
    set fadeoutafilter=afade=t=out:st=%endfadestarttime%:d=%fadeouttime%
    set fadeoutvfilter=fade=t=out:st=%endfadestarttime%:d=%fadeouttime%
)
:: Final filter
:: Separates fade filters with , if both are enabled
if NOT %fadeouttime%0 == 00 (
    if NOT %fadeintime%0 == 00 (
        set fadefseparator=,
    )
)
:: Choosing if fading is enabled or not
if NOT %fadeouttime%0 == 00 (set fadeenabled=1)
if NOT %fadeintime%0 == 00 (set fadeenabled=1)
:: Actual filter
if %fadeenabled%0 == 10 (
    set filterfade=;[%shortsoutputname%]%fadeinvfilter%%fadefseparator%%fadeoutvfilter%[fadedvideo];[%amixoutputname%]%fadeinafilter%%fadefseparator%%fadeoutafilter%[fadedaudio]
    set fadeaoutputname=fadedaudio
    set fadevoutputname=fadedvideo
) else (
    set filterfade=
    set fadeaoutputname=%amixoutputname%
    set fadevoutputname=%shortsoutputname%
)
:: Upscaling to 4K
if %upscaleto4k% == yes (
    set filterupscale=;[%fadevoutputname%]scale=-2:2160:flags=neighbor[finalvideo]
    set upscaleoutputname=finalvideo
) else (
    set filterupscale=
    set upscaleoutputname=%fadevoutputname%
)
:: Audio input
if %audiofile% == no (
    set ainput=
) else (
    set ainput=-ss %audiostarttime% -t %time% -i %audiofile%
)
:: Mapping
if %fadeaoutputname% == 0:a:0 (
    set mapaudio=0:a:0
) else (
    set mapaudio=[%fadeaoutputname%]
)
set mapvideo=[%upscaleoutputname%]
:: Running
echo\
echo Encoding...
echo\
color 06
:: FFmpeg
ffmpeg -loglevel warning -stats %hwaccelarg% ^
-ss %starttime% -t %time% -i %1 %ainput% ^
%encoderarg% %audioencoderopts% ^
-filter_complex "%filterinput%%filteramix%%filtershorts%%filterfade%%filterupscale%" ^
-map "%mapaudio%" -map "%mapvideo%" ^
-vsync vfr -movflags +faststart ^
"%~dpn1 (shipped).%container%"
:: End
echo\
echo Done!
echo\
color 0A
pause