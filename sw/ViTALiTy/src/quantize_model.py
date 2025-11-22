"""
under /workspace
python3 ViTALiTy/src/quantize_model.py \
  --model-path models/vitality_train/best_checkpoint.pth \
  --model deit_tiny_patch16_224 \
  --degree 1 \
  --data-path /path/to/imagenet/val \
  --out models/vitality_train/ \
  --num-calib 512 \
  --workers 8

"""

import os
import argparse
import numpy as np
from pathlib import Path
from timm import create_model
import torch
import torch.nn as nn
import models
from datasets import build_dataset

import onnx
from onnxruntime.quantization import quantize_static, CalibrationDataReader, QuantType, QuantFormat
from onnxruntime.quantization.shape_inference import quant_pre_process
from onnx.utils import extract_model
import onnxruntime as ort


def get_args_parser():
    parser = argparse.ArgumentParser('Quantization of float vitality models', add_help=False)
    parser.add_argument("--model-path", required=True, type=str)
    parser.add_argument("--model", default="deit_tiny_patch16_224", type=str)
    parser.add_argument("--degree", default=1, type=int, choices=[1,2])
    parser.add_argument("--bits-act", default=8, type=int)
    parser.add_argument("--bits-wt", default=8, type=int)
    parser.add_argument("--batch-size", default=64, type=int)
    parser.add_argument("--img-size", default=224, type=int)
    parser.add_argument("--workers", default=4, type=int)
    parser.add_argument("--out", default="ptq_out", type=str)
    parser.add_argument('--device', default='cuda',
                        help='device to use for training / testing')
    parser.add_argument('--data-path', default='/srv/datasets/imagenet/', type=str, help='dataset path')
    parser.add_argument('--data-set', default='IMNET', choices=['CIFAR', 'IMNET', 'INAT', 'INAT19'],
                        type=str, help='Image Net dataset path')
    parser.add_argument('--drop', type=float, default=0.0, metavar='PCT',
                        help='Dropout rate (default: 0.)')
    parser.add_argument('--drop-path', type=float, default=0.1, metavar='PCT',
                        help='Drop path rate (default: 0.1)')
    parser.add_argument("--export-onnx", type=bool, default=True)
    parser.add_argument("--num-calib", type=int, default=512)
    parser.add_argument("--pin-mem", action="store_true", default=False)
    parser.add_argument('--input-size', default=224, type=int, help='images input size')
    # Augmentation parameters
    parser.add_argument('--color-jitter', type=float, default=0.4, metavar='PCT',
                        help='Color jitter factor (default: 0.4)')
    parser.add_argument('--aa', type=str, default='rand-m9-mstd0.5-inc1', metavar='NAME',
                        help='Use AutoAugment policy. "v0" or "original". " + \
                             "(default: rand-m9-mstd0.5-inc1)'),
    parser.add_argument('--smoothing', type=float, default=0.1, help='Label smoothing (default: 0.1)')
    parser.add_argument('--train-interpolation', type=str, default='bicubic',
                        help='Training interpolation (random, bilinear, bicubic default: "bicubic")')

    return parser


class DataReader(CalibrationDataReader):
    def __init__(self, dataloader, max_samples: int, input_name: str = "input"):
        self.dataloader = dataloader
        self.max_samples = max_samples
        self.input_name = input_name
        self._it = None
        self._seen = 0
        self.rewind()

    def get_next(self):
        if self._seen >= self.max_samples:
            return None
        try:
            batch, _ = next(self._it) 
        except StopIteration:
            return None
        self._seen += batch.shape[0]
        return {self.input_name: batch.cpu().numpy()}  

    def rewind(self):
        self._it = iter(self.dataloader)
        self._seen = 0


class _ExportLogitsOnly(nn.Module):
    def __init__(self, model):
        super().__init__()
        self.model = model
    def forward(self, x):
        out = self.model(x)
        if isinstance(out, (list, tuple)):
            return out[0]
        return out


def collect_linear_tensors(subgraph_path, float_model=True):
    model = onnx.load(subgraph_path)
    names = set()
    if float_model:
        target_ops = {"MatMul", "Gemm"}
    else:
        target_ops = {"QLinearMatMul"}

    for node in model.graph.node:
        if node.op_type not in target_ops:
            continue
        names.add(node.input[0])
        names.add(node.output[0])

    return sorted(names)


def add_interm_outputs(full_model_path, tensor_names, out_path):
    model = onnx.load(full_model_path)
    model = onnx.shape_inference.infer_shapes(model)

    existing_outputs = {o.name for o in model.graph.output}

    value_info_map = {}
    for vi in list(model.graph.value_info) + list(model.graph.input) + list(model.graph.output):
        value_info_map[vi.name] = vi

    for name in tensor_names:
        if name in existing_outputs:
            continue
        vi = value_info_map.get(name)
        if vi is not None:
            model.graph.output.append(vi)
        else:
            model.graph.output.append(
                onnx.helper.make_tensor_value_info(name, onnx.TensorProto.FLOAT, None)
            )

    onnx.save(model, out_path)


def save_interm_outputs(
    model_path,
    dataloader,
    input_name,
    tensor_names,
    npz_path,
    max_batches=None,
):
    sess = ort.InferenceSession(model_path, providers=["CPUExecutionProvider"])
    ort_outputs = sess.get_outputs()
    output_name_to_idx = {o.name: i for i, o in enumerate(ort_outputs)}
    buffers = {name: [] for name in tensor_names}

    for bidx, (images, *rest) in enumerate(dataloader):
        if max_batches is not None and bidx >= max_batches:
            break
        x = images.cpu().numpy()
        outputs = sess.run(None, {input_name: x})

        for name in tensor_names:
            idx = output_name_to_idx.get(name, None)
            if idx is None:
                raise RuntimeError(f"Tensor {name} not found in ORT outputs of {model_path}")
            buffers[name].append(outputs[idx])

    arrays = {name: np.concatenate(chunks, axis=0) for name, chunks in buffers.items()}
    np.savez(npz_path, **arrays)


def quantize_model(model: nn.Module, args: argparse.Namespace, val_loader) -> str:
    # Export the float model to ONNX
    dummy = torch.randn(1, 3, args.img_size, args.img_size, device=args.device)
    float_onnx_path = os.path.join(args.out, "model_float.onnx")
    export_model = _ExportLogitsOnly(model).eval().to(args.device)
    torch.onnx.export(
        export_model, 
        dummy, 
        float_onnx_path,
        input_names=["input"], 
        output_names=["logits"],
        opset_version=17, 
        do_constant_folding=True,
        dynamic_axes={
            "input":  {0: "batch"},
            "logits": {0: "batch"},
        },
    )

    # Prepare calibration data
    calib_subset  = torch.utils.data.Subset(val_loader, list(range(args.num_calib)))
    calib_loader  = torch.utils.data.DataLoader(
        calib_subset,
        batch_size=args.batch_size, 
        shuffle=False,
        num_workers=args.workers,
        pin_memory=False,
        drop_last=False
    )
    calib_data = DataReader(calib_loader, max_samples=args.num_calib, input_name="input")

    # Preprocess
    print("Quantization preprocessing...")
    pre_onnx_path = os.path.join(args.out, "model_preprocessed.onnx")
    quant_pre_process(
        float_onnx_path,
        pre_onnx_path,
        skip_symbolic_shape=True,
        skip_optimization=True,
    )

    # Extract float attention subgraph
    extracted_float_path = os.path.join(args.out, "extracted_attn_float.onnx")
    extract_model(
        pre_onnx_path,
        extracted_float_path,
        input_names=["/model/Add_output_0"],
        output_names=["/model/blocks/blocks.0/Add_output_0"],
    )
    float_linear_tensors = collect_linear_tensors(
        extracted_float_path, 
        float_model=True
    )
    float_onnx_path_detailed = os.path.join(args.out, "float_detailed.onnx")
    add_interm_outputs(pre_onnx_path, float_linear_tensors, float_onnx_path_detailed)

    # Quantization
    print("Quantizing...")
    quant_onnx_path = os.path.join(args.out, "model_quantized.onnx")
    quantize_static(
        model_input=pre_onnx_path,
        model_output=quant_onnx_path,
        calibration_data_reader=calib_data,
        per_channel=True,
        reduce_range=False,
        activation_type=QuantType.QInt8,
        weight_type=QuantType.QInt8,
        op_types_to_quantize=["MatMul","Gemm"],
        extra_options={"ActivationSymmetric": False},
        quant_format=QuantFormat.QOperator
    )

    # Extract quantized attention subgraph
    extracted_quant_path = os.path.join(args.out, "extracted_attn_quant.onnx")
    extract_model(
        quant_onnx_path,
        extracted_quant_path,
        input_names=["/model/Add_output_0"],
        output_names=["/model/blocks/blocks.0/Add_output_0"],
    )
    quant_linear_tensors = collect_linear_tensors(
        extracted_quant_path, 
        float_model=False
    )
    quant_onnx_path_detailed = os.path.join(args.out, "quant_detailed.onnx")
    add_interm_outputs(quant_onnx_path, quant_linear_tensors, quant_onnx_path_detailed)

    # Inference and save intermediate data
    print("Collecting intermediate data...")
    float_npz_path = os.path.join(args.out, "attn_float_activations.npz")
    save_interm_outputs(
        float_onnx_path_detailed,
        calib_loader,
        input_name="input",
        tensor_names=float_linear_tensors,
        npz_path=float_npz_path,
    )

    quant_npz_path = os.path.join(args.out, "attn_quant_activations.npz")
    save_interm_outputs(
        quant_onnx_path_detailed,
        calib_loader,
        input_name="input",
        tensor_names=quant_linear_tensors,
        npz_path=quant_npz_path,
    )

    return quant_onnx_path


def evaluate_onnx(onnx_path: str,
                  dataset_val,
                  args: argparse.Namespace) -> None:
    eval_loader = torch.utils.data.DataLoader(
        dataset_val,
        batch_size=args.batch_size,
        shuffle=False,
        num_workers=args.workers,
        pin_memory=False,
        drop_last=False,
    )

    providers = ["CUDAExecutionProvider", "CPUExecutionProvider"]
    sess = ort.InferenceSession(onnx_path, providers=providers)

    in_name  = sess.get_inputs()[0].name
    out_name = sess.get_outputs()[0].name
    print("Evaluating ONNX model...")
    correct = 0
    total = 0
    with torch.no_grad():
        for imgs, labels in eval_loader:
            x = imgs.cpu().numpy()
            y = labels.numpy()
            logits = sess.run([out_name], {in_name: x})[0] 
            pred = logits.argmax(axis=1)
            correct += (pred == y).sum()
            total   += y.shape[0]
    top1 = 100.0 * correct / max(1, total)
    print(f"[ACC] Quantized ONNX top-1 on {total} imgs: {top1:.2f}%")


def main(args):
    print(args)
    args.device = torch.device(args.device)

    args.nb_classes = 1000
    dataset_val, _ = build_dataset(is_train=False, args=args)

    print(f"Creating model: {args.model}")
    model = create_model(
        args.model,
        pretrained=False,
        num_classes=args.nb_classes,
        drop_rate=args.drop,
        drop_path_rate=args.drop_path,
        drop_block_rate=None,
        vitality=True,
        degree=args.degree,
    )
    checkpoint = torch.load(args.model_path, map_location='cpu')
    checkpoint_model = checkpoint['model']
    state_dict = model.state_dict()
    for k in ['head.weight', 'head.bias', 'head_dist.weight', 'head_dist.bias']:
        if k in checkpoint_model and checkpoint_model[k].shape != state_dict[k].shape:
            print(f"Removing key {k} from pretrained checkpoint")
            del checkpoint_model[k]
    # interpolate position embedding
    pos_embed_checkpoint = checkpoint_model['pos_embed']
    embedding_size = pos_embed_checkpoint.shape[-1]
    num_patches = model.patch_embed.num_patches
    num_extra_tokens = model.pos_embed.shape[-2] - num_patches
    # height (== width) for the checkpoint position embedding
    orig_size = int((pos_embed_checkpoint.shape[-2] - num_extra_tokens) ** 0.5)
    # height (== width) for the new position embedding
    new_size = int(num_patches ** 0.5)
    # class_token and dist_token are kept unchanged
    extra_tokens = pos_embed_checkpoint[:, :num_extra_tokens]
    # only the position tokens are interpolated
    pos_tokens = pos_embed_checkpoint[:, num_extra_tokens:]
    pos_tokens = pos_tokens.reshape(-1, orig_size, orig_size, embedding_size).permute(0, 3, 1, 2)
    pos_tokens = torch.nn.functional.interpolate(
        pos_tokens, size=(new_size, new_size), mode='bicubic', align_corners=False)
    pos_tokens = pos_tokens.permute(0, 2, 3, 1).flatten(1, 2)
    new_pos_embed = torch.cat((extra_tokens, pos_tokens), dim=1)
    checkpoint_model['pos_embed'] = new_pos_embed
    model.load_state_dict(checkpoint_model, strict=False)
    model.to(args.device)
    model.eval()

    quant_model_path = quantize_model(model, args, dataset_val)
    # evaluate_onnx(quant_model_path, dataset_val, args)


if __name__ == '__main__':
    parser = argparse.ArgumentParser('Quantization of float vitality models', parents=[get_args_parser()])
    args = parser.parse_args()
    Path(args.out).mkdir(parents=True, exist_ok=True)
    main(args)
