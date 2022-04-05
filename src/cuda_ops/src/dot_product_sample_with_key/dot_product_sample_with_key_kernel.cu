#include "../cuda_utils.h"
#include "dot_product_sample_with_key_kernel.h"


__global__ void dot_product_sample_with_key_forward_kernel(
    int m, int h, int c, const float* query, const float* key, const float* pos, float* out_F, const int* skq_indices
)
{
    // m: # of total mappings
    // h: # of attention heads
    // c: # of attention channels
    
    int index = blockIdx.x * blockDim.x + threadIdx.x;
    if (index >= m * h) return;

    int map_idx = index / h;
    int head_idx = index % h;

    int sample_idx = skq_indices[map_idx]; // skq_indices[0][map_idx]
    int key_idx_ = skq_indices[m + map_idx]; // skq_indices[1][map_idx]
    int query_idx_ = skq_indices[2*m + map_idx]; // skq_indices[2][map_idx]

    for(int i = 0; i < c; i++){

        int query_idx = query_idx_ * h * c + head_idx * c + i;
        int key_idx = key_idx_ * h * c + head_idx * c + i;
        int pos_idx = sample_idx * h * c + head_idx * c + i;

        out_F[index] += query[query_idx] * (key[key_idx] + pos[pos_idx]);
    }
}

__global__ void dot_product_sample_with_key_backward_kernel(
    int m, int h, int c, const float* query, const float* key, const float* pos, const int* skq_indices,
    float* grad_query, float* grad_key, float* grad_pos, const float* grad_out_F
)
{
    // m: # of total mappings
    // h: # of attention heads
    // c: # of attention channels
    
    int index = blockIdx.x * blockDim.x + threadIdx.x;
    if (index >= m * c) return;

    int map_idx = index / c;
    int i = index % c;

    int sample_idx = skq_indices[map_idx]; // skq_indices[0][map_idx]
    int key_idx_ = skq_indices[m + map_idx]; // skq_indices[1][map_idx]
    int query_idx_ = skq_indices[2*m + map_idx]; // skq_indices[2][map_idx]

    for(int head_idx = 0; head_idx < h; head_idx++){

        int out_F_idx = map_idx * h + head_idx;
        int query_idx = query_idx_ * h * c + head_idx * c + i;
        int key_idx = key_idx_ * h * c + head_idx * c + i;
        int pos_idx = sample_idx * h * c + head_idx * c + i;

        atomicAdd(grad_query + query_idx, grad_out_F[out_F_idx] * (key[key_idx] + pos[pos_idx]));
        atomicAdd(grad_key + key_idx, grad_out_F[out_F_idx] * query[query_idx]);
        atomicAdd(grad_pos + pos_idx, grad_out_F[out_F_idx] * query[query_idx]);
    }
}

void dot_product_sample_with_key_forward_launcher(
    int m, int h, int c, const float* query, const float* key, const float* pos, float* out_F, const int* skq_indices
) {
    cudaStream_t stream = at::cuda::getCurrentCUDAStream();
    dim3 blocks(DIVUP(m * h, THREADS_PER_BLOCK));
    dim3 threads(THREADS_PER_BLOCK);
    dot_product_sample_with_key_forward_kernel<<<blocks, threads, 0, stream>>>(
        m, h, c, query, key, pos, out_F, skq_indices
    );
}

void dot_product_sample_with_key_backward_launcher(
    int m, int h, int c, const float* query, const float* key, const float* pos, const int* skq_indices,
    float* grad_query, float* grad_key, float* grad_pos, const float* grad_out_F
) {
    cudaStream_t stream = at::cuda::getCurrentCUDAStream();
    dim3 blocks(DIVUP(m * c, THREADS_PER_BLOCK));
    dim3 threads(THREADS_PER_BLOCK);
    dot_product_sample_with_key_backward_kernel<<<blocks, threads, 0, stream>>>(
        m, h, c, query, key, pos, skq_indices,
        grad_query, grad_key, grad_pos, grad_out_F
    );
}