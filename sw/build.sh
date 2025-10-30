set -e

cd mpeg_audio
make clean
make -j10
cd ..

cd mpeg_video
make clean
make -j10
cd ..

