#!/usr/bin/env python
# -*- coding: utf-8 -*-

import logging
from argparse import ArgumentParser

logging.basicConfig(format='%(asctime)s %(levelname)s: %(message)s',
                    datefmt='%m/%d/%Y %I:%M:%S %p', level=logging.DEBUG)


def separate(input_files, src_lang, trg_lang,
             indices_file, n_clusters=4):
    # open the input files to read lines from
    # and a file from which to read the cluster indices
    with open(f'{input_files}.{src_lang}',
              'r', encoding='utf8') as in_src_fh, \
            open(f'{input_files}.{trg_lang}',
                 'r', encoding='utf8') as in_trg_fh, \
            open(indices_file, 'r', encoding='utf8') as in_cluster_fh:
        # for each cluster id, open src and trg output files
        src_out_files = [open(f'{input_files}_cluster{i}.{src_lang}', 'w', encoding='utf8')
                         for i in range(n_clusters)]
        trg_out_files = [open(f'{input_files}_cluster{i}.{trg_lang}', 'w', encoding='utf8')
                         for i in range(n_clusters)]

        # iterate over input lines
        for src_line in in_src_fh:
            trg_line = in_trg_fh.readline()
            src, trg = src_line.strip(), trg_line.strip()
            # read the cluster ID from file
            cluster_id = int(in_cluster_fh.readline().strip())
            # write lines into corresponding files
            src_out_files[cluster_id].write(src + '\n')
            trg_out_files[cluster_id].write(trg + '\n')

        # close output files
        for fh in src_out_files:
            fh.close()
        for fh in trg_out_files:
            fh.close()


# def restore_cluster_order(loc, input_files, cluster_mode_name,
#                           src_lang, trg_lang, n_clusters=4):
#     # iterate over input lines
#     for filename in input_files:
#         # create src and trg lines where we will save lines in cluster order
#         # (first the whole cluster 0, then 1, etc.)
#         with open(f'{filename}.{cluster_mode_name}_{n_clusters}_'
#                   f'clusterorder.{src_lang}',
#                   'w', encoding='utf8') as src_clusterorder_fh, \
#                 open(f'{filename}.{cluster_mode_name}_{n_clusters}_'
#                      f'clusterorder.{trg_lang}',
#                      'w', encoding='utf8') as trg_clusterorder_fh:
#             # iterate over clusters
#             for cluster in [str(i) for i in range(n_clusters)]:
#                 # open the cluster file and write all of its lines into
#                 # the cluster order file
#                 with open(
#                         f'{filename}.{cluster_mode_name}_'
#                         f'{n_clusters}_cluster{cluster}.{src_lang}',
#                         'r', encoding='utf8') as cluster_src_fh:
#                     for line in cluster_src_fh:
#                         src_clusterorder_fh.write(line.strip() + '\n')
#                 with open(
#                         f'{filename}.{cluster_mode_name}_'
#                         f'{n_clusters}_cluster{cluster}.{trg_lang}',
#                         'r', encoding='utf8') as cluster_trg_fh:
#                     for line in cluster_trg_fh:
#                         trg_clusterorder_fh.write(line.strip() + '\n')


def make_argument_parser():
    parser = ArgumentParser()
    parser.add_argument("--input-file", type=str,
                        help="Input filename, without the language extensions")
    parser.add_argument("--indices", type=str,
                        help="File containing cluster indices, "
                             "in the same order as the input parallel files "
                             "they correspond to")
    parser.add_argument("--src-lang", help="Source language")
    parser.add_argument("--trg-lang", help="Target language")
    parser.add_argument("--n-clusters", type=int,
                        help="Number of clusters")

    return parser


if __name__ == '__main__':
    # Parse arguments
    argument_parser = make_argument_parser()
    args = argument_parser.parse_args()

    logging.info("Separating according to given indices")
    indices = args.indices

    # separate into random clusters
    separate(input_files=args.input_file,
             src_lang=args.src_lang, trg_lang=args.trg_lang,
             indices_file=indices,
             n_clusters=args.n_clusters)
    logging.info(f"Result files saved into {args.input_file}_clusterX.{args.src_lang} "
                 f"and {args.input_file}_clusterX.{args.trg_lang}, where X is the cluster ID")

    # # save files in cluster order
    # restore_cluster_order(loc=args.path_to_files, input_files=args.input_files,
    #                       cluster_mode_name=mode_name, src_lang=args.src_lang,
    #                       trg_lang=args.trg_lang, n_clusters=args.n_clusters)
    # logging.info(f"Lines in cluster order saved into {args.path_to_files}/"
    #              f"FILENAME.{mode_name}_{args.n_clusters}_clusterorder.LANG")
