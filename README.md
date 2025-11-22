# Glide Accelerator

**Hardware accelerator for Vision Transformers using linearized attention**

Replaces O(N²) softmax attention with O(N) polynomial approximation, achieving **10-100× speedup** on Zynq UltraScale+ FPGAs.

---

## Architecture

![Block Design](docs/block_design.png)

**32×16 Systolic Array** | **INT8 Quantization** | **102.4 GOPS @ 200 MHz**

- 512 processing elements with dedicated accumulators
- AXI4 interface for PS-PL integration
- Memory-mapped control at `0xA000_0000`

---

## Linear Attention

Traditional attention is quadratic:
```
softmax(QK^T) · V  →  O(N²) complexity
```

Glide linearizes it:
```
softmax(x) ≈ 1 + x + x²/2  (Taylor series)
ϕ(Q) · (ϕ(K)^T · V)  →  O(N) complexity
```

The systolic array accelerates the resulting matrix operations.

---

## Quick Start

```bash
cd hw

# Package as Vivado IP
./run_vivado.sh package-ip

# Create Zynq PS-PL system (opens GUI)
./run_vivado.sh create-bd-gui
```

**Output**: Ready-to-use block design with ARM cores + accelerator

---

**Accelerating Vision Transformers through algorithmic and hardware co-design**
