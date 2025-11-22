# Glide Accelerator

**Hardware accelerator for efficient Vision Transformer inference using linear attention approximation**

Glide Accelerator replaces expensive softmax attention with Taylor-series polynomial approximation, achieving **10-100× speedup** while maintaining accuracy. The design features a **32×16 systolic array** optimized for the matrix operations in linearized attention mechanisms.

---

## Why Linear Attention?

Traditional Vision Transformers use softmax attention with **O(N²)** complexity:

```
Attention(Q,K,V) = softmax(QK^T/√d) · V
```

**Glide uses polynomial approximation** to linearize this to **O(N)**:

```
softmax(x) ≈ 1 + x + x²/2  (Taylor series, degree-2)
Attention(Q,K,V) ≈ ϕ(Q) · (ϕ(K)^T · V)
```

This transforms **N×N matrix multiplications** into efficient **associative operations** that our systolic array can accelerate.

---

## Architecture

![Zynq UltraScale+ Block Design](docs/block_design.png)

*PS-PL integration: ARM Cortex-A cores controlling the systolic accelerator via AXI4 memory-mapped registers*

### Hardware Components

| Component | Specification |
|-----------|---------------|
| **Systolic Array** | 32 rows × 16 columns (512 PEs) |
| **Precision** | INT8 quantization, 32-bit accumulation |
| **Memory** | 512 dedicated accumulators for multi-pass tiling |
| **Quantization** | 64 shared units (8× time-multiplexed) |
| **Interfaces** | AXI4-Lite (control), AXI4-Stream (data) |

### Performance @ 200 MHz

| Metric | Value |
|--------|-------|
| **Peak Throughput** | 102.4 GOPS (512 MACs/cycle) |
| **Power Efficiency** | Low-power INT8 operations |
| **Latency** | ~61 cycles (end-to-end pipeline) |
| **Resource Usage** | 36% LUTs, 15% DSPs (Zynq UltraScale+) |

---

## How It Works

### 1. **Linear Attention Computation**

For a Vision Transformer processing **N patches**:

```python
# Traditional attention: O(N²)
scores = Q @ K.T          # N×N matrix (expensive!)
weights = softmax(scores) # Row-wise softmax
output = weights @ V      # Another N×N matmul

# Glide's linearized attention: O(N)
Q_approx = poly_approx(Q)  # Element-wise polynomial
K_approx = poly_approx(K)
KV = K_approx.T @ V        # Precompute this (reusable!)
output = Q_approx @ KV     # Final result
```

### 2. **Systolic Array Acceleration**

The **32×16 array** performs outer-product matrix multiplications:

```
┌─────────────────────────────────┐
│  PE[0,0]  PE[0,1]  ...  PE[0,15] │
│  PE[1,0]  PE[1,1]  ...  PE[1,15] │
│    ...      ...     ...    ...   │
│ PE[31,0] PE[31,1] ... PE[31,15] │
└─────────────────────────────────┘
   ↓        ↓              ↓
  Accumulate → Quantize → Output
```

Each PE computes `C[i,j] += A[i] * B[j]` in parallel.

### 3. **INT8 Quantization**

Reduces computation cost with minimal accuracy loss:
- **Activations**: INT8 (8-bit)
- **Weights**: INT8 (8-bit)
- **Accumulation**: INT32 (32-bit, no overflow)
- **Output**: Re-quantized to INT8

---

## Quick Start

### Prerequisites
- Xilinx Vivado 2023.1+
- Zynq UltraScale+ board (ZCU102/104) or AWS F1 instance

### 1. **RTL Simulation**

Test the accelerator with a SystemVerilog testbench:

```bash
cd hw
source /tools/Xilinx/Vivado/2023.1/settings64.sh
./run_vivado.sh sim
```

### 2. **Package as Vivado IP**

Create a reusable IP for any Zynq project:

```bash
cd hw
./run_vivado.sh package-ip
```

**Output**: `hw/ip_repo/systolic_accelerator_v1.0/`

### 3. **Create PS-PL Block Design**

Automatically generates a complete Zynq system with PS and your accelerator:

```bash
./run_vivado.sh create-bd-gui
```

This opens Vivado GUI showing:
- ✅ Zynq UltraScale+ PS (quad-core ARM Cortex-A53)
- ✅ Systolic accelerator IP at **0xA000_0000**
- ✅ AXI interconnects and clocking
- ✅ External ports for DMA integration

### 4. **Generate Bitstream**

In Vivado GUI:
1. Right-click block design → **Create HDL Wrapper**
2. Click **Generate Bitstream**
3. Wait for implementation to complete

---

## Software Control

### Memory Map

| Address | Register | Function |
|---------|----------|----------|
| `0xA000_0000` | CTRL | [0]=enable, [1]=reset, [2]=start |
| `0xA000_0004` | STATUS | [0]=busy, [1]=done, [2]=overflow |
| `0xA000_0008` | ACCUM_CTRL | [0]=accum_enable, [1]=accum_clear |
| `0xA000_000C` | QUANT_CTRL | [0]=quant_enable |
| `0xA000_0010` | SCALE | Quantization scale factor (32-bit) |
| `0xA000_0014` | SHIFT | Quantization shift amount |

### Example: Linux Driver (Bare Metal)

```c
#include <stdio.h>
#include <fcntl.h>
#include <sys/mman.h>

#define ACCEL_BASE 0xA0000000
#define CTRL_REG   0x00
#define STATUS_REG 0x04
#define SCALE_REG  0x10

int main() {
    int fd = open("/dev/mem", O_RDWR | O_SYNC);
    volatile uint32_t *accel = (uint32_t *)mmap(
        NULL, 4096, PROT_READ | PROT_WRITE,
        MAP_SHARED, fd, ACCEL_BASE
    );

    // Configure accelerator
    accel[SCALE_REG/4] = 128;        // Scale factor
    accel[CTRL_REG/4]  = 0x5;        // Enable + Start

    // Poll for completion
    while (!(accel[STATUS_REG/4] & 0x2));

    printf("Linear attention computed!\n");
    munmap((void*)accel, 4096);
    close(fd);
}
```

---

## Deployment Options

### 1. **Zynq UltraScale+ Boards**
- **ZCU102** / **ZCU104** evaluation kits
- Export hardware → PetaLinux → Load bitstream

### 2. **AWS EC2 F1 Instances**
Cloud FPGA deployment for scalable inference:

```bash
# Launch F1 instance with Xilinx FPGA
aws ec2 run-instances --instance-type f1.2xlarge ...

# Deploy using AWS FPGA Developer Kit
git clone https://github.com/aws/aws-fpga.git
source aws-fpga/sdk_setup.sh
```

### 3. **Edge Devices**
- **Kria SOM** (K26/KV260)
- **Ultra96-V2**
- Custom Zynq boards

---

## Performance Comparison

| Method | Complexity | Speedup | Accuracy |
|--------|-----------|---------|----------|
| **Softmax Attention** | O(N²) | 1× (baseline) | 100% |
| **Degree-1 Linear** | O(N) | **50-70×** | ~98% |
| **Degree-2 Linear (Glide)** | O(N) | **10-100×** | **~99.5%** |

*Benchmarked on DeiT-Tiny with ImageNet-1K*

---

## Project Structure

```
Glide-Accelerator/
├── hw/                          # Hardware RTL
│   ├── src/
│   │   ├── systolic_quant_32x16.sv     # Main accelerator
│   │   ├── axi_systolic_wrapper.sv     # AXI4 interface wrapper
│   │   ├── systolic_mac_rect.sv        # Systolic array core
│   │   ├── pe.sv                       # Processing element
│   │   ├── accumulator_bank.sv         # 512 accumulators
│   │   └── quant_shared.sv             # Quantization units
│   ├── tb/                      # Testbenches
│   ├── scripts/
│   │   ├── create_ip.tcl              # IP packaging
│   │   ├── create_bd_simple.tcl       # Block design automation
│   │   └── vivado_synth.tcl           # Synthesis flow
│   ├── run_vivado.sh            # Automation script
│   └── QUICK_START.md           # Detailed integration guide
├── models/                      # PyTorch models
│   └── degree_2_quant/         # Quantized ViT with degree-2 approx
├── ViTALiTy/                   # Vision Transformer training
└── docs/                        # Documentation & images
```

---

## Documentation

- **[Quick Start Guide](hw/QUICK_START.md)** - PS-PL integration and deployment
- **[Hardware Architecture](hw/README.md)** - Detailed RTL documentation
- **[Production Notes](PRODUCTION_RELEASE_NOTES.md)** - Verification results

---

## Key Innovation

**Glide bridges the gap between algorithm and hardware:**

1. **Algorithmic**: Taylor-series softmax → linear attention (O(N²) → O(N))
2. **Architectural**: Systolic array optimized for outer-product operations
3. **Efficiency**: INT8 quantization with shared quantization units
4. **Integration**: Production-ready AXI4 IP for any Zynq platform

Result: **Vision Transformers running 10-100× faster** on low-power FPGAs.

---

## References

- [ViTALiTy: Vision Transformer Acceleration](https://github.com/GATECH-EIC/ViTALiTy)
- [AMD QTViT: Quantization Techniques](https://github.com/AMD-AGI/AMD_QTViT)
- [Linear Attention Paper](https://arxiv.org/abs/2006.16236)

---

## License

Research project - see individual component licenses.

---

**Accelerating the future of efficient Vision Transformers 🚀**
