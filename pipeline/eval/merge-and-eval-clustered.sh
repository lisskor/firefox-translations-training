#!/bin/bash
##
# Evaluate a model on GPU.
#

set -x
set -euo pipefail

echo "###### Evaluation of a model"

res_prefix=$1
original_source=$2
original_reference=$3
src=$4
trg=$5
input_prefixes=( "${@:6}" )

tmp="${res_prefix}/tmp"
mkdir -p "${tmp}"

echo "### Merging clustered parts into one dataset"

# Merge all clusters into one file (source and hypothesis)
cat "${input_prefixes[@]/%/.${src}}" > "${tmp}/cluster_order.${src}"
cat "${input_prefixes[@]/%/.${trg}}" > "${tmp}/cluster_order.${trg}"

# Copy reference in original order to result location
pigz -dc "${original_source}" > "${res_prefix}.${src}"
pigz -dc "${original_reference}" > "${res_prefix}.${trg}.ref"

python pipeline/clusters/source_based_reordering.py --orig-src "${res_prefix}.${src}" \
    --srcs "${tmp}/cluster_order.${src}" --hyps "${tmp}/cluster_order.${trg}" --hyp-names "${res_prefix}.${trg}"

sacrebleu "${res_prefix}.${trg}.ref" -i "${res_prefix}.${trg}" -d -f text --score-only -l "${src}-${trg}" -m bleu chrf  |
  tee "${res_prefix}.metrics"

rm -rf "${tmp}"
