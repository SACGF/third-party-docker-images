FROM python:3.12-slim

RUN apt-get update && apt-get -y install \
    git \
    procps \
    && \
    rm -rf /var/lib/apt/lists/*


ARG REPO_TAG=905809435a6bb00aa413a4cf4d4424365112a0af

RUN pip install numpy<2
RUN pip install git+https://github.com/fritzsedlazeck/Spectre.git@${REPO_TAG}
