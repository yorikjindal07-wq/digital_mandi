import argparse
import csv
import gc
import json
import os
import platform
import random

import numpy as np
import torch
import torch.nn as nn
import torch.optim as optim
from sklearn.metrics import classification_report, f1_score
from torch.utils.data import DataLoader, Subset
from tqdm import tqdm

from dataset import get_dataloaders
from model import get_disease_model


SEED = 42
torch.manual_seed(SEED)
np.random.seed(SEED)
random.seed(SEED)
if torch.cuda.is_available():
    torch.cuda.manual_seed_all(SEED)

DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")
USE_AMP = DEVICE.type == "cuda"

DATA_DIR = "data"
BATCH_SIZE = 8
ACCUM_STEPS = 2
BASE_LR = 3e-4
FINETUNE_LR = 1e-4
EPOCHS = 30
PATIENCE = 8
SAVE_PATH = "best_vision_model.pth"
RESUME_PATH = "checkpoint_last.pth"
NUM_WORKERS = 0 if platform.system() == "Windows" else 4
UNFREEZE_EPOCH = 4


def print_gpu_info(batch_size: int, accum_steps: int):
    print(f"Device:     {DEVICE}")
    if DEVICE.type == "cuda":
        props = torch.cuda.get_device_properties(0)
        vram = props.total_memory / 1e9
        print(f"GPU:        {props.name}")
        print(f"VRAM:       {vram:.1f} GB")
        print("AMP:        Enabled")
        print(f"Effective batch: {batch_size} x {accum_steps} = {batch_size * accum_steps}")
        if vram < 6:
            print("Low VRAM detected. Batch size 8 is recommended.")
    else:
        print("GPU:        Not found - running on CPU")


def get_image_size(use_efficient: bool) -> int:
    return 300 if use_efficient else 224


def create_optimizer(model: nn.Module, lr: float) -> optim.Optimizer:
    return optim.AdamW(
        filter(lambda p: p.requires_grad, model.parameters()),
        lr=lr,
        weight_decay=1e-4,
    )


def create_scheduler(optimizer: optim.Optimizer):
    return optim.lr_scheduler.ReduceLROnPlateau(
        optimizer,
        mode="max",
        factor=0.5,
        patience=2,
        min_lr=1e-6,
    )


def unfreeze_backbone(model: nn.Module):
    unfrozen = 0
    for param in model.parameters():
        if not param.requires_grad:
            param.requires_grad = True
            unfrozen += 1

    total = sum(1 for _ in model.parameters())
    trainable = sum(int(p.requires_grad) for p in model.parameters())
    print(f"  Unfrozen {unfrozen} parameter tensors ({trainable}/{total} trainable)")


def train_epoch(model, loader, criterion, optimizer, scaler, epoch, accum_steps):
    model.train()
    total_loss = 0.0
    correct = 0
    total = 0
    nan_batches = 0
    optimizer.zero_grad(set_to_none=True)

    for batch_idx, (imgs, labels) in enumerate(tqdm(loader, leave=False, desc=f"Ep{epoch}")):
        imgs = imgs.to(DEVICE, non_blocking=True)
        labels = labels.to(DEVICE, non_blocking=True)

        with torch.cuda.amp.autocast(enabled=USE_AMP):
            out = model(imgs)
            loss = criterion(out, labels)

        if torch.isnan(loss) or torch.isinf(loss):
            nan_batches += 1
            optimizer.zero_grad(set_to_none=True)
            continue

        scaler.scale(loss / accum_steps).backward()
        total_loss += loss.item()
        _, pred = out.detach().max(1)
        correct += (pred == labels).sum().item()
        total += labels.size(0)

        if (batch_idx + 1) % accum_steps == 0:
            scaler.unscale_(optimizer)
            torch.nn.utils.clip_grad_norm_(model.parameters(), max_norm=1.0)
            scaler.step(optimizer)
            scaler.update()
            optimizer.zero_grad(set_to_none=True)

    if len(loader) % accum_steps != 0:
        scaler.unscale_(optimizer)
        torch.nn.utils.clip_grad_norm_(model.parameters(), max_norm=1.0)
        scaler.step(optimizer)
        scaler.update()
        optimizer.zero_grad(set_to_none=True)

    if nan_batches:
        print(f"  Skipped {nan_batches} invalid batches")

    denom = max(len(loader) - nan_batches, 1)
    return total_loss / denom, correct / max(total, 1)


@torch.no_grad()
def validate(model, loader, criterion, classes):
    model.eval()
    total_loss = 0.0
    correct = 0
    total = 0
    all_preds = []
    all_labels = []

    for imgs, labels in tqdm(loader, leave=False, desc="Val"):
        imgs = imgs.to(DEVICE, non_blocking=True)
        labels = labels.to(DEVICE, non_blocking=True)

        with torch.cuda.amp.autocast(enabled=USE_AMP):
            out = model(imgs)
            loss = criterion(out, labels)

        _, pred = out.max(1)
        if not (torch.isnan(loss) or torch.isinf(loss)):
            total_loss += loss.item()
        correct += (pred == labels).sum().item()
        total += labels.size(0)
        all_preds.extend(pred.cpu().numpy())
        all_labels.extend(labels.cpu().numpy())

    macro_f1 = f1_score(all_labels, all_preds, average="macro", zero_division=0)
    return total_loss / max(len(loader), 1), correct / max(total, 1), macro_f1, all_preds, all_labels


def save_checkpoint(path, epoch, model, optimizer, scaler, scheduler, best_f1, classes, use_efficient):
    torch.save(
        {
            "epoch": epoch,
            "model_state_dict": model.state_dict(),
            "optimizer_state": optimizer.state_dict(),
            "scaler_state": scaler.state_dict(),
            "scheduler_state": scheduler.state_dict(),
            "best_f1": best_f1,
            "classes": classes,
            "num_classes": len(classes),
            "use_efficient": use_efficient,
        },
        path,
    )


def load_checkpoint(path, model, optimizer, scaler, scheduler):
    ckpt = torch.load(path, map_location=DEVICE, weights_only=False)
    model.load_state_dict(ckpt["model_state_dict"])
    optimizer.load_state_dict(ckpt["optimizer_state"])
    scaler.load_state_dict(ckpt["scaler_state"])
    scheduler.load_state_dict(ckpt["scheduler_state"])
    return ckpt["epoch"], ckpt["best_f1"]


def init_csv(path):
    with open(path, "w", newline="") as f:
        csv.writer(f).writerow(["epoch", "train_loss", "val_loss", "train_acc", "val_acc", "val_f1", "lr"])


def log_csv(path, epoch, tl, vl, ta, va, vf, lr):
    with open(path, "a", newline="") as f:
        csv.writer(f).writerow(
            [epoch, round(tl, 5), round(vl, 5), round(ta, 4), round(va, 4), round(vf, 4), f"{lr:.2e}"]
        )


def main(use_efficient: bool, quick: bool, resume: bool, batch_size: int, accum_steps: int):
    print("=" * 58)
    print("Digital Mandi - Training")
    print("=" * 58)
    print_gpu_info(batch_size, accum_steps)
    print(f"Backbone:   {'EfficientNet-B3' if use_efficient else 'ResNet18'}")
    print(f"Mode:       {'QUICK TEST' if quick else 'Full training'}")
    print("=" * 58)

    img_size = get_image_size(use_efficient)
    train_loader, val_loader, classes = get_dataloaders(
        DATA_DIR,
        batch_size=batch_size,
        img_size=img_size,
        use_weighted_sampler=False,
    )
    num_classes = len(classes)
    raw_train_data = train_loader.dataset

    if quick:
        print("\n[QUICK MODE] 500 train + 100 val, 3 epochs")
        t_sub = Subset(raw_train_data, list(range(min(500, len(raw_train_data)))))
        v_sub = Subset(val_loader.dataset, list(range(min(100, len(val_loader.dataset)))))
        train_loader = DataLoader(
            t_sub,
            batch_size=batch_size,
            shuffle=True,
            num_workers=NUM_WORKERS,
            pin_memory=(DEVICE.type == "cuda"),
        )
        val_loader = DataLoader(
            v_sub,
            batch_size=batch_size,
            shuffle=False,
            num_workers=NUM_WORKERS,
            pin_memory=(DEVICE.type == "cuda"),
        )
        epochs = 3
        patience = 99
    else:
        epochs = EPOCHS
        patience = PATIENCE

    model = get_disease_model(num_classes, use_efficient=use_efficient, pretrained=True).to(DEVICE)
    criterion = nn.CrossEntropyLoss(label_smoothing=0.1)
    print("\nLoss: CrossEntropyLoss(label_smoothing=0.1)")
    print("Sampler: standard shuffle baseline")

    optimizer = create_optimizer(model, BASE_LR)
    scaler = torch.cuda.amp.GradScaler(enabled=USE_AMP)
    scheduler = create_scheduler(optimizer)

    csv_path = "training_log.csv"
    if not resume:
        init_csv(csv_path)

    history = {k: [] for k in ("train_loss", "val_loss", "train_acc", "val_acc", "val_f1")}
    best_f1 = 0.0
    patience_count = 0
    start_epoch = 1
    backbone_unfrozen = False

    if resume and os.path.exists(RESUME_PATH):
        print(f"\nResuming from: {RESUME_PATH}")
        start_epoch, best_f1 = load_checkpoint(RESUME_PATH, model, optimizer, scaler, scheduler)
        start_epoch += 1
        backbone_unfrozen = start_epoch > UNFREEZE_EPOCH
        print(f"  Epoch {start_epoch}, best F1={best_f1:.4f}")
    elif resume:
        print(f"\nNo checkpoint at {RESUME_PATH} - starting fresh")

    print("\n" + "-" * 58)
    print(f"Classes:         {num_classes}")
    print(f"Train samples:   {len(train_loader.dataset):,}")
    print(f"Val samples:     {len(val_loader.dataset):,}")
    print(f"Image size:      {img_size}")
    print(f"Phase 1:         Epochs 1-{UNFREEZE_EPOCH - 1}: head only, LR={BASE_LR:.0e}")
    print(f"Phase 2:         Epoch {UNFREEZE_EPOCH}+: full backbone, LR={FINETUNE_LR:.0e}")
    print("Mixup:           disabled for clean baseline")
    print(f"Effective batch: {batch_size} x {accum_steps} = {batch_size * accum_steps}")
    print("-" * 58)

    for epoch in range(start_epoch, epochs + 1):
        lr = optimizer.param_groups[0]["lr"]
        print(f"\n{'=' * 46}  Epoch {epoch}/{epochs}  LR={lr:.2e}")

        if DEVICE.type == "cuda":
            used = torch.cuda.memory_allocated(0) / 1e9
            total_vram = torch.cuda.get_device_properties(0).total_memory / 1e9
            print(f"  VRAM: {used:.2f}/{total_vram:.1f} GB")

        if epoch == UNFREEZE_EPOCH and not backbone_unfrozen and not quick:
            print(f"\n  [Phase 2] Unfreezing full backbone at epoch {epoch}")
            unfreeze_backbone(model)
            optimizer = create_optimizer(model, FINETUNE_LR)
            scheduler = create_scheduler(optimizer)
            backbone_unfrozen = True

        train_loss, train_acc = train_epoch(
            model=model,
            loader=train_loader,
            criterion=criterion,
            optimizer=optimizer,
            scaler=scaler,
            epoch=epoch,
            accum_steps=accum_steps,
        )
        val_loss, val_acc, val_f1, preds, labels_list = validate(model, val_loader, criterion, classes)
        scheduler.step(val_f1)

        if DEVICE.type == "cuda":
            torch.cuda.empty_cache()
        gc.collect()

        history["train_loss"].append(train_loss)
        history["val_loss"].append(val_loss)
        history["train_acc"].append(train_acc)
        history["val_acc"].append(val_acc)
        history["val_f1"].append(val_f1)
        log_csv(csv_path, epoch, train_loss, val_loss, train_acc, val_acc, val_f1, lr)

        print(f"  Train -> Loss: {train_loss:.4f}  Acc: {train_acc:.4f}")
        print(f"  Val   -> Loss: {val_loss:.4f}  Acc: {val_acc:.4f}  Macro F1: {val_f1:.4f}")

        per_class = f1_score(labels_list, preds, average=None, zero_division=0)
        for cls, score in zip(classes, per_class):
            status = "OK" if score >= 0.70 else "LOW"
            print(f"  {cls:30s}: F1={score:.3f}  {status}")

        if val_f1 > best_f1:
            best_f1 = val_f1
            patience_count = 0
            torch.save(
                {
                    "epoch": epoch,
                    "model_state_dict": model.state_dict(),
                    "val_acc": val_acc,
                    "val_f1": val_f1,
                    "classes": classes,
                    "num_classes": num_classes,
                    "use_efficient": use_efficient,
                },
                SAVE_PATH,
            )
            print(f"  Best model saved - F1={best_f1:.4f}")
        else:
            patience_count += 1
            print(f"  No improvement ({patience_count}/{patience})")
            if patience_count >= patience:
                print(f"\nEarly stopping at epoch {epoch}")
                break

        if not quick:
            save_checkpoint(
                RESUME_PATH,
                epoch,
                model,
                optimizer,
                scaler,
                scheduler,
                best_f1,
                classes,
                use_efficient,
            )

    print("\n" + "=" * 58)
    print("FINAL EVALUATION")
    ckpt = torch.load(SAVE_PATH, map_location=DEVICE, weights_only=False)
    model.load_state_dict(ckpt["model_state_dict"])
    _, final_acc, final_f1, final_preds, final_labels = validate(model, val_loader, criterion, classes)
    print(f"Final Accuracy: {final_acc:.4f}   Macro F1: {final_f1:.4f}")

    present_labels = sorted(set(final_labels) | set(final_preds))
    present_names = [classes[i] for i in present_labels if i < len(classes)]
    print(
        classification_report(
            final_labels,
            final_preds,
            labels=present_labels,
            target_names=present_names,
            zero_division=0,
        )
    )

    with open("training_log.json", "w") as f:
        json.dump(history, f, indent=2)

    if quick:
        print("\nQuick test passed")
    else:
        print(f"\nDone. Best F1={best_f1:.4f} -> {SAVE_PATH}")
        print("Next: python export_pipeline.py")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--efficient", action="store_true", help="Use EfficientNet-B3 (default: ResNet18)")
    parser.add_argument("--quick", action="store_true", help="3-epoch pipeline test with 500 images")
    parser.add_argument("--resume", action="store_true", help="Resume from checkpoint_last.pth")
    parser.add_argument("--batch-size", type=int, default=BATCH_SIZE, help=f"Batch size (default {BATCH_SIZE})")
    parser.add_argument(
        "--accum-steps",
        type=int,
        default=ACCUM_STEPS,
        help=f"Gradient accumulation steps (default {ACCUM_STEPS})",
    )
    args = parser.parse_args()

    main(
        use_efficient=args.efficient,
        quick=args.quick,
        resume=args.resume,
        batch_size=args.batch_size,
        accum_steps=args.accum_steps,
    )