import numpy as np

path = "attn_float_activations.npz"  # 或 quant 的那份
data = np.load(path)
print("共有", len(data.files), "个数组：")
for k in data.files:
    print(f"{k:60s} shape={data[k].shape}, dtype={data[k].dtype}")
