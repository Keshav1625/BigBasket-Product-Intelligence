-- PROJECT 1: BIGBASKET PRODUCT INTELLIGENCE & ANALYTICS
-- FINAL SQL CORRECTION, VALIDATION & ANALYSIS
-- Database: bigbasket_analytics | Table: products

USE bigbasket_analytics;

-- 1. DATA CORRECTION
SET SQL_SAFE_UPDATES = 0;

UPDATE products
SET rating = NULL
WHERE LOWER(TRIM(missing_rating_flag)) = 'true'
  AND rating = 0;

UPDATE products
SET discount_amount = CASE
    WHEN market_price > sale_price THEN ROUND(market_price - sale_price, 2)
    ELSE 0
END
WHERE market_price IS NOT NULL AND sale_price IS NOT NULL;

UPDATE products
SET discount_percentage = CASE
    WHEN market_price > 0 AND market_price > sale_price
    THEN ROUND(((market_price - sale_price) / market_price) * 100, 4)
    ELSE 0
END
WHERE market_price IS NOT NULL AND sale_price IS NOT NULL;

UPDATE products
SET has_discount = CASE
    WHEN market_price > sale_price THEN 'True'
    ELSE 'False'
END;

SET SQL_SAFE_UPDATES = 1;

-- 2. DATABASE & TABLE VALIDATION
SELECT DATABASE() AS current_database;
SHOW TABLES;
DESCRIBE products;
SELECT COUNT(*) AS total_records FROM products;
SELECT COUNT(DISTINCT `index`) AS unique_product_ids FROM products;
SELECT * FROM products LIMIT 10;

-- 3. DATA QUALITY ANALYSIS
SELECT COUNT(*) AS missing_product_names
FROM products WHERE product IS NULL OR TRIM(product) = '';

SELECT COUNT(*) AS missing_brands
FROM products WHERE brand IS NULL OR TRIM(brand) = '';

SELECT COUNT(*) AS missing_categories
FROM products WHERE category IS NULL OR TRIM(category) = '';

SELECT COUNT(*) AS missing_ratings
FROM products WHERE rating IS NULL;

SELECT `index`, COUNT(*) AS duplicate_count
FROM products GROUP BY `index` HAVING COUNT(*) > 1;

SELECT * FROM products WHERE sale_price IS NULL OR sale_price <= 0;
SELECT * FROM products WHERE market_price IS NULL OR market_price <= 0;

SELECT * FROM products
WHERE rating IS NOT NULL AND (rating < 1 OR rating > 5);

SELECT
    COUNT(*) AS total_records,
    SUM(product IS NULL OR TRIM(product) = '') AS missing_products,
    SUM(brand IS NULL OR TRIM(brand) = '') AS missing_brands,
    SUM(category IS NULL OR TRIM(category) = '') AS missing_categories,
    SUM(rating IS NULL) AS missing_ratings,
    SUM(sale_price IS NULL OR sale_price <= 0) AS invalid_sale_prices,
    SUM(market_price IS NULL OR market_price <= 0) AS invalid_market_prices
FROM products;

-- 4. OVERALL PRODUCT ANALYSIS
SELECT
    COUNT(*) AS total_products,
    COUNT(DISTINCT product) AS unique_products,
    COUNT(DISTINCT category) AS total_categories,
    COUNT(DISTINCT sub_category) AS total_subcategories,
    COUNT(DISTINCT brand) AS total_brands,
    COUNT(DISTINCT `type`) AS total_product_types
FROM products;

SELECT
    ROUND(AVG(sale_price), 2) AS average_sale_price,
    MIN(sale_price) AS minimum_sale_price,
    MAX(sale_price) AS maximum_sale_price,
    ROUND(AVG(market_price), 2) AS average_market_price
FROM products;

-- 5. CATEGORY ANALYSIS
SELECT category, COUNT(*) AS total_products
FROM products GROUP BY category ORDER BY total_products DESC;

SELECT category, ROUND(AVG(sale_price), 2) AS avg_sale_price,
       ROUND(AVG(market_price), 2) AS avg_market_price
FROM products GROUP BY category ORDER BY avg_sale_price DESC;

SELECT category, ROUND(AVG(discount_percentage), 2) AS avg_discount_percentage
FROM products GROUP BY category ORDER BY avg_discount_percentage DESC;

SELECT category, ROUND(AVG(rating), 2) AS avg_rating, COUNT(rating) AS rated_products
FROM products GROUP BY category ORDER BY avg_rating DESC;

SELECT category, COUNT(*) AS total_products
FROM products GROUP BY category ORDER BY total_products DESC LIMIT 5;

-- 6. SUBCATEGORY ANALYSIS
SELECT sub_category, COUNT(*) AS total_products
FROM products GROUP BY sub_category ORDER BY total_products DESC LIMIT 10;

SELECT sub_category, ROUND(AVG(rating), 2) AS avg_rating, COUNT(rating) AS rated_products
FROM products GROUP BY sub_category
HAVING COUNT(rating) >= 10 ORDER BY avg_rating DESC;

SELECT sub_category, ROUND(AVG(sale_price), 2) AS avg_sale_price,
       ROUND(AVG(market_price), 2) AS avg_market_price
FROM products GROUP BY sub_category ORDER BY avg_sale_price DESC;

-- 7. BRAND ANALYSIS
SELECT brand, COUNT(*) AS total_products
FROM products WHERE brand IS NOT NULL AND TRIM(brand) <> ''
GROUP BY brand ORDER BY total_products DESC LIMIT 20;

SELECT brand, ROUND(AVG(rating), 2) AS avg_rating, COUNT(rating) AS rated_products
FROM products WHERE brand IS NOT NULL AND TRIM(brand) <> ''
GROUP BY brand HAVING COUNT(rating) >= 5
ORDER BY avg_rating DESC LIMIT 20;

SELECT brand, ROUND(AVG(discount_percentage), 2) AS avg_discount
FROM products WHERE brand IS NOT NULL AND TRIM(brand) <> ''
GROUP BY brand HAVING COUNT(*) >= 5
ORDER BY avg_discount DESC LIMIT 20;

-- 8. PRICING ANALYSIS
SELECT product, brand, category, sale_price, market_price
FROM products ORDER BY sale_price DESC LIMIT 20;

SELECT product, brand, category, sale_price, market_price
FROM products WHERE sale_price > 0 ORDER BY sale_price ASC LIMIT 20;

SELECT product, brand, sale_price, market_price
FROM products WHERE sale_price > market_price;

SELECT ROUND(AVG(market_price - sale_price), 2) AS avg_price_difference
FROM products;

SELECT
    CASE
        WHEN sale_price < market_price THEN 'Discounted'
        WHEN sale_price = market_price THEN 'No Price Difference'
        ELSE 'Sale Price Higher'
    END AS price_status,
    COUNT(*) AS total_products
FROM products GROUP BY price_status;

-- 9. DISCOUNT ANALYSIS
SELECT
    COUNT(*) AS total_products,
    SUM(has_discount = 'True') AS discounted_products,
    SUM(has_discount = 'False') AS non_discounted_products,
    ROUND(AVG(discount_amount), 2) AS avg_discount_amount,
    ROUND(AVG(discount_percentage), 2) AS avg_discount_percentage,
    MAX(discount_percentage) AS maximum_discount
FROM products;

SELECT
    CASE
        WHEN discount_percentage = 0 THEN 'No Discount'
        WHEN discount_percentage <= 10 THEN '0-10%'
        WHEN discount_percentage <= 20 THEN '10-20%'
        WHEN discount_percentage <= 30 THEN '20-30%'
        WHEN discount_percentage <= 50 THEN '30-50%'
        ELSE 'Above 50%'
    END AS discount_range,
    COUNT(*) AS total_products
FROM products GROUP BY discount_range
ORDER BY MIN(discount_percentage);

SELECT product, brand, category, sale_price, market_price,
       discount_amount, discount_percentage
FROM products ORDER BY discount_percentage DESC LIMIT 20;

SELECT category, COUNT(*) AS total_products,
       SUM(has_discount = 'True') AS discounted_products,
       ROUND(AVG(discount_percentage), 2) AS avg_discount
FROM products GROUP BY category ORDER BY avg_discount DESC;

-- 10. RATING ANALYSIS
SELECT ROUND(AVG(rating), 2) AS overall_average_rating FROM products;

SELECT
    CASE
        WHEN rating < 2 THEN 'Below 2'
        WHEN rating < 3 THEN '2 to 2.9'
        WHEN rating < 4 THEN '3 to 3.9'
        WHEN rating < 5 THEN '4 to 4.9'
        WHEN rating = 5 THEN '5 Stars'
    END AS rating_range,
    COUNT(*) AS total_products
FROM products WHERE rating IS NOT NULL
GROUP BY rating_range ORDER BY MIN(rating);

SELECT product, brand, category, rating
FROM products WHERE rating IS NOT NULL ORDER BY rating DESC LIMIT 20;

SELECT product, brand, category, rating
FROM products WHERE rating IS NOT NULL ORDER BY rating ASC LIMIT 20;

SELECT category, ROUND(AVG(rating), 2) AS avg_rating, COUNT(rating) AS rated_products
FROM products GROUP BY category ORDER BY avg_rating DESC;

-- 11. PRODUCT TYPE ANALYSIS
SELECT `type`, COUNT(*) AS total_products,
       ROUND(AVG(sale_price), 2) AS avg_sale_price,
       ROUND(AVG(rating), 2) AS avg_rating
FROM products WHERE `type` IS NOT NULL
GROUP BY `type` ORDER BY total_products DESC LIMIT 20;

SELECT `type`, ROUND(AVG(rating), 2) AS avg_rating, COUNT(rating) AS rated_products
FROM products WHERE `type` IS NOT NULL
GROUP BY `type` HAVING COUNT(rating) >= 5 ORDER BY avg_rating DESC;

-- 12. BUSINESS INSIGHTS
SELECT product, brand, category, sale_price, discount_percentage, rating
FROM products
WHERE discount_percentage >= 20 AND rating >= 4
ORDER BY rating DESC, discount_percentage DESC;

SELECT product, brand, category, market_price, rating
FROM products WHERE market_price >= 500 AND rating < 3
ORDER BY market_price DESC;

SELECT category, ROUND(AVG(market_price), 2) AS avg_market_price
FROM products GROUP BY category ORDER BY avg_market_price DESC LIMIT 5;

SELECT brand, ROUND(AVG(rating), 2) AS avg_rating, COUNT(rating) AS rated_products
FROM products WHERE brand IS NOT NULL AND TRIM(brand) <> ''
GROUP BY brand HAVING COUNT(rating) >= 5
ORDER BY avg_rating DESC LIMIT 20;

SELECT product, brand, sale_price, market_price
FROM products WHERE has_discount = 'False'
ORDER BY sale_price DESC LIMIT 20;

-- 13. FINAL VALIDATION & PROJECT SUMMARY
SELECT
    COUNT(*) AS total_records,
    COUNT(DISTINCT `index`) AS unique_product_ids,
    SUM(rating IS NULL) AS missing_ratings,
    SUM(rating = 0) AS zero_ratings,
    SUM(discount_percentage < 0) AS negative_discounts,
    SUM(discount_percentage > 100) AS above_100_discounts,
    SUM(sale_price IS NULL OR sale_price <= 0) AS invalid_sale_prices,
    SUM(market_price IS NULL OR market_price <= 0) AS invalid_market_prices
FROM products;

SELECT COUNT(*) AS discount_mismatches
FROM products
WHERE ABS(
    discount_percentage -
    CASE
        WHEN market_price > 0 AND market_price > sale_price
        THEN ((market_price - sale_price) / market_price) * 100
        ELSE 0
    END
) > 0.01;

SELECT
    COUNT(*) AS total_products,
    COUNT(DISTINCT category) AS total_categories,
    COUNT(DISTINCT sub_category) AS total_subcategories,
    COUNT(DISTINCT brand) AS total_brands,
    COUNT(rating) AS rated_products,
    SUM(rating IS NULL) AS unrated_products,
    ROUND(AVG(sale_price), 2) AS avg_sale_price,
    ROUND(AVG(market_price), 2) AS avg_market_price,
    ROUND(AVG(rating), 2) AS avg_rating,
    ROUND(AVG(discount_percentage), 2) AS avg_discount_percentage
FROM products;

-- END OF BIGBASKET SQL ANALYSIS
