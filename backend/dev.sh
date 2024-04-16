docker build -f dev.dockerfile -t api . &&
docker run -p 3000:3000 -v $(pwd):/rails api