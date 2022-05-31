#!/bin/bash
##
# Separate parallel files into cluster files according to given indices
#

set -x
set -euo pipefail

test -v SRC
test -v TRG

input_data=$1
indices=$2
n_clusters=$3
cluster_data_dir=$4

tmp="${cluster_data_dir}/tmp"
mkdir -p "${tmp}"

echo "### Separating ${input_data} into clusters according to indices in ${indices}"

# temporarily uncompress input corpus
pigz -dc "${input_data}.${SRC}.gz" > "${tmp}/corpus.${SRC}"
pigz -dc "${input_data}.${TRG}.gz" > "${tmp}/corpus.${TRG}"

# separate corpus into multiple cluster files
python pipeline/clusters/separate_clusters.py \
      --input-file "${tmp}/corpus" --indices "${indices}" \
      --src-lang "${SRC}" --trg-lang "${TRG}" --n-clusters "${n_clusters}"

# compress results and move to cluster directory
for ((i=0;i<n_clusters;i++))
do
  pigz -c "${tmp}/corpus_cluster${i}.${SRC}" > "${cluster_data_dir}/corpus_cluster${i}.${SRC}.gz"
  pigz -c "${tmp}/corpus_cluster${i}.${TRG}" > "${cluster_data_dir}/corpus_cluster${i}.${TRG}.gz"
done

# remove temp files
rm -rf "${tmp}"

echo "### Done: Separated ${input_data} into clusters, saved into ${cluster_data_dir}/corpus_clusterX.lang.gz"
