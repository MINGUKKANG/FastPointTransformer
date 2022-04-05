#pragma once
#ifndef _dot_product_sample_KERNEL
#define _dot_product_sample_KERNEL
#include <vector>
#include <torch/serialize/tensor.h>
#include <ATen/cuda/CUDAContext.h>

#define AT at::Tensor

void dot_product_sample_forward(
    int m, int h, int c, AT query_tensor, AT pos_tensor, AT out_F_tensor, AT qr_indices_tensor
    );
void dot_product_sample_backward(
    int m, int h, int c, AT query_tensor, AT pos_tensor, AT qr_indices_tensor,
    AT grad_query_tensor, AT grad_pos_tensor, AT grad_out_F_tensor
    );

#ifdef __cplusplus
extern "C" {
#endif

void dot_product_sample_forward_launcher(
    int m, int h, int c, const float* query, const float* pos, float* out_F, const int* qr_indices
    );
void dot_product_sample_backward_launcher(
    int m, int h, int c, const float* query, const float* pos, const int* qr_indices,
    float* grad_query, float* grad_pos, const float* grad_out_F
    );

#ifdef __cplusplus
}
#endif
#endif