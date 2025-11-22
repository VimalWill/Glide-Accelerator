# Glide Accelerator

Low-power hardware accelerator for efficient Vision Transformer inference using linear attention approximation and systolic array architecture.

## Architecture

- **Systolic Array**: 32×16 processing elements (512 MACs)
- **Precision**: INT8 quantization with 32-bit accumulation
- **Attention Mechanism**: Taylor-series approximated softmax (degree-1 & degree-2)
- **Throughput**: 512 MACs/cycle @ 200 MHz
- **Resource Efficiency**: Shared quantization units (64 units time-multiplexed)

## Performance

| Metric | Value |
|--------|-------|
| Target Frequency | 200 MHz |
| Peak Throughput | 102.4 GOPS |
| LUT Utilization | ~36% |
| DSP Utilization | ~15% |
| Latency (End-to-End) | ~61 cycles |

## Quick Start

### Simulation
```bash
cd hw
source /tools/Xilinx/Vivado/<version>/settings64.sh
./run_vivado.sh sim
```

### Synthesis
```bash
cd hw
./run_vivado.sh synth
```

## Documentation

- [Hardware Architecture](hw/README.md) - Detailed RTL documentation
- [Production Release Notes](PRODUCTION_RELEASE_NOTES.md) - Verification and validation
- [Implementation Guide](hw/IMPLEMENTATION_GUIDE.md) - Integration instructions

## References

- [ViTALiTy](https://github.com/GATECH-EIC/ViTALiTy) - Vision Transformer acceleration
- [AMD QTViT](https://github.com/AMD-AGI/AMD_QTViT) - Quantization techniques

