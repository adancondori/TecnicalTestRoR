# Steps RUN rails-api

docker build -f dev.dockerfile -t api .

docker run -p 3000:3000

docker run -it api /bin/bash 