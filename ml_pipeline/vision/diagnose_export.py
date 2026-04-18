# diagnose_export.py - extended version
import sys, os, traceback

print("Python:", sys.version)
print("Working dir:", os.getcwd())

print("\n--- Test 1: torch")
try:
    import torch
    print(f"  OK torch {torch.__version__}")
except Exception as e:
    print(f"  FAIL: {e}"); traceback.print_exc(); sys.exit(1)

print("\n--- Test 2: torchvision alone")
try:
    import torchvision
    print(f"  OK torchvision {torchvision.__version__}")
except Exception as e:
    print(f"  FAIL torchvision: {e}")
    traceback.print_exc()

print("\n--- Test 3: torchvision.models")
try:
    from torchvision.models import resnet18, ResNet18_Weights
    print("  OK resnet18")
except Exception as e:
    print(f"  FAIL resnet18: {e}")
    traceback.print_exc()

print("\n--- Test 4: EfficientNet")
try:
    from torchvision.models import efficientnet_b3, EfficientNet_B3_Weights
    print("  OK efficientnet_b3")
except Exception as e:
    print(f"  FAIL efficientnet_b3: {e}")
    traceback.print_exc()

print("\n--- Test 5: model.py line by line")
try:
    import torch.nn as nn
    print("  OK nn")
    from torchvision.models import resnet18, ResNet18_Weights
    print("  OK resnet18 import")
    from torchvision.models import efficientnet_b3, EfficientNet_B3_Weights
    print("  OK efficientnet_b3 import")
    
    # Try building resnet18
    m = resnet18(weights=ResNet18_Weights.DEFAULT)
    print("  OK resnet18 built")
    
    # Try building efficientnet_b3
    m2 = efficientnet_b3(weights=EfficientNet_B3_Weights.DEFAULT)
    print("  OK efficientnet_b3 built")
except Exception as e:
    print(f"  FAIL: {e}")
    traceback.print_exc()

print("\n--- Test 6: protobuf version")
try:
    import google.protobuf
    print(f"  protobuf version: {google.protobuf.__version__}")
except Exception as e:
    print(f"  protobuf import failed: {e}")

print("\n--- Test 7: numpy version")
try:
    import numpy as np
    print(f"  numpy version: {np.__version__}")
except Exception as e:
    print(f"  numpy failed: {e}")

print("\n--- Test 8: read model.py source")
try:
    with open("model.py") as f:
        lines = f.readlines()
    print(f"  model.py has {len(lines)} lines")
    print("  First 10 lines:")
    for i, line in enumerate(lines[:10]):
        print(f"    {i+1}: {line.rstrip()}")
except Exception as e:
    print(f"  Cannot read model.py: {e}")

print("\n--- Test 9: exec model.py content directly")
try:
    exec(open("model.py").read())
    print("  OK model.py executed without error")
except Exception as e:
    print(f"  FAIL executing model.py: {e}")
    traceback.print_exc()

print("\nDiagnosis complete")