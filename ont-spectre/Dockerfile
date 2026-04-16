FROM python:3.12-slim

RUN apt-get update && apt-get -y install \
    git \
    procps \
    && \
    rm -rf /var/lib/apt/lists/*


ARG REPO_TAG=2f6eaebf48e5f4e4b65aca854235e74dab485fb7

RUN pip install git+https://github.com/awgymer/ont-spectre.git@${REPO_TAG}
