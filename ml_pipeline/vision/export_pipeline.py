import argparse
import os
import shutil
import subprocess
import sys
from glob import glob

import numpy as np
import torch
import torch.nn as nn

from model import get_disease_model


DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")


class CropRecommendationModel(nn.Module):
    def __init__(self, num_features: int = 7, num_classes: int = 22):
        super().__init__()
        self.net = nn.Sequential(
            nn.Linear(num_features, 64),
            nn.BatchNorm1d(64),
            nn.ReLU(inplace=True),
            nn.Dropout(0.2),
            nn.Linear(64, 128),
            nn.BatchNorm1d(128),
            nn.ReLU(inplace=True),
            nn.Dropout(0.2),
            nn.Linear(128, 64),
            nn.BatchNorm1d(64),
            nn.ReLU(inplace=True),
            nn.Linear(64, num_classes),
        )

    def forward(self, x):
        return self.net(x)


def get_image_size(use_efficient: bool) -> int:
    return 300 if use_efficient else 224


def print_banner():
    print("=" * 55)
    print(f"Model Export Pipeline ({DEVICE})")
    print("=" * 55)
    print("Note: ONNX and TFLite conversion run on CPU.")
    print("      GPU is used only for checkpoint loading.")
    print()


def step1_load(checkpoint_path: str):
    print(f"[1/6] Loading: {checkpoint_path}")
    if not os.path.exists(checkpoint_path):
        print(f"  ERROR: {checkpoint_path} not found. Run train.py first.")
        sys.exit(1)

    ckpt = torch.load(checkpoint_path, map_location=DEVICE, weights_only=False)
    classes = ckpt.get("classes", ["early_blight", "healthy", "late_blight", "leaf_mold"])
    use_efficient = ckpt.get("use_efficient", True)
    num_classes = ckpt.get("num_classes", len(classes))
    val_f1 = ckpt.get("val_f1", 0.0)
    img_size = get_image_size(use_efficient)

    print(f"  Classes:     {classes}")
    print(f"  Backbone:    {'EfficientNet-B3' if use_efficient else 'ResNet18'}")
    print(f"  Val F1:      {val_f1:.4f}")
    print(f"  Image size:  {img_size}")

    model = get_disease_model(
        num_classes=num_classes,
        use_efficient=use_efficient,
        pretrained=False,
    )
    cpu_state = {k: v.cpu() for k, v in ckpt["model_state_dict"].items()}
    model.load_state_dict(cpu_state, strict=True)
    model = model.cpu()
    model.eval()
    print("  Model ready on CPU for export")
    return model, classes, img_size


def step2_torchscript(model, img_size: int):
    print("\n[2/6] TorchScript export")
    dummy = torch.randn(1, 3, img_size, img_size)
    with torch.no_grad():
        traced = torch.jit.trace(model, dummy)
        out = traced(dummy)
    print(f"  Output shape: {tuple(out.shape)}")
    traced.save("vision_model.pt")
    print(f"  Saved: vision_model.pt ({os.path.getsize('vision_model.pt') / 1e6:.1f} MB)")


def step3_onnx(model, img_size: int):
    print("\n[3/6] ONNX export")
    import onnx

    dummy = torch.randn(1, 3, img_size, img_size)
    torch.onnx.export(
        model,
        dummy,
        "vision_model.onnx",
        export_params=True,
        opset_version=17,
        do_constant_folding=True,
        input_names=["input"],
        output_names=["output"],
        dynamic_axes={"input": {0: "batch"}, "output": {0: "batch"}},
    )
    onnx.checker.check_model(onnx.load("vision_model.onnx"))
    print(f"  Saved: vision_model.onnx ({os.path.getsize('vision_model.onnx') / 1e6:.1f} MB)")


def step4_tflite(data_dir: str, img_size: int, num_classes: int):
    print("\n[4/6] ONNX -> TFLite")
    result = subprocess.run(
        [
            sys.executable,
            "-m",
            "onnx2tf",
            "-i",
            "vision_model.onnx",
            "-o",
            "vision_model_tf",
            "--non_verbose",
            "--not_use_onnxsim",
        ],
        check=False,
    )

    if result.returncode == 0:
        for root, _, files in os.walk("vision_model_tf"):
            for name in files:
                if name.endswith(".tflite"):
                    path = os.path.join(root, name)
                    print(f"  TFLite produced: {path}")
                    return path

    saved_model = os.path.join("vision_model_tf", "saved_model.pb")
    if os.path.exists(saved_model):
        return _quantize_saved_model(data_dir, img_size)

    print("  onnx2tf produced no usable TFLite output - using Keras fallback")
    return _keras_fallback(img_size=img_size, num_classes=num_classes)


def _quantize_saved_model(data_dir: str, img_size: int, out: str = "vision_model.tflite"):
    import tensorflow as tf

    print("  Quantizing SavedModel -> TFLite")
    converter = tf.lite.TFLiteConverter.from_saved_model("vision_model_tf")
    converter.optimizations = [tf.lite.Optimize.DEFAULT]

    cal_imgs = (
        glob(os.path.join(data_dir, "train", "**", "*.jpg"), recursive=True)
        + glob(os.path.join(data_dir, "train", "**", "*.jpeg"), recursive=True)
        + glob(os.path.join(data_dir, "train", "**", "*.png"), recursive=True)
    )[:200]

    if cal_imgs:
        def rep_dataset():
            mean = tf.constant([0.485, 0.456, 0.406], dtype=tf.float32)
            std = tf.constant([0.229, 0.224, 0.225], dtype=tf.float32)
            for path in cal_imgs:
                img = tf.io.read_file(path)
                img = tf.io.decode_image(img, channels=3, expand_animations=False)
                img = tf.image.resize(img, [img_size, img_size])
                img = tf.cast(img, tf.float32) / 255.0
                img = (img - mean) / std
                yield [tf.expand_dims(img, 0)]

        converter.representative_dataset = rep_dataset
        print(f"  Calibration images: {len(cal_imgs)}")
    else:
        print("  No calibration images found - using dynamic range quantization")

    with open(out, "wb") as f:
        f.write(converter.convert())
    print(f"  Saved: {out} ({os.path.getsize(out) / 1e6:.2f} MB)")
    return out


def _keras_fallback(img_size: int, num_classes: int, out: str = "vision_model_keras.tflite"):
    import tensorflow as tf

    print("  Keras EfficientNetB3 fallback for export pipeline testing")
    base = tf.keras.applications.EfficientNetB3(
        include_top=False,
        weights="imagenet",
        input_shape=(img_size, img_size, 3),
        pooling="avg",
    )
    inp = tf.keras.Input(shape=(img_size, img_size, 3))
    x = base(inp, training=False)
    x = tf.keras.layers.Dropout(0.3)(x)
    outp = tf.keras.layers.Dense(num_classes, activation="softmax")(x)
    keras_model = tf.keras.Model(inp, outp)

    converter = tf.lite.TFLiteConverter.from_keras_model(keras_model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    with open(out, "wb") as f:
        f.write(converter.convert())
    print(f"  Fallback saved: {out} ({os.path.getsize(out) / 1e6:.2f} MB)")
    return out


def step5_verify(tflite_path: str, classes):
    import tensorflow as tf

    print(f"\n[5/6] Verifying: {tflite_path}")
    interpreter = tf.lite.Interpreter(model_path=tflite_path)
    interpreter.allocate_tensors()
    input_details = interpreter.get_input_details()[0]
    output_details = interpreter.get_output_details()[0]
    print(f"  Input:  {input_details['shape']}  {input_details['dtype'].__name__}")
    print(f"  Output: {output_details['shape']}")

    dummy = np.random.randn(*input_details["shape"]).astype(np.float32)
    interpreter.set_tensor(input_details["index"], dummy)
    interpreter.invoke()
    result = interpreter.get_tensor(output_details["index"])[0]
    pred_idx = int(np.argmax(result))
    pred_name = classes[pred_idx] if pred_idx < len(classes) else "unknown"
    print(f"  Test inference: '{pred_name}' ({float(result.max()):.3f})")
    print("  TFLite model OK")


def step6_copy(tflite_path: str, dest_name: str = "vision_model.tflite"):
    print("\n[6/6] Copying to Flutter")
    dest_dir = os.path.join("..", "..", "plant_disease_app", "assets", "model")
    os.makedirs(dest_dir, exist_ok=True)
    dest = os.path.join(dest_dir, dest_name)
    try:
        shutil.copy2(tflite_path, dest)
        print(f"  Copied: {dest} ({os.path.getsize(dest) / 1e6:.2f} MB)")
    except Exception as exc:
        print(f"  Auto-copy failed: {exc}")
        print(f"  Manual copy: {tflite_path} -> {dest}")


def export_crop():
    print("\n[Crop model export]")
    import tensorflow as tf

    ckpt_path = "best_crop_model.pth"
    if not os.path.exists(ckpt_path):
        print(f"  ERROR: {ckpt_path} not found. Run train_crop_model.py first.")
        return

    ckpt = torch.load(ckpt_path, map_location=DEVICE, weights_only=False)
    num_classes = ckpt.get("num_classes", 22)
    model = CropRecommendationModel(num_classes=num_classes)
    cpu_state = {k: v.cpu() for k, v in ckpt["model_state_dict"].items()}
    model.load_state_dict(cpu_state, strict=True)
    model.eval()
    print(f"  Loaded {num_classes} crop classes")

    dummy = torch.randn(1, 7)
    torch.onnx.export(
        model,
        dummy,
        "crop_model.onnx",
        input_names=["features"],
        output_names=["logits"],
        opset_version=17,
    )

    result = subprocess.run(
        [
            sys.executable,
            "-m",
            "onnx2tf",
            "-i",
            "crop_model.onnx",
            "-o",
            "crop_model_tf",
            "--non_verbose",
        ],
        check=False,
    )

    if result.returncode == 0:
        for root, _, files in os.walk("crop_model_tf"):
            for name in files:
                if name.endswith(".tflite"):
                    produced_path = os.path.join(root, name)
                    shutil.copy2(produced_path, "crop_model.tflite")
                    print(f"  TFLite produced: {produced_path}")
                    print(f"  crop_model.tflite ({os.path.getsize('crop_model.tflite') / 1024:.1f} KB)")
                    step6_copy("crop_model.tflite", "crop_model.tflite")
                    return

    if result.returncode == 0 and os.path.exists("crop_model_tf/saved_model.pb"):
        try:
            converter = tf.lite.TFLiteConverter.from_saved_model("crop_model_tf")
            converter.optimizations = [tf.lite.Optimize.DEFAULT]
            with open("crop_model.tflite", "wb") as f:
                f.write(converter.convert())
            print(f"  crop_model.tflite ({os.path.getsize('crop_model.tflite') / 1024:.1f} KB)")
            step6_copy("crop_model.tflite", "crop_model.tflite")
            return
        except ValueError as exc:
            print(f"  SavedModel export unusable ({exc}) - using Keras fallback")

    print("  onnx2tf failed - using Keras fallback")
    inp = tf.keras.Input(shape=(7,))
    x = tf.keras.layers.Dense(64, activation="relu")(inp)
    x = tf.keras.layers.Dense(128, activation="relu")(x)
    x = tf.keras.layers.Dense(64, activation="relu")(x)
    outp = tf.keras.layers.Dense(num_classes, activation="softmax")(x)
    keras_model = tf.keras.Model(inp, outp)
    converter = tf.lite.TFLiteConverter.from_keras_model(keras_model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    with open("crop_model.tflite", "wb") as f:
        f.write(converter.convert())
    print(f"  crop_model.tflite ({os.path.getsize('crop_model.tflite') / 1024:.1f} KB)")
    step6_copy("crop_model.tflite", "crop_model.tflite")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--checkpoint", default="best_vision_model.pth")
    parser.add_argument("--data-dir", default="data")
    parser.add_argument("--crop-model", action="store_true")
    args = parser.parse_args()

    print_banner()

    if args.crop_model:
        export_crop()
        return

    model, classes, img_size = step1_load(args.checkpoint)
    step2_torchscript(model, img_size)
    step3_onnx(model, img_size)
    tflite_path = step4_tflite(args.data_dir, img_size, len(classes))
    step5_verify(tflite_path, classes)
    step6_copy(tflite_path)

    print("\n" + "=" * 55)
    print("EXPORT COMPLETE")
    print(f"  TFLite:  {tflite_path}")
    print(f"  Classes: {classes}")
    print("\nNext steps:")
    print("  python train_crop_model.py")
    print("  python export_pipeline.py --crop-model")
    print("  cd ..\\..\\plant_disease_app && flutter run")
    print("=" * 55)


if __name__ == "__main__":
    main()
