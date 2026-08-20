FROM python:3.11-slim

RUN apt-get update && apt-get -y install \
    git \
    procps \
    && \
    rm -rf /var/lib/apt/lists/*


ARG REPO_TAG=34beb6ccced740b1c0710160b904465730f4167d

RUN pip install git+https://github.com/awgymer/cuteSV.git@${REPO_TAG}
