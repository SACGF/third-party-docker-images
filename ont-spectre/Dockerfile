FROM python:3.11

RUN apt-get update && apt-get -y install \
    git \
    procps \
    && \
    rm -rf /var/lib/apt/lists/*


ARG REPO_TAG=2f6eaebf48e5f4e4b65aca854235e74dab485fb7

# setuptools < 82 required for pkg_resources
RUN pip install "setuptools<82"
RUN pip install git+https://github.com/awgymer/ont-spectre.git@${REPO_TAG}
