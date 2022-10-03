#!/bin/bash

nexus_repo=""
python_version="python3.6"

# Download certificates
curl -f ${nexus_repo} > /usr/local/lib/${python_version}/site-packages/certifi/cacert.pem
