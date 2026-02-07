use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Price {
    pub amount: f64,
    pub currency: String,
    pub includes_shipping: bool,
    pub obo: bool,
}
