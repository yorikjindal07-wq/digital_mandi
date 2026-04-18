# ═══════════════════════════════════════════════════════════════
# ml_pipeline/vision/train_crop_model.py  —  GPU VERSION
#
# Trains the crop recommendation MLP on tabular soil/climate data.
# Fast: ~30 seconds on GPU, ~2 min on CPU.
#
# Dataset: Crop Recommendation Dataset (Kaggle)
#   https://www.kaggle.com/datasets/atharvaingle/crop-recommendation-dataset
#   2,200 rows × 8 columns (N, P, K, temp, humidity, pH, rainfall, label)
#   22 crop classes
#
# The script auto-downloads the CSV from Kaggle if not found.
# You can also pass --csv to point to an existing file.
#
# Usage:
#   python train_crop_model.py                          ← auto-download
#   python train_crop_model.py --csv path\to\file.csv  ← use existing
#   python train_crop_model.py --epochs 100             ← more epochs
# ═══════════════════════════════════════════════════════════════

import os, sys, json, argparse, platform, subprocess, shutil
import torch
import torch.nn as nn
import torch.optim as optim
import numpy as np
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.preprocessing   import LabelEncoder, StandardScaler
from sklearn.metrics         import classification_report, accuracy_score
from torch.utils.data        import DataLoader, TensorDataset

from model import get_crop_model

# ── Device ─────────────────────────────────────────────────────
DEVICE      = torch.device("cuda" if torch.cuda.is_available() else "cpu")
NUM_WORKERS = 0 if platform.system() == "Windows" else 4
SAVE_PATH   = "best_crop_model.pth"

print(f"Crop model training on: {DEVICE}")
if DEVICE.type == "cuda":
    print(f"GPU: {torch.cuda.get_device_name(0)}")


# ═══════════════════════════════════════════════════════════════
# Step 1 — Find or download the CSV
# ═══════════════════════════════════════════════════════════════

KAGGLE_SLUG   = "atharvaingle/crop-recommendation-dataset"
CSV_FILENAME  = "Crop_recommendation.csv"

# Places to look for the CSV (in order of preference)
SEARCH_PATHS = [
    os.path.join("data", CSV_FILENAME),          # Default: data/ folder
    CSV_FILENAME,                                  # Current directory
    os.path.join("..", CSV_FILENAME),             # Parent directory
    os.path.join("..", "data", CSV_FILENAME),     # Parent/data/
]


def find_csv(user_path: str = None) -> str:
    """
    Returns the path to Crop_recommendation.csv.
    Priority: user_path → SEARCH_PATHS → Kaggle download.
    """
    # User explicitly provided a path
    if user_path:
        # Expand environment variables and ~ in path
        expanded = os.path.expandvars(os.path.expanduser(user_path))
        if os.path.isfile(expanded):
            print(f"  Using provided CSV: {expanded}")
            return expanded
        # Maybe they forgot the filename and gave a directory
        candidate = os.path.join(expanded, CSV_FILENAME)
        if os.path.isfile(candidate):
            print(f"  Using CSV in provided directory: {candidate}")
            return candidate
        print(f"  ⚠️  Provided path not found: {expanded}")
        print(f"  Falling back to auto-download...")

    # Search known locations
    for path in SEARCH_PATHS:
        if os.path.isfile(path):
            print(f"  Found existing CSV: {path}")
            return path

    # Not found anywhere — download from Kaggle
    return download_csv()


def download_csv() -> str:
    """Download Crop_recommendation.csv from Kaggle."""
    print("\n  CSV not found. Downloading from Kaggle...")
    print(f"  Dataset: {KAGGLE_SLUG}")

    # Check kaggle CLI is available
    if not shutil.which("kaggle"):
        print("\n  ❌ kaggle CLI not installed.")
        print("  Fix: pip install kaggle")
        print("  Then set up API key: https://www.kaggle.com/settings → API → Create New Token")
        print("  Place kaggle.json in: C:\\Users\\<you>\\.kaggle\\kaggle.json")
        sys.exit(1)

    # Check API key exists
    kaggle_json = os.path.join(os.path.expanduser("~"), ".kaggle", "kaggle.json")
    if not os.path.isfile(kaggle_json):
        print(f"\n  ❌ Kaggle API key not found at: {kaggle_json}")
        print("  Get it from: https://www.kaggle.com/settings → API → Create New Token")
        sys.exit(1)

    dest_dir = "data"
    os.makedirs(dest_dir, exist_ok=True)

    result = subprocess.run([
        "kaggle", "datasets", "download",
        "-d", KAGGLE_SLUG,
        "-p", dest_dir,
        "--unzip",
    ], capture_output=False)

    if result.returncode != 0:
        print(f"\n  ❌ Kaggle download failed (exit code {result.returncode})")
        print("  Try manually:")
        print(f"    kaggle datasets download -d {KAGGLE_SLUG} -p data --unzip")
        sys.exit(1)

    # Find the downloaded CSV (kaggle may rename it)
    for fname in [CSV_FILENAME, "Crop_Recommendation.csv", "crop_recommendation.csv"]:
        path = os.path.join(dest_dir, fname)
        if os.path.isfile(path):
            print(f"  ✅ Downloaded: {path}")
            return path

    # Search recursively in case it landed in a subfolder
    for root, _, files in os.walk(dest_dir):
        for f in files:
            if f.lower().endswith(".csv") and "crop" in f.lower():
                path = os.path.join(root, f)
                print(f"  ✅ Found: {path}")
                return path

    print(f"  ❌ Download succeeded but CSV not found in {dest_dir}/")
    print(f"  Contents: {os.listdir(dest_dir)}")
    sys.exit(1)


# ═══════════════════════════════════════════════════════════════
# Step 2 — Load and preprocess
# ═══════════════════════════════════════════════════════════════

def load_and_preprocess(csv_path: str):
    df = pd.read_csv(csv_path)
    print(f"\n  Rows: {len(df):,}   Columns: {list(df.columns)}")
    print(f"  Crop classes ({df['label'].nunique()}): {sorted(df['label'].unique().tolist())}")

    features = ["N", "P", "K", "temperature", "humidity", "ph", "rainfall"]

    # Verify all columns exist
    missing = [f for f in features + ["label"] if f not in df.columns]
    if missing:
        # Try lowercase
        df.columns = [c.lower() for c in df.columns]
        missing = [f for f in features + ["label"] if f not in df.columns]
        if missing:
            print(f"  ❌ Missing columns: {missing}")
            print(f"  Available: {list(df.columns)}")
            sys.exit(1)

    X     = df[features].values.astype(np.float32)
    y_raw = df["label"].values

    le      = LabelEncoder()
    y       = le.fit_transform(y_raw).astype(np.int64)
    classes = le.classes_.tolist()

    scaler   = StandardScaler()
    X_scaled = scaler.fit_transform(X).astype(np.float32)

    # Save scaler params — Flutter app needs these for inference
    scaler_params = {
        "mean":     scaler.mean_.tolist(),
        "scale":    scaler.scale_.tolist(),
        "features": features,
        "classes":  classes,
        "num_classes": len(classes),
    }
    with open("crop_scaler.json", "w") as f:
        json.dump(scaler_params, f, indent=2)
    print("  Saved: crop_scaler.json  (needed by Flutter app)")

    return X_scaled, y, classes, scaler_params


# ═══════════════════════════════════════════════════════════════
# Step 3 — Train
# ═══════════════════════════════════════════════════════════════

def train(csv_path: str, epochs: int, batch_size: int, lr: float):
    print("\n" + "=" * 55)
    print("Crop Recommendation Model Training")
    print("=" * 55)

    X, y, classes, scaler_params = load_and_preprocess(csv_path)
    num_classes = len(classes)

    X_train, X_val, y_train, y_val = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y,
    )
    print(f"\n  Train: {len(X_train):,}   Val: {len(X_val):,}")

    train_ds = TensorDataset(torch.from_numpy(X_train), torch.from_numpy(y_train))
    val_ds   = TensorDataset(torch.from_numpy(X_val),   torch.from_numpy(y_val))

    train_loader = DataLoader(
        train_ds, batch_size=batch_size, shuffle=True,
        num_workers=NUM_WORKERS, pin_memory=(DEVICE.type == "cuda"),
    )
    val_loader = DataLoader(
        val_ds, batch_size=batch_size, shuffle=False,
        num_workers=NUM_WORKERS, pin_memory=(DEVICE.type == "cuda"),
    )

    # Model → GPU
    model     = get_crop_model(num_classes).to(DEVICE)
    criterion = nn.CrossEntropyLoss(label_smoothing=0.05)
    optimizer = optim.AdamW(model.parameters(), lr=lr, weight_decay=1e-4)
    scheduler = optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=epochs, eta_min=1e-5)

    best_val_acc  = 0.0
    best_preds    = []
    best_labels   = []

    print(f"\n  Epochs: {epochs}  |  Batch: {batch_size}  |  LR: {lr}")
    print(f"  Classes: {num_classes} ({', '.join(classes[:5])}...)")
    print()

    for epoch in range(1, epochs + 1):
        # ── Train ──────────────────────────────────────────────
        model.train()
        train_correct = train_total = 0

        for X_batch, y_batch in train_loader:
            X_batch = X_batch.to(DEVICE, non_blocking=True)
            y_batch = y_batch.to(DEVICE, non_blocking=True)
            out     = model(X_batch)
            loss    = criterion(out, y_batch)
            optimizer.zero_grad()
            loss.backward()
            optimizer.step()
            _, pred = out.max(1)
            train_correct += (pred == y_batch).sum().item()
            train_total   += y_batch.size(0)

        # ── Validate ───────────────────────────────────────────
        model.eval()
        correct = val_total = 0
        ep_preds, ep_labels = [], []

        with torch.no_grad():
            for X_batch, y_batch in val_loader:
                X_batch = X_batch.to(DEVICE, non_blocking=True)
                y_batch = y_batch.to(DEVICE, non_blocking=True)
                out     = model(X_batch)
                _, pred = out.max(1)
                correct   += (pred == y_batch).sum().item()
                val_total += y_batch.size(0)
                ep_preds .extend(pred.cpu().numpy())
                ep_labels.extend(y_batch.cpu().numpy())

        train_acc = train_correct / train_total
        val_acc   = correct / val_total
        scheduler.step()

        # Print every 10 epochs
        if epoch % 10 == 0 or epoch == 1:
            print(f"  Epoch {epoch:3d}/{epochs}  "
                  f"Train Acc: {train_acc:.4f}  Val Acc: {val_acc:.4f}")

        if val_acc > best_val_acc:
            best_val_acc  = val_acc
            best_preds    = ep_preds
            best_labels   = ep_labels
            torch.save({
                "model_state_dict": model.state_dict(),
                "classes":          classes,
                "num_classes":      num_classes,
                "scaler_params":    scaler_params,
                "val_acc":          val_acc,
            }, SAVE_PATH)

    # ── Final report ───────────────────────────────────────────
    print(f"\n{'='*55}")
    print(f"Best Val Accuracy: {best_val_acc:.4f}")
    print("\nPer-class report:")
    print(classification_report(best_labels, best_preds, target_names=classes, zero_division=0))
    print(f"✅ Saved: {SAVE_PATH}")
    print(f"✅ Saved: crop_scaler.json")
    print(f"\nNext: python export_pipeline.py --crop-model")


# ═══════════════════════════════════════════════════════════════
# Entry point
# ═══════════════════════════════════════════════════════════════

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Train crop recommendation model",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python train_crop_model.py                         # auto-download CSV
  python train_crop_model.py --csv data\\Crop_recommendation.csv
  python train_crop_model.py --epochs 150 --lr 5e-4
        """,
    )
    parser.add_argument(
        "--csv", type=str, default=None,
        help="Path to Crop_recommendation.csv. "
             "If not provided, auto-downloads from Kaggle.",
    )
    parser.add_argument("--epochs",     type=int,   default=80)
    parser.add_argument("--batch-size", type=int,   default=256)
    parser.add_argument("--lr",         type=float, default=1e-3)
    args = parser.parse_args()

    csv_path = find_csv(args.csv)
    train(
        csv_path   = csv_path,
        epochs     = args.epochs,
        batch_size = args.batch_size,
        lr         = args.lr,
    )