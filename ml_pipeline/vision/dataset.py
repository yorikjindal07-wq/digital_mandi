import os
import platform
from collections import Counter

from torch.utils.data import DataLoader, WeightedRandomSampler
from torchvision import datasets, transforms


NUM_WORKERS = 0 if platform.system() == "Windows" else 4


def get_train_transform(img_size: int) -> transforms.Compose:
    return transforms.Compose([
        transforms.Resize((img_size + 32, img_size + 32)),
        transforms.RandomResizedCrop(img_size, scale=(0.8, 1.0)),
        transforms.RandomHorizontalFlip(p=0.5),
        transforms.RandomRotation(degrees=15),
        transforms.ColorJitter(
            brightness=0.2,
            contrast=0.2,
            saturation=0.2,
            hue=0.05,
        ),
        transforms.ToTensor(),
        transforms.Normalize(
            mean=[0.485, 0.456, 0.406],
            std=[0.229, 0.224, 0.225],
        ),
    ])


def get_val_transform(img_size: int) -> transforms.Compose:
    return transforms.Compose([
        transforms.Resize((img_size, img_size)),
        transforms.ToTensor(),
        transforms.Normalize(
            mean=[0.485, 0.456, 0.406],
            std=[0.229, 0.224, 0.225],
        ),
    ])


def get_dataloaders(
    data_dir: str,
    batch_size: int = 32,
    img_size: int = 224,
    num_workers: int | None = None,
    use_weighted_sampler: bool = False,
):
    if num_workers is None:
        num_workers = NUM_WORKERS

    train_path = os.path.join(data_dir, "train")
    val_path = os.path.join(data_dir, "val")

    if not os.path.exists(train_path):
        raise FileNotFoundError(
            f"Training data not found at: {train_path}\n"
            "Run: python download_datasets.py"
        )

    train_dataset = datasets.ImageFolder(
        root=train_path,
        transform=get_train_transform(img_size),
    )
    val_dataset = datasets.ImageFolder(
        root=val_path,
        transform=get_val_transform(img_size),
    )

    classes = train_dataset.classes
    counts = Counter(train_dataset.targets)

    print(f"Loaded {len(train_dataset):,} training, {len(val_dataset):,} val images")
    print(f"Classes ({len(classes)}): {classes}")
    print(f"num_workers: {num_workers} | pin_memory: True | img_size: {img_size}")
    print("Class distribution (train):")
    for idx, cls in enumerate(classes):
        n = counts[idx]
        bar = "#" * min(n // 300, 24)
        print(f"  {cls:30s}: {n:5,}  {bar}")

    sampler = None
    shuffle = True
    if use_weighted_sampler:
        class_weights = {idx: 1.0 / max(cnt, 1) for idx, cnt in counts.items()}
        sample_weights = [class_weights[label] for label in train_dataset.targets]
        sampler = WeightedRandomSampler(
            weights=sample_weights,
            num_samples=len(train_dataset),
            replacement=True,
        )
        shuffle = False

    loader_kwargs = dict(
        batch_size=batch_size,
        num_workers=num_workers,
        pin_memory=True,
        persistent_workers=num_workers > 0,
        prefetch_factor=2 if num_workers > 0 else None,
    )

    train_loader = DataLoader(
        train_dataset,
        shuffle=shuffle,
        sampler=sampler,
        **loader_kwargs,
    )
    val_loader = DataLoader(
        val_dataset,
        shuffle=False,
        **loader_kwargs,
    )

    return train_loader, val_loader, classes