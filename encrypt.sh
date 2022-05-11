#!/bin/bash
set -ex -o pipefail
INPUT_FILE=$1
OUTPUT_FILE=$(echo ${INPUT_FILE} | sed 's/.yaml$/.sops.yaml/' | sed 's/.yml$/.sops.yml/')

sops --encrypt --pgp 1997AA2DBF0982F972B61D91D127B098EF01F86D ${INPUT_FILE} > ${OUTPUT_FILE}
rm -f ${INPUT_FILE}