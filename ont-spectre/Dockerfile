FROM python:3.11

RUN apt-get update && apt-get -y install \
    git \
    procps \
    && \
    rm -rf /var/lib/apt/lists/*


ARG REPO_TAG=72bdc950c3da01580d46b7df8ad9b81b38d43ced

# setuptools < 82 required for pkg_resources
RUN pip install "setuptools<82"
RUN pip install git+https://github.com/awgymer/ont-spectre.git@${REPO_TAG}
