use regex::Regex;
use std::sync::LazyLock;

use crate::models::Price;

static PRICE_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"\$\s?([\d,]+(?:\.\d{2})?)").unwrap());

static OBO_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"(?i)\b(obo|or best offer|best offer)\b").unwrap());

static SHIPPED_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"(?i)\b(shipped|free shipping|includes shipping)\b").unwrap());

static PLUS_SHIPPING_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"(?i)\b(plus shipping|\+ shipping|buyer pays shipping)\b").unwrap());

pub fn extract_price(text: &str) -> Option<Price> {
    let price_match = PRICE_RE.find(text)?;
    let caps = PRICE_RE.captures(price_match.as_str())?;
    let amount_str = caps.get(1)?.as_str().replace(',', "");
    let amount: f64 = amount_str.parse().ok()?;

    // Skip unreasonably small or large values (likely not prices)
    if amount < 1.0 || amount > 500_000.0 {
        return None;
    }

    let obo = OBO_RE.is_match(text);
    let includes_shipping = SHIPPED_RE.is_match(text) && !PLUS_SHIPPING_RE.is_match(text);

    Some(Price {
        amount,
        currency: "USD".to_string(),
        includes_shipping,
        obo,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_basic_price() {
        let price = extract_price("Selling for $1650 shipped").unwrap();
        assert!((price.amount - 1650.0).abs() < f64::EPSILON);
        assert!(price.includes_shipping);
        assert!(!price.obo);
    }

    #[test]
    fn test_price_with_obo() {
        let price = extract_price("$500 OBO plus shipping").unwrap();
        assert!((price.amount - 500.0).abs() < f64::EPSILON);
        assert!(!price.includes_shipping);
        assert!(price.obo);
    }

    #[test]
    fn test_price_with_cents() {
        let price = extract_price("Price: $1,299.99 shipped").unwrap();
        assert!((price.amount - 1299.99).abs() < f64::EPSILON);
        assert!(price.includes_shipping);
    }

    #[test]
    fn test_no_price() {
        assert!(extract_price("Contact me for pricing").is_none());
    }
}
