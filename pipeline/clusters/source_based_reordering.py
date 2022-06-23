#!/usr/bin/env python
# -*- coding: utf-8 -*-

import os
import logging
from collections import Counter
from argparse import ArgumentParser

logging.basicConfig(format='%(asctime)s %(levelname)s: %(message)s',
                    datefmt='%m/%d/%Y %I:%M:%S %p', level=logging.DEBUG)


def match_order(orig_src, srcs, hyps):
    orig_src_lines = list_of_lines_from_file(orig_src)
    orig_src_lines_counter = Counter(orig_src_lines)
    if len(set(orig_src_lines)) != len(orig_src_lines):
        logging.warning("Duplicate lines in original source")
    all_srcs_dict = {}
    for src_sent in set(orig_src_lines):
        for i in range(orig_src_lines_counter[src_sent]):
            all_srcs_dict[str(i)+"_"+src_sent] = {n: None for n in range(len(srcs))}

    for i in range(len(srcs)):
        src_lines = list_of_lines_from_file(srcs[i])
        assert sorted(list(src_lines)) == sorted(list(orig_src_lines)), \
            "References do not match"
        hyp_lines = list_of_lines_from_file(hyps[i])

        src_lines_used = {line: 0 for line in set(src_lines)}
        for src_line, hyp_line in zip(src_lines, hyp_lines):
            all_srcs_dict[str(src_lines_used[src_line]) + "_" + src_line][i] = hyp_line
            src_lines_used[src_line] += 1

    return all_srcs_dict, orig_src_lines


def list_of_lines_from_file(filename):
    with open(filename, 'r', encoding='utf8') as fh:
        lines = [line.strip() for line in fh.readlines()]
    return lines


def write_output(all_srcs_dict, first_src_lines, hyp_names, out_path):
    first_src_lines_counter = Counter(first_src_lines)
    for i in range(len(hyp_names)):
        src_lines_used = {line: 0 for line in set(first_src_lines)}
        with open(os.path.join(out_path, hyp_names[i]), 'w',
                  encoding='utf8') as fh:
            for line in first_src_lines:
                fh.write(all_srcs_dict[str(src_lines_used[line]) + "_" + line][i] + '\n')
                src_lines_used[line] += 1

            assert dict(first_src_lines_counter) == src_lines_used, \
                "Reference counter does not match the written lines"


if __name__ == '__main__':
    # Parse arguments
    parser = ArgumentParser()
    parser.add_argument("--orig-src", required=True,
                        help="Source in original order")
    parser.add_argument("--srcs", required=True, nargs="+",
                        help="Scrambled source files")
    parser.add_argument("--hyps", required=True, nargs="+",
                        help="Scrambled hypothesis files")
    parser.add_argument("--hyp-names", required=True, nargs="+",
                        help="Filenames under which the reordered hypotheses"
                             "will be saved")
    parser.add_argument("--output-path", default="./",
                        help="Path to output files")

    args = parser.parse_args()

    assert (len(args.srcs) == len(args.hyps) == len(args.hyp_names)), \
        f"Number of hypotheses ({len(args.hyps)}), sources ({len(args.srcs)}) and " \
        f"output filenames ({len(args.hyp_names)}) does not match"

    srcs_dict, first_src = match_order(orig_src=args.orig_src, srcs=args.srcs, hyps=args.hyps)
    write_output(all_srcs_dict=srcs_dict, first_src_lines=first_src,
                 hyp_names=args.hyp_names, out_path=args.output_path)
