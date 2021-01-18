#!/bin/python
"""Script to generate .klg files form SUN3D datases

This script converts a SUN3D dataset to the .klg file format.
The .klg file format is used by the reference implementations of Kintinuous, ElasticFusion and Co-Fusion.

Example:
    The script runs from the command line

        $ python3 SUN3DToKlg.py  ../mit_32_bikeroom/bikeroom_2/
        $ ./SUN3DToKlg.py ../mit_32_bikeroom/bikeroom_2/
        $ python3 SUN3DToKlg.py -o /tmp/output.klg ../mit_32_bikeroom/bikeroom_2/
        $ ./SUN3DToKlg.py -o /tmp/output.klg ../mit_32_bikeroom/bikeroom_2/

Attributes:
    path: Path to the dataset root

Todo:
    * Tests

"""

import glob
import re
import cv2
import numpy as np
import zlib
import argparse
from os import path
import errno

def convertToKlg(datasetPath, outputFile = './out.klg'):
    """
    convertToKlg: converts a SUN3D dataset to klg file format

    klg file formart:
    https://github.com/mp3guy/Logger1/
    """

    datasetPath = path.normpath(datasetPath)
    outputFile = path.normpath(outputFile)

    imgPath = path.join(datasetPath, 'rgb/')
    depthPath = path.join(datasetPath, 'depth/')

    if not (path.exists(imgPath) or path.exists(depthPath)):
        print("No valid SUN3D dataset found")
        exit(errno.ENOENT)

    imgFiles = sorted(glob.glob(path.join(imgPath, '*.png')))
    depthFiles = sorted(glob.glob(path.join(depthPath, '*.png')))

    # regular expression to extract id and timestamp
    regexPrg = re.compile(r"(?P<timestamp>\d+.\d+).(png|jpg)$");

    # build frame datastructure for RGB and depth images
    imgFrames = dict()
    for i, img in enumerate(imgFiles):
        res = regexPrg.search(img);
        imgFrames[i] = dict(
            timestamp = float(res.group('timestamp')),
            path = img
        )
    depthFrames = dict()
    for i, depth in enumerate(depthFiles):
        res = regexPrg.search(depth)
        depthFrames[i] = dict(
            timestamp = float(res.group('timestamp')),
            path = depth
        )

    # match RGB with depth
    for imgKey in imgFrames:
        currentMin = -1
        for depthKey in depthFrames:
            tmp = abs(depthFrames[depthKey]['timestamp'] - imgFrames[imgKey]['timestamp'])
            if currentMin > tmp or currentMin == -1:
               imgFrames[imgKey]['depthId'] = depthKey
               currentMin = tmp

    # write data to file
    with open(outputFile, 'wb') as output_file:
        count = int(len(imgFrames))
        output_file.write(count.to_bytes(4, byteorder="little", signed=True))

        for i, p in imgFrames.items():
            img = cv2.imread(p['path'])
            depth_path = depthFrames[p['depthId']]['path']
            depth = (cv2.imread(depth_path, cv2.IMREAD_UNCHANGED)/5.0)
            
            ret, encodedImage = cv2.imencode('.jpg', img, [cv2.IMWRITE_JPEG_QUALITY, 90, 0])

            depth = depth.astype('uint16')
            depthCompressed = zlib.compress(depth)

            """
            Fileformat:
                Format is:
                int64_t: timestamp
                int32_t: depthSize
                int32_t: imageSize
                unsigned char*: depth
                unsigned char*: img
            """

            imgSize = int(len(encodedImage.tobytes(order='c')))
            depthSize = int(len(depthCompressed))
            output_file.write((33333*i).to_bytes(8, byteorder="little", signed=True))
            output_file.write(depthSize.to_bytes(4, byteorder="little", signed=True))
            output_file.write(imgSize.to_bytes(4, byteorder="little", signed=True))
            output_file.write(depthCompressed)
            output_file.write(encodedImage.tobytes(order='c'))





if __name__ == '__main__':

    parser = argparse.ArgumentParser(description="Process path to SUN3D dataset")
    parser.add_argument('path', help='path to the dataset', nargs=1)
    parser.add_argument('-o', dest='file', nargs=1, required=False, default=['./out.klg'],
            help='output file')

    args = parser.parse_args()
    convertToKlg(args.path[0], args.file[0]);
