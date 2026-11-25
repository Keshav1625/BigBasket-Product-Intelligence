
# ============================================================
# PROJECT 1: BIGBASKET PRODUCT INTELLIGENCE & ANALYTICS
# Python | Pandas | NumPy | Matplotlib | Seaborn
# ============================================================

from pathlib import Path
import json
import warnings

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns

warnings.filterwarnings("ignore")

# ============================================================
# 1. PROJECT PATHS
# ============================================================

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data"

RAW_FILE = DATA / "Raw" / "BigBasket Products.csv"

# Also support alternate folder capitalization
if not RAW_FILE.exists():
    alternatives = [
        DATA / "RAW" / "BigBasket Products.csv",
        DATA / "raw" / "BigBasket Products.csv"
    ]
    RAW_FILE = next((p for p in alternatives if p.exists()), RAW_FILE)

CLEAN_DIR = DATA / "Cleaned"
OUT_DIR = DATA / "Processed"
IMAGE_DIR = ROOT / "Images"

for folder in [CLEAN_DIR, OUT_DIR, IMAGE_DIR]:
    folder.mkdir(parents=True, exist_ok=True)

if not RAW_FILE.exists():
    raise FileNotFoundError(
        f"Dataset not found: {RAW_FILE}\n"
        "Place BigBasket Products.csv inside data/Raw/"
    )

# ============================================================
# 2. LOAD DATASET
# ============================================================

print("\n" + "=" * 60)
print("BIGBASKET PRODUCT INTELLIGENCE & ANALYTICS")
print("=" * 60)

df = pd.read_csv(RAW_FILE)

print("\nDataset loaded successfully!")
print("Original Shape:", df.shape)

# Standardize column names
df.columns = (
    df.columns.astype(str)
    .str.strip()
    .str.lower()
    .str.replace(r"[^a-z0-9]+", "_", regex=True)
    .str.strip("_")
)

required_columns = [
    "index", "product", "category", "sub_category",
    "brand", "sale_price", "market_price",
    "type", "rating", "description"
]

missing_columns = [
    col for col in required_columns
    if col not in df.columns
]

if missing_columns:
    raise ValueError(
        f"Missing columns: {missing_columns}\n"
        f"Available columns: {df.columns.tolist()}"
    )

df = df[required_columns].copy()

# ============================================================
# 3. INITIAL DATA INSPECTION
# ============================================================

print("\n========== DATA INSPECTION ==========")

print("\nFirst 5 Records:")
print(df.head())

print("\nDataset Information:")
df.info()

print("\nStatistical Summary:")
print(df.describe(include="all"))

initial_missing = df.isnull().sum()
duplicate_rows = df.duplicated().sum()
duplicate_ids = df["index"].duplicated().sum()

print("\nMissing Values:")
print(initial_missing)

print("\nDuplicate Rows:", duplicate_rows)
print("Duplicate Index IDs:", duplicate_ids)

# Save initial quality checks
initial_report = pd.DataFrame({
    "Column": df.columns,
    "Missing_Values": df.isnull().sum().values,
    "Unique_Values": df.nunique().values
})

initial_report.to_csv(
    OUT_DIR / "initial_data_inspection.csv",
    index=False
)

# ============================================================
# 4. DATA CLEANING
# ============================================================

print("\n========== DATA CLEANING ==========")

# Clean text columns
text_columns = [
    "product", "category", "sub_category",
    "brand", "type", "description"
]

for col in text_columns:
    df[col] = df[col].astype("string").str.strip()
    df[col] = df[col].replace("", pd.NA)

# Convert numeric columns
numeric_columns = [
    "index", "sale_price", "market_price", "rating"
]

for col in numeric_columns:
    df[col] = pd.to_numeric(df[col], errors="coerce")

# Create missing-value flags
df["missing_product_flag"] = df["product"].isna()
df["missing_brand_flag"] = df["brand"].isna()
df["missing_rating_flag"] = df["rating"].isna()

# Identify invalid values
df["invalid_sale_price_flag"] = (
    df["sale_price"].isna() | (df["sale_price"] <= 0)
)

df["invalid_market_price_flag"] = (
    df["market_price"].isna() | (df["market_price"] <= 0)
)

df["invalid_rating_flag"] = (
    df["rating"].notna()
    & ~df["rating"].between(1, 5)
)

# Invalid ratings should not affect rating analysis
df.loc[df["invalid_rating_flag"], "rating"] = np.nan

# Identify exact duplicate rows without deleting them
df["exact_duplicate_flag"] = df.duplicated(keep="first")

# ============================================================
# 5. FEATURE ENGINEERING
# ============================================================

print("\n========== FEATURE ENGINEERING ==========")

# Price difference
df["discount_amount"] = (
    df["market_price"] - df["sale_price"]
)

# Discount percentage
df["discount_percentage"] = np.where(
    df["market_price"] > 0,
    (
        df["discount_amount"] /
        df["market_price"]
    ) * 100,
    np.nan
)

# Discount availability
df["has_discount"] = (
    df["market_price"].notna()
    & df["sale_price"].notna()
    & (df["market_price"] > df["sale_price"])
)

# Price comparison category
df["price_comparison_status"] = np.select(
    [
        df["sale_price"].isna() | df["market_price"].isna(),
        df["sale_price"] > df["market_price"],
        df["sale_price"] == df["market_price"],
        df["sale_price"] < df["market_price"]
    ],
    [
        "Missing Price",
        "Sale Price Above Market Price",
        "No Discount",
        "Discount Available"
    ],
    default="Needs Review"
)

# ============================================================
# 6. SAVE CLEANED DATA
# ============================================================

cleaned_file = CLEAN_DIR / "bigbasket_products_cleaned.csv"

df.to_csv(
    cleaned_file,
    index=False,
    encoding="utf-8-sig"
)

print("\nCleaned dataset saved:", cleaned_file)

# ============================================================
# 7. PREPARE ANALYTICAL DATA
# ============================================================

valid_products = df[
    df["product"].notna()
    & df["category"].notna()
    & df["sale_price"].gt(0)
    & df["market_price"].gt(0)
].copy()

rated_products = valid_products[
    valid_products["rating"].between(1, 5)
].copy()

print("\nValid Product Records:", len(valid_products))
print("Rated Product Records:", len(rated_products))

# ============================================================
# 8. CATEGORY ANALYSIS
# ============================================================

category_summary = (
    valid_products.groupby("category", dropna=False)
    .agg(
        product_records=("product", "size"),
        unique_products=("product", "nunique"),
        unique_brands=("brand", "nunique"),
        average_sale_price=("sale_price", "mean"),
        median_sale_price=("sale_price", "median"),
        average_market_price=("market_price", "mean"),
        average_discount=("discount_percentage", "mean"),
        discounted_products=("has_discount", "sum"),
        average_rating=("rating", "mean"),
        rated_records=("rating", "count")
    )
    .reset_index()
    .sort_values("product_records", ascending=False)
)

category_summary.to_csv(
    OUT_DIR / "category_summary.csv", index=False
)

# ============================================================
# 9. SUBCATEGORY ANALYSIS
# ============================================================

subcategory_summary = (
    valid_products.groupby(
        ["category", "sub_category"], dropna=False
    )
    .agg(
        product_records=("product", "size"),
        unique_products=("product", "nunique"),
        unique_brands=("brand", "nunique"),
        average_sale_price=("sale_price", "mean"),
        average_discount=("discount_percentage", "mean"),
        average_rating=("rating", "mean"),
        rated_records=("rating", "count")
    )
    .reset_index()
    .sort_values("product_records", ascending=False)
)

subcategory_summary.to_csv(
    OUT_DIR / "subcategory_summary.csv", index=False
)

# ============================================================
# 10. BRAND ANALYSIS
# ============================================================

brand_summary = (
    valid_products.groupby("brand", dropna=False)
    .agg(
        product_records=("product", "size"),
        unique_products=("product", "nunique"),
        category_count=("category", "nunique"),
        average_sale_price=("sale_price", "mean"),
        average_discount=("discount_percentage", "mean"),
        average_rating=("rating", "mean"),
        rated_records=("rating", "count")
    )
    .reset_index()
    .sort_values("product_records", ascending=False)
)

brand_summary.to_csv(
    OUT_DIR / "brand_summary.csv", index=False
)

# ============================================================
# 11. PRODUCT TYPE ANALYSIS
# ============================================================

type_summary = (
    valid_products.groupby("type", dropna=False)
    .agg(
        product_records=("product", "size"),
        unique_products=("product", "nunique"),
        average_sale_price=("sale_price", "mean"),
        average_discount=("discount_percentage", "mean"),
        average_rating=("rating", "mean"),
        rated_records=("rating", "count")
    )
    .reset_index()
    .sort_values("product_records", ascending=False)
)

type_summary.to_csv(
    OUT_DIR / "type_summary.csv", index=False
)

# ============================================================
# 12. PRODUCT LEVEL ANALYSIS
# ============================================================

product_summary = (
    valid_products.groupby(
        ["product", "category", "sub_category", "brand"],
        dropna=False
    )
    .agg(
        catalogue_records=("product", "size"),
        average_sale_price=("sale_price", "mean"),
        minimum_sale_price=("sale_price", "min"),
        maximum_sale_price=("sale_price", "max"),
        average_market_price=("market_price", "mean"),
        average_discount=("discount_percentage", "mean"),
        average_rating=("rating", "mean"),
        rated_records=("rating", "count")
    )
    .reset_index()
    .sort_values("average_sale_price", ascending=False)
)

product_summary.to_csv(
    OUT_DIR / "product_summary.csv", index=False
)

# ============================================================
# 13. DISCOUNT ANALYSIS
# ============================================================

discount_summary = (
    valid_products.groupby("price_comparison_status", dropna=False)
    .agg(
        product_records=("product", "size"),
        average_sale_price=("sale_price", "mean"),
        average_market_price=("market_price", "mean"),
        average_discount=("discount_percentage", "mean")
    )
    .reset_index()
)

discount_summary.to_csv(
    OUT_DIR / "discount_summary.csv", index=False
)

# Top 100 discounted catalogue records
top_discounted = valid_products.sort_values(
    "discount_percentage", ascending=False
).head(100)

top_discounted.to_csv(
    OUT_DIR / "top_100_discounted_products.csv", index=False
)

# ============================================================
# 14. RATING ANALYSIS
# ============================================================

rating_summary = (
    rated_products.groupby("rating")
    .agg(
        product_records=("product", "size")
    )
    .reset_index()
    .sort_values("rating")
)

rating_summary.to_csv(
    OUT_DIR / "rating_summary.csv", index=False
)

top_rated = rated_products.sort_values(
    ["rating", "product"],
    ascending=[False, True]
).head(100)

top_rated.to_csv(
    OUT_DIR / "top_100_rated_products.csv", index=False
)

# ============================================================
# 15. DATA QUALITY REPORT
# ============================================================

report = {
    "project": "BigBasket Product Intelligence & Analytics",
    "data_type": "Product Catalogue",
    "source_file": RAW_FILE.name,
    "total_rows": int(len(df)),
    "total_columns_original": int(len(required_columns)),
    "missing_product": int(df["missing_product_flag"].sum()),
    "missing_brand": int(df["missing_brand_flag"].sum()),
    "missing_rating": int(df["missing_rating_flag"].sum()),
    "invalid_sale_price": int(df["invalid_sale_price_flag"].sum()),
    "invalid_market_price": int(df["invalid_market_price_flag"].sum()),
    "invalid_rating": int(df["invalid_rating_flag"].sum()),
    "duplicate_rows": int(duplicate_rows),
    "duplicate_index_ids": int(duplicate_ids),
    "unique_products": int(df["product"].nunique()),
    "unique_categories": int(df["category"].nunique()),
    "unique_subcategories": int(df["sub_category"].nunique()),
    "unique_brands": int(df["brand"].nunique()),
    "unique_types": int(df["type"].nunique()),
    "valid_product_records": int(len(valid_products)),
    "rated_product_records": int(len(rated_products)),
    "average_sale_price": float(valid_products["sale_price"].mean()),
    "average_market_price": float(valid_products["market_price"].mean()),
    "average_discount_percentage": float(
        valid_products["discount_percentage"].mean()
    ),
    "discounted_product_records": int(
        valid_products["has_discount"].sum()
    )
}

with open(
    OUT_DIR / "data_quality_report.json",
    "w",
    encoding="utf-8"
) as file:
    json.dump(report, file, indent=4)

# ============================================================
# 16. EXPORT EXCEL SUMMARY WORKBOOK
# ============================================================

excel_file = OUT_DIR / "BigBasket_Analysis_Summaries.xlsx"

with pd.ExcelWriter(excel_file, engine="openpyxl") as writer:

    pd.DataFrame({
        "Metric": list(report.keys()),
        "Value": list(report.values())
    }).to_excel(
        writer, sheet_name="Data_Quality", index=False
    )

    category_summary.to_excel(
        writer, sheet_name="Category_Summary", index=False
    )

    subcategory_summary.to_excel(
        writer, sheet_name="Subcategory_Summary", index=False
    )

    brand_summary.to_excel(
        writer, sheet_name="Brand_Summary", index=False
    )

    type_summary.to_excel(
        writer, sheet_name="Type_Summary", index=False
    )

    product_summary.to_excel(
        writer, sheet_name="Product_Summary", index=False
    )

    discount_summary.to_excel(
        writer, sheet_name="Discount_Summary", index=False
    )

    rating_summary.to_excel(
        writer, sheet_name="Rating_Summary", index=False
    )

    top_discounted.to_excel(
        writer, sheet_name="Top_Discounts", index=False
    )

    top_rated.to_excel(
        writer, sheet_name="Top_Rated", index=False
    )

# ============================================================
# 17. DATA VISUALIZATION
# ============================================================

sns.set_theme(style="whitegrid")

# Chart 1: Top Categories
if not category_summary.empty:

    chart_data = category_summary.head(10).sort_values(
        "product_records"
    )

    plt.figure(figsize=(12, 7))

    sns.barplot(
        data=chart_data,
        x="product_records",
        y="category"
    )

    plt.title("Top Categories by Product Records")
    plt.xlabel("Number of Product Records")
    plt.ylabel("Category")
    plt.tight_layout()

    plt.savefig(
        IMAGE_DIR / "bigbasket_top_categories.png",
        dpi=160
    )

    plt.close()

# Chart 2: Top Brands
if not brand_summary.empty:

    chart_data = (
        brand_summary.dropna(subset=["brand"])
        .head(10)
        .sort_values("product_records")
    )

    if not chart_data.empty:

        plt.figure(figsize=(12, 7))

        sns.barplot(
            data=chart_data,
            x="product_records",
            y="brand"
        )

        plt.title("Top Brands by Product Records")
        plt.xlabel("Number of Product Records")
        plt.ylabel("Brand")
        plt.tight_layout()

        plt.savefig(
            IMAGE_DIR / "bigbasket_top_brands.png",
            dpi=160
        )

        plt.close()

# Chart 3: Sale Price Distribution
if not valid_products.empty:

    plt.figure(figsize=(10, 6))

    sns.histplot(
        data=valid_products,
        x="sale_price",
        bins=40,
        kde=True
    )

    plt.title("Sale Price Distribution")
    plt.xlabel("Sale Price (INR)")
    plt.ylabel("Product Records")
    plt.tight_layout()

    plt.savefig(
        IMAGE_DIR / "bigbasket_sale_price_distribution.png",
        dpi=160
    )

    plt.close()

# Chart 4: Rating Distribution
if not rated_products.empty:

    plt.figure(figsize=(9, 5))

    sns.countplot(
        data=rated_products,
        x="rating"
    )

    plt.title("Product Rating Distribution")
    plt.xlabel("Rating")
    plt.ylabel("Product Records")
    plt.tight_layout()

    plt.savefig(
        IMAGE_DIR / "bigbasket_rating_distribution.png",
        dpi=160
    )

    plt.close()

# Chart 5: Sale Price vs Market Price
if not valid_products.empty:

    plt.figure(figsize=(10, 6))

    sns.scatterplot(
        data=valid_products,
        x="market_price",
        y="sale_price",
        alpha=0.45
    )

    plt.title("Sale Price vs Market Price")
    plt.xlabel("Market Price (INR)")
    plt.ylabel("Sale Price (INR)")
    plt.tight_layout()

    plt.savefig(
        IMAGE_DIR / "bigbasket_sale_vs_market_price.png",
        dpi=160
    )

    plt.close()

# ============================================================
# 18. FINAL OUTPUT
# ============================================================

print("\n" + "=" * 60)
print("BIGBASKET ANALYSIS COMPLETED SUCCESSFULLY!")
print("=" * 60)

print("\nTOTAL RECORDS:", len(df))
print("UNIQUE PRODUCTS:", df["product"].nunique())
print("UNIQUE CATEGORIES:", df["category"].nunique())
print("UNIQUE SUBCATEGORIES:", df["sub_category"].nunique())
print("UNIQUE BRANDS:", df["brand"].nunique())
print("UNIQUE TYPES:", df["type"].nunique())

print("\nVALID PRODUCT RECORDS:", len(valid_products))
print("RATED PRODUCT RECORDS:", len(rated_products))

print("\nOUTPUT LOCATIONS:")
print("Cleaned Data:", CLEAN_DIR)
print("Processed Data:", OUT_DIR)
print("Excel Workbook:", excel_file)
print("Charts:", IMAGE_DIR)

print("\nIMPORTANT:")
print("This dataset contains product catalogue information.")
print("Catalogue prices are NOT actual sales or revenue.")

print("\nALL TASKS COMPLETED!")
