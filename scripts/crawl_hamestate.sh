#!/bin/bash
# Crawl HamEstate to understand available data sources for the scraper
# Outputs to scripts/hamestate_data/

set -euo pipefail
OUT="$(dirname "$0")/hamestate_data"
mkdir -p "$OUT"
UA="Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15"

echo "=== 1. RSS feed (product category) ==="
curl -sS -A "$UA" \
  "https://www.hamestate.com/product-category/ham_equipment/feed/" \
  -o "$OUT/category_feed.xml"
echo "Saved category_feed.xml ($(wc -c < "$OUT/category_feed.xml") bytes)"

echo ""
echo "=== 2. WP JSON API: product categories ==="
curl -sS -A "$UA" \
  "https://www.hamestate.com/wp-json/wp/v2/product_cat?per_page=100" \
  -o "$OUT/product_categories.json"
echo "Saved product_categories.json"

echo ""
echo "=== 3. WC Store API: products (page 1, public) ==="
curl -sS -A "$UA" \
  "https://www.hamestate.com/wp-json/wc/store/v1/products?per_page=25&category=19" \
  -o "$OUT/store_api_products_p1.json"
echo "Saved store_api_products_p1.json ($(wc -c < "$OUT/store_api_products_p1.json") bytes)"

echo ""
echo "=== 4. WC Store API: products (page 2) ==="
curl -sS -A "$UA" \
  "https://www.hamestate.com/wp-json/wc/store/v1/products?per_page=25&category=19&page=2" \
  -o "$OUT/store_api_products_p2.json"
echo "Saved store_api_products_p2.json ($(wc -c < "$OUT/store_api_products_p2.json") bytes)"

echo ""
echo "=== 5. WC Store API: all categories ==="
curl -sS -A "$UA" \
  "https://www.hamestate.com/wp-json/wc/store/v1/products/categories?per_page=100" \
  -o "$OUT/store_categories.json"
echo "Saved store_categories.json"

echo ""
echo "=== 6. WCPT AJAX endpoint (how the table plugin loads data) ==="
curl -sS -A "$UA" \
  -X POST \
  -d "action=wcpt_query&wcpt_id=0&wcpt_page=1&wcpt_category=ham_equipment&wcpt_per_page=25" \
  "https://www.hamestate.com/wp-admin/admin-ajax.php" \
  -o "$OUT/wcpt_ajax.json"
echo "Saved wcpt_ajax.json ($(wc -c < "$OUT/wcpt_ajax.json") bytes)"

echo ""
echo "=== 7. Sample product detail page ==="
# Extract first product URL from store API
FIRST_URL=$(python3 -c "
import json, sys
try:
    data = json.load(open('$OUT/store_api_products_p1.json'))
    if isinstance(data, list) and len(data) > 0:
        print(data[0].get('permalink', ''))
except: pass
" 2>/dev/null || true)

if [ -n "$FIRST_URL" ]; then
  echo "Fetching detail page: $FIRST_URL"
  curl -sS -A "$UA" "$FIRST_URL" -o "$OUT/sample_product_detail.html"
  echo "Saved sample_product_detail.html ($(wc -c < "$OUT/sample_product_detail.html") bytes)"
else
  echo "No product URL found from store API, trying RSS..."
  FIRST_URL=$(python3 -c "
import xml.etree.ElementTree as ET
tree = ET.parse('$OUT/category_feed.xml')
root = tree.getroot()
for item in root.iter('{http://purl.org/rss/1.0/}item'):
    link = item.find('{http://purl.org/rss/1.0/}link')
    if link is not None and link.text:
        print(link.text)
        break
for item in root.iter('item'):
    link = item.find('link')
    if link is not None and link.text:
        print(link.text)
        break
" 2>/dev/null || true)
  if [ -n "$FIRST_URL" ]; then
    echo "Fetching detail page from RSS: $FIRST_URL"
    curl -sS -A "$UA" "$FIRST_URL" -o "$OUT/sample_product_detail.html"
    echo "Saved sample_product_detail.html ($(wc -c < "$OUT/sample_product_detail.html") bytes)"
  fi
fi

echo ""
echo "=== Summary ==="
echo "Files in $OUT:"
ls -lh "$OUT/"

echo ""
echo "=== Quick peek at data ==="
echo ""
echo "--- RSS feed (first 3 items) ---"
python3 -c "
import xml.etree.ElementTree as ET
tree = ET.parse('$OUT/category_feed.xml')
root = tree.getroot()
ns = {'': 'http://purl.org/rss/1.0/', 'dc': 'http://purl.org/dc/elements/1.1/'}
count = 0
for item in root.iter('item'):
    if count >= 3: break
    title = item.find('title')
    link = item.find('link')
    desc = item.find('description')
    print(f'  Title: {title.text if title is not None else \"?\"}')
    print(f'  Link:  {link.text if link is not None else \"?\"}')
    print(f'  Desc:  {(desc.text or \"\")[:120] if desc is not None else \"?\"}')
    print()
    count += 1
if count == 0:
    print('  (no items found in RSS)')
" 2>/dev/null || echo "  (could not parse RSS)"

echo "--- Store API products (first 3) ---"
python3 -c "
import json
data = json.load(open('$OUT/store_api_products_p1.json'))
if isinstance(data, list):
    for p in data[:3]:
        print(f'  ID: {p.get(\"id\")}')
        print(f'  Name: {p.get(\"name\")}')
        print(f'  URL: {p.get(\"permalink\")}')
        print(f'  Price: {p.get(\"prices\",{}).get(\"price\")} {p.get(\"prices\",{}).get(\"currency_code\")}')
        print(f'  Images: {len(p.get(\"images\",[]))}')
        print(f'  Status: {p.get(\"is_in_stock\")}')
        cats = [c.get('name') for c in p.get('categories',[])]
        print(f'  Categories: {cats}')
        desc = p.get('short_description','')[:120]
        print(f'  Short desc: {desc}')
        print()
elif isinstance(data, dict):
    print(f'  Error response: {json.dumps(data, indent=2)[:300]}')
else:
    print('  Unexpected response type')
" 2>/dev/null || echo "  (could not parse store API)"

echo "--- Store categories ---"
python3 -c "
import json
data = json.load(open('$OUT/store_categories.json'))
if isinstance(data, list):
    for c in data:
        print(f'  ID: {c.get(\"id\")}  Name: {c.get(\"name\")}  Count: {c.get(\"count\")}  Slug: {c.get(\"slug\")}')
elif isinstance(data, dict):
    print(f'  Response: {json.dumps(data, indent=2)[:300]}')
" 2>/dev/null || echo "  (could not parse categories)"

echo ""
echo "--- WCPT AJAX response (first 200 chars) ---"
head -c 200 "$OUT/wcpt_ajax.json"
echo ""

echo ""
echo "--- Store API product keys (schema) ---"
python3 -c "
import json
data = json.load(open('$OUT/store_api_products_p1.json'))
if isinstance(data, list) and len(data) > 0:
    print('  Keys:', sorted(data[0].keys()))
    prices = data[0].get('prices', {})
    if prices:
        print('  Price keys:', sorted(prices.keys()))
    imgs = data[0].get('images', [])
    if imgs:
        print('  Image keys:', sorted(imgs[0].keys()))
" 2>/dev/null || echo "  (no data)"
