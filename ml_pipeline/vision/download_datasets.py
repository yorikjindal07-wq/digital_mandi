# ═══════════════════════════════════════════════════════════════
# ml_pipeline/vision/download_datasets.py  — FULLY CORRECTED
#
# Downloads and merges ALL classes from both datasets:
#
# PlantVillage (arjuntejaswi/plant-village):
#   Apple:     Apple___Apple_scab, Apple___Black_rot,
#              Apple___Cedar_apple_rust, Apple___healthy
#   Blueberry: Blueberry___healthy
#   Cherry:    Cherry___Powdery_mildew, Cherry___healthy
#   Corn:      Corn___Cercospora_leaf_spot, Corn___Common_rust,
#              Corn___Northern_Leaf_Blight, Corn___healthy
#   Grape:     Grape___Black_rot, Grape___Esca, Grape___Leaf_blight, Grape___healthy
#   Orange:    Orange___Haunglongbing
#   Peach:     Peach___Bacterial_spot, Peach___healthy
#   Pepper:    Pepper___Bacterial_spot, Pepper___healthy
#   Potato:    Potato___Early_blight, Potato___Late_blight, Potato___healthy
#   Raspberry: Raspberry___healthy
#   Soybean:   Soybean___healthy
#   Squash:    Squash___Powdery_mildew
#   Strawberry:Strawberry___Leaf_scorch, Strawberry___healthy
#   Tomato:    Tomato___Bacterial_spot, Tomato___Early_blight,
#              Tomato___Late_blight, Tomato___Leaf_Mold,
#              Tomato___Septoria_leaf_spot, Tomato___Spider_mites,
#              Tomato___Target_Spot, Tomato___Yellow_Leaf_Curl_Virus,
#              Tomato___Mosaic_virus, Tomato___healthy
#
# Mendeley (vipoooool/new-plant-diseases-dataset):
#   Same 38 classes as PlantVillage (different images, train/val split)
#
# UNIFIED CLASSES (what the app recognises):
#   We group all diseases by crop+disease type into 13 classes:
#   healthy, early_blight, late_blight, leaf_mold,
#   powdery_mildew, black_rot, bacterial_spot, leaf_blight,
#   leaf_scorch, common_rust, cercospora_leaf_spot, septoria_leaf_spot,
#   yellow_leaf_curl_virus
#
# Run:
#   python download_datasets.py
#   python download_datasets.py --skip-kaggle      (if already downloaded)
#   python download_datasets.py --skip-inaturalist (skip API photos)
# ═══════════════════════════════════════════════════════════════

import os
import shutil
import random
import zipfile
import requests
import time
from pathlib import Path
from PIL import Image
from tqdm import tqdm

random.seed(42)

OUTPUT_DIR = Path("data")
VAL_RATIO  = 0.20
MIN_IMAGES = 300   # warn if a class has fewer than this

# ═══════════════════════════════════════════════════════════════
# CLASS MAP
# Maps every PlantVillage/Mendeley folder name → unified label
# All 38 PlantVillage classes are covered.
# ═══════════════════════════════════════════════════════════════
CLASS_MAP = {
    # ── HEALTHY (all crops merged) ──────────────────────────────
    "Apple___healthy":                    "healthy",
    "Blueberry___healthy":                "healthy",
    "Cherry_(including_sour)___healthy":  "healthy",
    "Cherry___healthy":                   "healthy",
    "Corn_(maize)___healthy":             "healthy",
    "Corn___healthy":                     "healthy",
    "Grape___healthy":                    "healthy",
    "Peach___healthy":                    "healthy",
    "Pepper,_bell___healthy":             "healthy",
    "Pepper___healthy":                   "healthy",
    "Potato___healthy":                   "healthy",
    "Raspberry___healthy":                "healthy",
    "Soybean___healthy":                  "healthy",
    "Strawberry___healthy":               "healthy",
    "Tomato___healthy":                   "healthy",
    "Tomato_healthy":                     "healthy",   # PlantVillage variant name

    # ── EARLY BLIGHT (Alternaria) ───────────────────────────────
    "Potato___Early_blight":              "early_blight",
    "Tomato___Early_blight":              "early_blight",

    # ── LATE BLIGHT (Phytophthora) ──────────────────────────────
    "Potato___Late_blight":               "late_blight",
    "Tomato___Late_blight":               "late_blight",

    # ── LEAF MOLD (Passalora fulva) ─────────────────────────────
    "Tomato___Leaf_Mold":                 "leaf_mold",
    "Tomato_Leaf_Mold":                   "leaf_mold",   # PlantVillage variant

    # ── POWDERY MILDEW ──────────────────────────────────────────
    "Cherry_(including_sour)___Powdery_mildew": "powdery_mildew",
    "Cherry___Powdery_mildew":            "powdery_mildew",
    "Squash___Powdery_mildew":            "powdery_mildew",

    # ── BLACK ROT ───────────────────────────────────────────────
    "Apple___Black_rot":                  "black_rot",
    "Grape___Black_rot":                  "black_rot",

    # ── BACTERIAL SPOT ──────────────────────────────────────────
    "Peach___Bacterial_spot":             "bacterial_spot",
    "Pepper,_bell___Bacterial_spot":      "bacterial_spot",
    "Pepper___Bacterial_spot":            "bacterial_spot",
    "Tomato___Bacterial_spot":            "bacterial_spot",

    # ── LEAF BLIGHT ─────────────────────────────────────────────
    "Corn_(maize)___Northern_Leaf_Blight":"leaf_blight",
    "Corn___Northern_Leaf_Blight":        "leaf_blight",
    "Grape___Leaf_blight_(Isariopsis_Leaf_Spot)": "leaf_blight",
    "Grape___Leaf_blight":                "leaf_blight",

    # ── LEAF SCORCH ─────────────────────────────────────────────
    "Strawberry___Leaf_scorch":           "leaf_scorch",

    # ── COMMON RUST ─────────────────────────────────────────────
    "Corn_(maize)___Common_rust_":        "common_rust",
    "Corn___Common_rust":                 "common_rust",

    # ── CERCOSPORA / GRAY LEAF SPOT ─────────────────────────────
    "Corn_(maize)___Cercospora_leaf_spot Gray_leaf_spot": "cercospora_leaf_spot",
    "Corn___Cercospora_leaf_spot":        "cercospora_leaf_spot",

    # ── SEPTORIA LEAF SPOT ──────────────────────────────────────
    "Tomato___Septoria_leaf_spot":        "septoria_leaf_spot",
    "Tomato_Septoria_leaf_spot":          "septoria_leaf_spot",

    # ── YELLOW LEAF CURL VIRUS ──────────────────────────────────
    "Tomato___Tomato_Yellow_Leaf_Curl_Virus": "yellow_leaf_curl_virus",
    "Tomato_Yellow_Leaf_Curl_Virus":      "yellow_leaf_curl_virus",

    # ── ADDITIONAL DISEASES (PlantVillage) ──────────────────────
    "Apple___Apple_scab":                 "apple_scab",
    "Apple___Cedar_apple_rust":           "cedar_apple_rust",
    "Grape___Esca_(Black_Measles)":       "grape_esca",
    "Grape___Esca":                       "grape_esca",
    "Orange___Haunglongbing_(Citrus_greening)": "citrus_greening",
    "Orange___Haunglongbing":             "citrus_greening",
    "Tomato___Spider_mites Two-spotted_spider_mite": "spider_mites",
    "Tomato___Spider_mites":              "spider_mites",
    "Tomato___Target_Spot":               "target_spot",
    "Tomato_Target_Spot":                 "target_spot",
    "Tomato___Tomato_mosaic_virus":       "mosaic_virus",
    "Tomato_mosaic_virus":                "mosaic_virus",
}

# ═══════════════════════════════════════════════════════════════
# iNaturalist taxon IDs — much more reliable than text search
# Find more at: https://www.inaturalist.org/taxa/search
# ═══════════════════════════════════════════════════════════════
INAT_TAXON_IDS = {
    "early_blight":        120164,   # Alternaria solani
    "late_blight":         352035,   # Phytophthora infestans
    "leaf_mold":           175541,   # Passalora fulva
    "powdery_mildew":      793510,   # Erysiphales order
    "bacterial_spot":      None,     # No reliable iNat taxon
    "common_rust":         118098,   # Puccinia sorghi
    "septoria_leaf_spot":  207697,   # Septoria lycopersici
}


# ═══════════════════════════════════════════════════════════════
# STEP 1 — Download Kaggle datasets
# ═══════════════════════════════════════════════════════════════

def download_kaggle_datasets():
    print("\n" + "="*60)
    print("STEP 1: Downloading Kaggle datasets")
    print("="*60)

    datasets = [
        {
            "slug":    "arjuntejaswi/plant-village",
            "extract": "PlantVillage",
            "desc":    "PlantVillage (38 classes, ~54k images)",
        },
        {
            "slug":    "vipoooool/new-plant-diseases-dataset",
            "extract": "MendeleyPlants",
            "desc":    "Mendeley Plant Diseases (38 classes, ~87k images)",
        },
    ]

    for ds in datasets:
        dest = Path(ds["extract"])

        # Check if it already has images
        existing = list(dest.rglob("*.jpg")) + list(dest.rglob("*.JPG"))
        if dest.exists() and len(existing) > 1000:
            print(f"  ✅ {ds['extract']} already has {len(existing):,} images — skipping download")
            continue

        print(f"\n  Downloading: {ds['desc']}")
        print(f"  Slug: {ds['slug']}")

        # Download WITHOUT --unzip so we control extraction ourselves
        result = os.system(
            f"kaggle datasets download -d {ds['slug']} -p {ds['extract']}"
        )

        if result != 0:
            print(f"  ❌ Download failed for {ds['slug']}")
            continue

        # Find and extract the zip ourselves (avoids kaggle's buggy --unzip)
        zip_files = list(dest.glob("*.zip"))
        if not zip_files:
            print(f"  ⚠️  No zip found in {dest}/")
            continue

        zip_path = zip_files[0]
        print(f"  Extracting: {zip_path} ({zip_path.stat().st_size/1e9:.2f} GB)")
        _extract_zip(zip_path, dest)

        img_count = len(list(dest.rglob("*.jpg"))) + len(list(dest.rglob("*.JPG")))
        print(f"  ✅ {ds['extract']}: {img_count:,} images extracted")


def _extract_zip(zip_path: Path, dest_dir: Path):
    """
    Extract zip file properly.
    We do this ourselves because kaggle CLI's --unzip
    sometimes fails silently on large files on Windows.
    """
    with zipfile.ZipFile(zip_path, 'r') as zf:
        members = zf.namelist()
        print(f"  Zip contains {len(members):,} files")

        for member in tqdm(members, desc="  Extracting", leave=False):
            if member.endswith('/'):
                continue  # Skip directories

            # Only extract image files
            ext = Path(member).suffix.lower()
            if ext not in ('.jpg', '.jpeg', '.png', '.JPG', '.JPEG', '.PNG'):
                continue

            dest_file = dest_dir / member
            if dest_file.exists():
                continue

            dest_file.parent.mkdir(parents=True, exist_ok=True)
            try:
                with zf.open(member) as src, open(dest_file, 'wb') as dst:
                    dst.write(src.read())
            except Exception:
                pass


# ═══════════════════════════════════════════════════════════════
# STEP 2 — Download from iNaturalist (using taxon_id — reliable)
# ═══════════════════════════════════════════════════════════════

def download_inaturalist_images(label: str, taxon_id: int, max_images: int = 200):
    dest = Path(f"iNaturalist/{label}")
    dest.mkdir(parents=True, exist_ok=True)

    existing = len(list(dest.glob("*.jpg")))
    if existing >= max_images:
        print(f"  ✅ iNaturalist/{label}: already {existing} images")
        return

    print(f"\n  Fetching iNaturalist: {label} (taxon_id={taxon_id})")

    base_url   = "https://api.inaturalist.org/v1/observations"
    downloaded = existing
    page       = 1

    while downloaded < max_images:
        params = {
            "taxon_id":     taxon_id,
            "quality_grade":"research",   # Expert-verified only
            "photos":       "true",
            "per_page":     50,
            "page":         page,
            "order_by":     "votes",
        }
        try:
            resp = requests.get(base_url, params=params, timeout=20)
            if resp.status_code == 429:
                print("    Rate limited — waiting 30s...")
                time.sleep(30)
                continue
            resp.raise_for_status()
            results = resp.json().get("results", [])
        except Exception as e:
            print(f"    API error: {e}")
            break

        if not results:
            break

        for obs in results:
            if downloaded >= max_images:
                break
            photos = obs.get("photos", [])
            if not photos:
                continue

            url = photos[0].get("url","").replace("square","medium")
            if not url:
                continue

            obs_id   = obs.get("id", downloaded)
            out_path = dest / f"inat_{label}_{obs_id}.jpg"
            if out_path.exists():
                downloaded += 1
                continue

            try:
                r = requests.get(url, timeout=15, stream=True)
                r.raise_for_status()
                with open(out_path, "wb") as f:
                    for chunk in r.iter_content(8192):
                        f.write(chunk)
                Image.open(out_path).verify()
                downloaded += 1
            except Exception:
                if out_path.exists():
                    out_path.unlink()

        page += 1
        time.sleep(1.0)

    print(f"    Total: {downloaded} images")


def download_all_inaturalist():
    print("\n" + "="*60)
    print("STEP 2: Downloading iNaturalist field photos")
    print("="*60)

    for label, taxon_id in INAT_TAXON_IDS.items():
        if taxon_id is None:
            print(f"  Skipping {label} — no taxon ID available")
            continue
        download_inaturalist_images(label, taxon_id, max_images=200)


# ═══════════════════════════════════════════════════════════════
# STEP 3 — Merge all sources into data/all/<class>/
# ═══════════════════════════════════════════════════════════════

def merge_all_sources():
    print("\n" + "="*60)
    print("STEP 3: Merging all sources into unified classes")
    print("="*60)

    all_dir = OUTPUT_DIR / "all"
    all_dir.mkdir(parents=True, exist_ok=True)

    source_dirs = [
        Path("PlantVillage"),
        Path("MendeleyPlants"),
        Path("iNaturalist"),
    ]

    counts      = {}
    unmatched   = set()

    for source in source_dirs:
        if not source.exists():
            print(f"  ⚠️  {source}/ not found — skipping")
            continue

        print(f"\n  Scanning {source}/")

        for class_dir in sorted(source.rglob("*")):
            if not class_dir.is_dir():
                continue

            folder_name = class_dir.name

            # Look up exact match first
            label = CLASS_MAP.get(folder_name)

            # Try case-insensitive partial match if no exact match
            if label is None:
                folder_lower = folder_name.lower().replace(" ","_")
                for k, v in CLASS_MAP.items():
                    if k.lower().replace(" ","_") == folder_lower:
                        label = v
                        break

            if label is None:
                unmatched.add(folder_name)
                continue

            # Collect all images in this folder
            images = (
                list(class_dir.glob("*.jpg"))  +
                list(class_dir.glob("*.jpeg")) +
                list(class_dir.glob("*.JPG"))  +
                list(class_dir.glob("*.JPEG")) +
                list(class_dir.glob("*.png"))  +
                list(class_dir.glob("*.PNG"))
            )

            if not images:
                continue

            dest = all_dir / label
            dest.mkdir(exist_ok=True)

            copied = 0
            for img_path in images:
                # Prefix with source name to avoid filename collisions
                new_name  = f"{source.name}_{class_dir.parent.name}_{img_path.name}"
                dest_path = dest / new_name
                if not dest_path.exists():
                    shutil.copy2(img_path, dest_path)
                    copied += 1

            counts[label] = counts.get(label, 0) + len(images)
            print(f"    {source.name}/{folder_name} → {label}: +{len(images)}")

    if unmatched:
        print(f"\n  ⚠️  Unmatched folders (not in CLASS_MAP): {sorted(unmatched)}")
        print("  Add them to CLASS_MAP if you want to include them.")

    print("\n  Final class counts (all sources merged):")
    for label in sorted(counts):
        n      = counts[label]
        status = "✅" if n >= MIN_IMAGES else "⚠️ "
        bar    = "█" * min(n // 500, 30)
        print(f"    {status} {label:30s}: {n:6,}  {bar}")

    return counts


# ═══════════════════════════════════════════════════════════════
# STEP 4 — Train / Val split with class balancing
# ═══════════════════════════════════════════════════════════════

def split_train_val():
    print("\n" + "="*60)
    print("STEP 4: Splitting into train / val")
    print("="*60)

    all_dir = OUTPUT_DIR / "all"
    if not all_dir.exists():
        print("  ❌ data/all/ not found. Run merge first.")
        return

    # Collect all images per class
    class_images = {}
    for label_dir in sorted(all_dir.iterdir()):
        if not label_dir.is_dir():
            continue
        imgs = (
            list(label_dir.glob("*.jpg"))  +
            list(label_dir.glob("*.jpeg")) +
            list(label_dir.glob("*.JPG"))  +
            list(label_dir.glob("*.png"))  +
            list(label_dir.glob("*.PNG"))
        )
        if imgs:
            class_images[label_dir.name] = imgs

    # Class balancing: cap at 5× median to keep diversity
    # 5× (not 3×) so that healthy class keeps enough images
    counts = sorted(len(v) for v in class_images.values())
    median = counts[len(counts) // 2]
    cap    = int(median * 5)
    print(f"  Classes found: {len(class_images)}")
    print(f"  Median class size: {median:,}")
    print(f"  Cap (5× median):   {cap:,}")

    total_train = total_val = 0

    for label, images in sorted(class_images.items()):
        random.shuffle(images)

        if len(images) > cap:
            images = images[:cap]
            capped = True
        else:
            capped = False

        split      = int(len(images) * (1 - VAL_RATIO))
        train_imgs = images[:split]
        val_imgs   = images[split:]

        for split_name, split_imgs in [("train", train_imgs), ("val", val_imgs)]:
            dest = OUTPUT_DIR / split_name / label
            dest.mkdir(parents=True, exist_ok=True)
            for img_path in split_imgs:
                dest_path = dest / img_path.name
                if not dest_path.exists():
                    shutil.copy2(img_path, dest_path)

        cap_note = f"  (capped from {len(class_images[label]):,})" if capped else ""
        print(f"  {label:30s}: {len(train_imgs):5,} train + {len(val_imgs):4,} val{cap_note}")
        total_train += len(train_imgs)
        total_val   += len(val_imgs)

    print(f"\n  Total: {total_train:,} train + {total_val:,} val = {total_train+total_val:,}")


# ═══════════════════════════════════════════════════════════════
# STEP 5 — Validate and report
# ═══════════════════════════════════════════════════════════════

def validate_structure():
    print("\n" + "="*60)
    print("STEP 5: Validation report")
    print("="*60)

    for split in ("train", "val"):
        split_dir = OUTPUT_DIR / split
        if not split_dir.exists():
            print(f"  ❌ data/{split}/ missing")
            continue

        classes = sorted(d.name for d in split_dir.iterdir() if d.is_dir())
        print(f"\n  data/{split}/ — {len(classes)} classes:")

        for cls in classes:
            n      = len(list((split_dir / cls).glob("*.*")))
            status = "✅" if n >= 50 else "⚠️ "
            print(f"    {status} {cls:30s}: {n:,}")

    # Update constants.dart reminder
    classes = sorted(
        d.name for d in (OUTPUT_DIR / "train").iterdir()
        if d.is_dir() and len(list((OUTPUT_DIR / "train" / d.name).glob("*.*"))) > 0
    ) if (OUTPUT_DIR / "train").exists() else []

    print("\n  ── Update your Flutter app with these classes ──")
    print("  In plant_disease_app/lib/core/constants.dart:")
    print("  static const List<String> diseaseLabels = [")
    for cls in classes:
        print(f"    '{cls}',")
    print("  ];")

    print("\n✅ Data ready for training!")
    print("   Next: python train.py")


# ═══════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════

if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument("--skip-kaggle",       action="store_true",
                        help="Skip Kaggle downloads (already downloaded)")
    parser.add_argument("--skip-inaturalist",  action="store_true",
                        help="Skip iNaturalist API downloads")
    parser.add_argument("--skip-merge",        action="store_true",
                        help="Skip merge (go straight to split)")
    parser.add_argument("--remap-only",        action="store_true",
                        help="Only redo the split — dataset already merged")
    args = parser.parse_args()

    if args.remap_only:
        split_train_val()
        validate_structure()
    else:
        if not args.skip_kaggle:
            download_kaggle_datasets()
        if not args.skip_inaturalist:
            download_all_inaturalist()
        if not args.skip_merge:
            merge_all_sources()
        split_train_val()
        validate_structure()
  
    print("\n🎉 Done!") 