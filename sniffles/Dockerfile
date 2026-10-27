FROM python:3.12-slim

RUN apt-get update && apt-get -y install \
    git \
    procps \
    && \
    rm -rf /var/lib/apt/lists/*


ARG REPO_TAG=38d8f868a502c49f3ec0dfa7e3020a2c1e6992d2

RUN pip install git+https://github.com/awgymer/Sniffles.git@${REPO_TAG}
