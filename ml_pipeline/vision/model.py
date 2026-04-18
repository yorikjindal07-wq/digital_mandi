import os

import torch
import torch.nn as nn
from torch.hub import load_state_dict_from_url
from torchvision.models import (
    ResNet18_Weights,
    EfficientNet_B3_Weights,
    efficientnet_b3,
    resnet18,
)


class DiseaseModelResNet(nn.Module):
    def __init__(self, num_classes: int, pretrained: bool = True):
        super().__init__()
        weights = ResNet18_Weights.DEFAULT if pretrained else None
        backbone = resnet18(weights=weights)

        for param in backbone.parameters():
            param.requires_grad = False

        in_features = backbone.fc.in_features
        backbone.fc = nn.Sequential(
            nn.Dropout(p=0.3),
            nn.Linear(in_features, 256),
            nn.ReLU(inplace=True),
            nn.Dropout(p=0.2),
            nn.Linear(256, num_classes),
        )
        self.backbone = backbone

        for param in self.backbone.fc.parameters():
            param.requires_grad = True

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return self.backbone(x)


class DiseaseModelEfficient(nn.Module):
    def __init__(self, num_classes: int, pretrained: bool = True):
        super().__init__()
        weights = EfficientNet_B3_Weights.DEFAULT if pretrained else None
        backbone = self._load_backbone(weights)

        for param in backbone.parameters():
            param.requires_grad = False

        in_features = backbone.classifier[1].in_features
        backbone.classifier = nn.Sequential(
            nn.Dropout(p=0.3),
            nn.Linear(in_features, num_classes),
        )
        self.backbone = backbone

        for param in self.backbone.classifier.parameters():
            param.requires_grad = True

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return self.backbone(x)

    @staticmethod
    def _load_backbone(weights):
        if weights is None:
            return efficientnet_b3(weights=None)

        try:
            return efficientnet_b3(weights=weights)
        except RuntimeError as exc:
            message = str(exc)
            if "invalid hash value" not in message:
                raise

            cache_file = os.path.join(
                os.path.expanduser("~"),
                ".cache",
                "torch",
                "hub",
                "checkpoints",
                "efficientnet_b3_rwightman-cf984f9c.pth",
            )
            if os.path.exists(cache_file):
                try:
                    os.remove(cache_file)
                    print("  Removed corrupted EfficientNet-B3 cache file. Retrying download...")
                except OSError:
                    raise RuntimeError(
                        "EfficientNet-B3 weights failed hash validation and the cached file "
                        f"could not be removed automatically: {cache_file}"
                    ) from exc

            try:
                return efficientnet_b3(weights=weights)
            except RuntimeError as retry_exc:
                retry_message = str(retry_exc)
                if "invalid hash value" not in retry_message:
                    raise

                print("  Torchvision hash check is still failing. Loading the official weights without hash enforcement...")
                backbone = efficientnet_b3(weights=None)
                state_dict = load_state_dict_from_url(
                    weights.url,
                    progress=True,
                    check_hash=False,
                )
                backbone.load_state_dict(state_dict)
                return backbone


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

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return self.net(x)


def get_disease_model(
    num_classes: int,
    use_efficient: bool = True,
    pretrained: bool = True,
) -> nn.Module:
    if use_efficient:
        model = DiseaseModelEfficient(num_classes=num_classes, pretrained=pretrained)
        print(f"  Model: EfficientNet-B3 -> {num_classes} classes")
        print("  Head input features: 1536")
    else:
        model = DiseaseModelResNet(num_classes=num_classes, pretrained=pretrained)
        print(f"  Model: ResNet18 -> {num_classes} classes")
        print("  Head input features: 512")

    trainable = sum(p.numel() for p in model.parameters() if p.requires_grad)
    total = sum(p.numel() for p in model.parameters())
    print(f"  Trainable params: {trainable:,} / {total:,} total")
    return model


def get_model_info(model: nn.Module) -> dict:
    trainable = sum(p.numel() for p in model.parameters() if p.requires_grad)
    total = sum(p.numel() for p in model.parameters())
    return {
        "class": model.__class__.__name__,
        "trainable_params": trainable,
        "total_params": total,
        "frozen_params": total - trainable,
    }


def get_crop_model(num_classes: int = 22) -> nn.Module:
    return CropRecommendationModel(num_classes=num_classes)


if __name__ == "__main__":
    print("Testing models...")

    resnet = get_disease_model(num_classes=4, use_efficient=False)
    out = resnet(torch.randn(2, 3, 224, 224))
    assert out.shape == (2, 4)
    print("ResNet18 check passed")

    efficient = get_disease_model(num_classes=4, use_efficient=True)
    out = efficient(torch.randn(2, 3, 300, 300))
    assert out.shape == (2, 4)
    print("EfficientNet-B3 check passed")
