# Energy-Efficient Accelerator Architecture for Transformers Using Linear Attention

This is the repo for ECE562 project **Energy-Efficient Accelerator Architecture for Transformers Using Linear Attention**.

## Structure

```
    /models
        /degree_x_train
            models after training
            /checkpoint.pth
                models after training
            /model_float.onnx
                float ONNX model
            /model_quantized.onnx
                ONNX model with linear and matmul nodes quantized
            /log
                training log file
        /degree_x_quant
            models and datafiles after quantization and processing
            /attn_float_activations.npz
                datafile, includes the input and output of linear/matmul nodes on calibration datasets on **extracted_attn_float**
            /attn_quant_activations.npz
                datafile, includes the input and output of linear/matmul nodes on calibration datasets on **extracted_attn_quant**
            /extracted_attn_float.onnx
                subgraph of **model_float.onnx**, only contains the attention part of the 1st block
            /extracted_attn_quant.onnx
                subgraph of **model_quantized.onnx**, only contains the attention part of the 1st block
            
    /ViTALiTy
        modified code, support degree-1 and degree-2 taylor expression of attention
```

You can use netron to visualize the extracted_attn_xxx.onnx files to see the relationship of data and model connections.

## Acknowledge

The code refers to:

https://github.com/GATECH-EIC/ViTALiTy

https://github.com/AMD-AGI/AMD_QTViT
