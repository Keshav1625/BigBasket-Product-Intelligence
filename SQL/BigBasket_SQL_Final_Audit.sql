-- BigBasket Product Intelligence: Final SQL Audit
-- READ-ONLY: SELECT statements only. No data is modified.
USE bigbasket_analytics;

-- 1. Row count and ID checks
SELECT COUNT(*) AS total_records,
       COUNT(DISTINCT `index`) AS unique_product_ids,
       SUM(`index` IS NULL) AS null_product_ids
FROM products;

-- 2. Duplicate IDs
SELECT `index`, COUNT(*) AS occurrences
FROM products
GROUP BY `index`
HAVING COUNT(*) > 1
ORDER BY occurrences DESC;

-- 3. Missing values
SELECT
 SUM(product IS NULL OR TRIM(product) = '') AS missing_product,
 SUM(category IS NULL OR TRIM(category) = '') AS missing_category,
 SUM(sub_category IS NULL OR TRIM(sub_category) = '') AS missing_subcategory,
 SUM(brand IS NULL OR TRIM(brand) = '') AS missing_brand,
 SUM(rating IS NULL) AS missing_rating,
 SUM(sale_price IS NULL) AS missing_sale_price,
 SUM(market_price IS NULL) AS missing_market_price
FROM products;

-- 4. Missing-rating flag check
SELECT LOWER(TRIM(missing_rating_flag)) AS missing_rating_flag,
       COUNT(*) AS product_count,
       SUM(rating IS NULL) AS null_rating_count,
       SUM(rating = 0) AS zero_rating_count
FROM products
GROUP BY LOWER(TRIM(missing_rating_flag));

-- 5. Invalid ratings
SELECT COUNT(*) AS invalid_rating_records
FROM products
WHERE rating IS NOT NULL AND (rating < 0 OR rating > 5);

-- 6. Price validation
SELECT SUM(sale_price < 0) AS negative_sale_prices,
       SUM(market_price < 0) AS negative_market_prices,
       SUM(sale_price IS NULL) AS null_sale_prices,
       SUM(market_price IS NULL) AS null_market_prices
FROM products;

-- 7. Discount amount mismatch
SELECT COUNT(*) AS discount_amount_mismatch_count
FROM products
WHERE discount_amount IS NULL
   OR ABS(discount_amount -
      CASE WHEN market_price > sale_price
           THEN ROUND(market_price - sale_price, 2) ELSE 0 END) > 0.02;

-- 8. Discount percentage mismatch
SELECT COUNT(*) AS discount_percentage_mismatch_count
FROM products
WHERE discount_percentage IS NULL
   OR ABS(discount_percentage -
      CASE WHEN market_price > 0 AND market_price > sale_price
           THEN ROUND(((market_price - sale_price) / market_price) * 100, 4)
           ELSE 0 END) > 0.02;

-- 9. Discount flag mismatch
SELECT COUNT(*) AS has_discount_mismatch_count
FROM products
WHERE LOWER(TRIM(has_discount)) <>
      CASE WHEN market_price > sale_price THEN 'true' ELSE 'false' END;

-- 10. Discount percentage summary
SELECT MIN(discount_percentage) AS minimum_discount_percentage,
       MAX(discount_percentage) AS maximum_discount_percentage,
       AVG(discount_percentage) AS average_discount_percentage,
       SUM(discount_percentage < 0) AS negative_discount_count,
       SUM(discount_percentage > 100) AS above_100_percent_count
FROM products;

-- 11. Sample discount calculation mismatches
SELECT `index`, product, sale_price, market_price, discount_amount,
       ROUND(CASE WHEN market_price > sale_price
                  THEN market_price - sale_price ELSE 0 END, 2)
           AS recalculated_discount_amount,
       discount_percentage,
       ROUND(CASE WHEN market_price > 0 AND market_price > sale_price
                  THEN ((market_price - sale_price) / market_price) * 100
                  ELSE 0 END, 4) AS recalculated_discount_percentage,
       has_discount
FROM products
WHERE ABS(COALESCE(discount_amount, 0) -
          CASE WHEN market_price > sale_price
               THEN ROUND(market_price - sale_price, 2) ELSE 0 END) > 0.02
   OR ABS(COALESCE(discount_percentage, 0) -
          CASE WHEN market_price > 0 AND market_price > sale_price
               THEN ROUND(((market_price - sale_price) / market_price) * 100, 4)
               ELSE 0 END) > 0.02
LIMIT 25;

-- 12. Overall catalogue summary
SELECT COUNT(*) AS total_products,
       COUNT(DISTINCT category) AS total_categories,
       COUNT(DISTINCT sub_category) AS total_subcategories,
       COUNT(DISTINCT brand) AS total_brands,
       COUNT(DISTINCT `type`) AS total_types,
       ROUND(AVG(rating), 2) AS average_rating,
       ROUND(AVG(sale_price), 2) AS average_sale_price,
       ROUND(AVG(market_price), 2) AS average_market_price
FROM products;

-- 13. Products by category
SELECT category, COUNT(*) AS total_products
FROM products
GROUP BY category
ORDER BY total_products DESC;

-- 14. Top 10 brands
SELECT brand, COUNT(*) AS total_products
FROM products
WHERE brand IS NOT NULL AND TRIM(brand) <> ''
GROUP BY brand
ORDER BY total_products DESC
LIMIT 10;

-- 15. Discount status split
SELECT has_discount, COUNT(*) AS total_products,
       ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM products), 2)
           AS percentage_of_catalogue
FROM products
GROUP BY has_discount
ORDER BY total_products DESC;

-- 16. Rating range distribution (rated products only)
SELECT
 CASE WHEN rating <= 3.0 THEN '0 - 3'
      WHEN rating <= 3.5 THEN '3.1 - 3.5'
      WHEN rating <= 4.0 THEN '3.6 - 4.0'
      WHEN rating <= 4.5 THEN '4.1 - 4.5'
      WHEN rating <= 5.0 THEN '4.6 - 5'
      ELSE 'Unrated' END AS rating_range,
 COUNT(*) AS total_products
FROM products
WHERE rating IS NOT NULL
GROUP BY rating_range
ORDER BY MIN(rating);

-- 17. Average discount by category
SELECT category, ROUND(AVG(discount_percentage), 2) AS average_discount_percentage
FROM products
GROUP BY category
ORDER BY average_discount_percentage DESC;

-- 18. Top 10 products by discount
SELECT product, brand, category, sale_price, market_price, discount_percentage
FROM products
ORDER BY discount_percentage DESC
LIMIT 10;
