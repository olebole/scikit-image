"""
`reconstruction_loop` originally part of CellProfiler, code licensed under both GPL and BSD licenses.

Website: http://www.cellprofiler.org
Copyright (c) 2003-2009 Massachusetts Institute of Technology
Copyright (c) 2009-2011 Broad Institute
All rights reserved.
Original author: Lee Kamentsky

"""

from __future__ import division
import numpy as np

cimport numpy as np
cimport cython


@cython.boundscheck(False)
def reconstruction_loop(np.ndarray[dtype=np.uint32_t, ndim=1,
                                   negative_indices=False, mode='c'] avalues,
                        np.ndarray[dtype=np.int32_t, ndim=1,
                                   negative_indices=False, mode='c'] aprev,
                        np.ndarray[dtype=np.int32_t, ndim=1,
                                   negative_indices=False, mode='c'] anext,
                        np.ndarray[dtype=np.int32_t, ndim=1,
                                   negative_indices=False, mode='c'] astrides,
                        np.int32_t current,
                        int image_stride):
    """The inner loop for reconstruction.

    This algorithm uses the rank-order of pixels. If low intensity pixels have
    a low rank and high intensity pixels have a high rank, then this loop
    performs reconstruction by dilation. If this ranking is reversed, the
    result is reconstruction by erosion.

    For each pixel in the seed image, check its neighbors. If its neighbor's
    rank is below that of the current pixel, replace the neighbor's rank with
    the rank of the current pixel. This dilation is limited by the mask, i.e.
    the rank at each pixel cannot exceed the mask as that pixel.

    Parameters
    ----------
    avalues : array
        The rank order of the flattened seed and mask images.
    aprev, anext: arrays
        Indices of previous and next pixels in rank sorted order.
    astrides : array
        Strides to neighbors of the current pixel.
    current : int
        Index of lowest-ranked pixel used as starting point in reconstruction
        loop.
    image_stride : int
        Stride between seed image and mask image in `avalues`.
    """
    cdef:
        np.int32_t neighbor
        np.uint32_t neighbor_value
        np.uint32_t current_value
        np.uint32_t mask_value
        np.int32_t current_link
        int i
        np.int32_t nprev
        np.int32_t nnext
        int nstrides = astrides.shape[0]
        np.uint32_t *values = <np.uint32_t *>(avalues.data)
        np.int32_t *prev = <np.int32_t *>(aprev.data)
        np.int32_t *next = <np.int32_t *>(anext.data)
        np.int32_t *strides = <np.int32_t *>(astrides.data)

    while current != -1:
        if current < image_stride:
            current_value = values[current]
            if current_value == 0:
                break
            for i in range(nstrides):
                neighbor = current + strides[i]
                neighbor_value = values[neighbor]
                # Only propagate neighbors ranked below the current rank
                if neighbor_value < current_value:
                    mask_value = values[neighbor + image_stride]
                    # Only propagate neighbors ranked below the mask rank
                    if neighbor_value < mask_value:
                        # Raise the neighbor to the mask rank if
                        # the mask ranked below the current rank
                        if mask_value < current_value:
                            current_link = neighbor + image_stride
                            values[neighbor] = mask_value
                        else:
                            current_link = current
                            values[neighbor] = current_value
                        # unlink the neighbor
                        nprev = prev[neighbor]
                        nnext = next[neighbor]
                        next[nprev] = nnext
                        if nnext != -1:
                            prev[nnext] = nprev
                        # link to the neighbor after the current link
                        nnext = next[current_link]
                        next[neighbor] = nnext
                        prev[neighbor] = current_link
                        if nnext >= 0:
                            prev[nnext] = neighbor
                            next[current_link] = neighbor
        current = next[current]

