#!/usr/bin/env python
# -*- coding: utf-8 -*-

import os
import logging
from argparse import ArgumentParser

logging.basicConfig(format='%(asctime)s %(levelname)s: %(message)s',
                    datefmt='%m/%d/%Y %I:%M:%S %p', level=logging.DEBUG)


def create_symlinks(files_list, links_list):
    for filename, link in zip(files_list, links_list):
        if not os.path.isdir(os.path.dirname(link)):
            os.makedirs(os.path.dirname(link))
        os.symlink(filename, link)


if __name__ == '__main__':
    # Parse arguments
    parser = ArgumentParser()
    parser.add_argument("--files", nargs="+",
                        help="Input filenames, without the language and .gz extensions")
    parser.add_argument("--links", nargs="+",
                        help="Corresponding link paths, without the language and .gz extensions")
    args = parser.parse_args()

    # Check that lists have the same length
    assert len(args.files) == len(args.links), "Number of files does not match number of links"

    logging.info("Creating symlinks")
    create_symlinks(args.files, args.links)
