#!/bin/bash
set -ex -o pipefail
INPUT_FILE=$1
OUTPUT_FILE=$(echo ${INPUT_FILE} | sed 's/.sops.yaml$/.yaml/' | sed 's/.sops.yml$/.yml/')
sops --decrypt ${INPUT_FILE} > ${OUTPUT_FILE}
rm -f ${INPUT_FILE}