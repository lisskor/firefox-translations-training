#!/bin/bash
##
# Extract sentence representations for clustering
#

set -x
set -euo pipefail

input_data=$1
hf_teacher_dir=$2
batch_size=$3
layer_num=$4
output_filename=$5
caching_dir=$6

tmp="${hf_teacher_dir}/tmp"
mkdir -p "${tmp}"

echo "### Extracting sentence representations for ${input_data}"

# temporarily uncompress input data
pigz -dc "${input_data}" > "${tmp}/tmp_corpus.txt"

# extract representations from given layer
python 3rd_party/domain_clusters/extract_sentence_representations.py \
      --hf-model-dir "${hf_teacher_dir}" --txt-dataset-path "${tmp}/tmp_corpus.txt" \
      --batch-size "${batch_size}" --layer-num "${layer_num}" \
      --out-filename "${output_filename}" --caching-dir "${caching_dir}"--gpu

# remove uncompressed file
rm -rf "${tmp}"

echo "### Done: Extracted sentence representations for ${input_data}, saved into ${output_filename}"
