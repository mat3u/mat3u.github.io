@echo off
for /f %%i in ('docker build . -q') do set JEKYLLIMG=%%i

docker rm --force jekyll
docker run --name jekyll -v %cd%:/srv/jekyll -p 4000:4000 %JEKYLLIMG%