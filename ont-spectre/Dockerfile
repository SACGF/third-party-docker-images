FROM python:3.11

RUN apt-get update && apt-get -y install \
    git \
    procps \
    && \
    rm -rf /var/lib/apt/lists/*


ARG REPO_TAG=1d2887b4867db629b95f9ade52a8fc0c150a91c2

# setuptools < 82 required for pkg_resources
RUN pip install "setuptools<82"
RUN pip install git+https://github.com/awgymer/ont-spectre.git@${REPO_TAG}
