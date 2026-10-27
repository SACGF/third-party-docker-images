FROM python:3.12-slim

RUN apt-get update && apt-get -y install \
    git \
    procps \
    && \
    rm -rf /var/lib/apt/lists/*


ARG REPO_TAG=9bfef50d713a3355ace02f7d571c8e3dbf21dee2

RUN pip install git+https://github.com/awgymer/Sniffles.git@${REPO_TAG}
