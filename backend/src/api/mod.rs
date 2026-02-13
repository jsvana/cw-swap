use axum::{
    extract::{Path, Query, State},
    http::StatusCode,
    response::IntoResponse,
    routing::get,
    Json, Router,
};
use serde::Deserialize;
use sqlx::PgPool;

use crate::db;

#[derive(Clone)]
pub struct AppState {
    pub pool: PgPool,
    pub http_client: reqwest::Client,
}

pub fn router(state: AppState) -> Router {
    Router::new()
        .route("/api/v1/listings", get(list_listings))
        .route("/api/v1/listings/{id}", get(get_listing))
        .route("/api/v1/categories", get(get_categories))
        .route("/api/v1/proxy/image", get(proxy_image))
        .route("/health", get(health))
        .with_state(state)
}

#[derive(Debug, Deserialize)]
struct ListingsParams {
    source: Option<String>,
    category: Option<String>,
    status: Option<String>,
    callsign: Option<String>,
    q: Option<String>,
    price_min: Option<f64>,
    price_max: Option<f64>,
    has_photo: Option<bool>,
    sort: Option<String>,
    page: Option<i32>,
    per_page: Option<i32>,
    #[serde(rename = "type")]
    listing_type: Option<String>,
}

async fn list_listings(
    State(state): State<AppState>,
    Query(params): Query<ListingsParams>,
) -> impl IntoResponse {
    let query = db::ListingQuery {
        source: params.source,
        category: params.category,
        status: params.status,
        callsign: params.callsign,
        q: params.q,
        price_min: params.price_min,
        price_max: params.price_max,
        has_photo: params.has_photo,
        sort: params.sort,
        page: params.page.unwrap_or(1).max(1),
        per_page: params.per_page.unwrap_or(20).clamp(1, 100),
        listing_type: params.listing_type,
    };

    match db::query_listings(&state.pool, &query).await {
        Ok(page) => Json(page).into_response(),
        Err(e) => {
            tracing::error!(error = %e, "failed to query listings");
            StatusCode::INTERNAL_SERVER_ERROR.into_response()
        }
    }
}

async fn get_listing(
    State(state): State<AppState>,
    Path(id): Path<String>,
) -> impl IntoResponse {
    match db::get_listing(&state.pool, &id).await {
        Ok(Some(listing)) => Json(listing).into_response(),
        Ok(None) => StatusCode::NOT_FOUND.into_response(),
        Err(e) => {
            tracing::error!(error = %e, "failed to get listing");
            StatusCode::INTERNAL_SERVER_ERROR.into_response()
        }
    }
}

async fn get_categories(State(state): State<AppState>) -> impl IntoResponse {
    match db::get_categories(&state.pool).await {
        Ok(categories) => Json(categories).into_response(),
        Err(e) => {
            tracing::error!(error = %e, "failed to get categories");
            StatusCode::INTERNAL_SERVER_ERROR.into_response()
        }
    }
}

#[derive(Debug, Deserialize)]
struct ProxyParams {
    url: String,
}

async fn proxy_image(
    State(state): State<AppState>,
    Query(params): Query<ProxyParams>,
) -> impl IntoResponse {
    // Only proxy URLs from known domains
    let allowed = params.url.contains("qrz.com")
        || params.url.contains("qth.com")
        || params.url.contains("hibid.com");
    if !allowed {
        return StatusCode::FORBIDDEN.into_response();
    }

    let resp = match state.http_client.get(&params.url).send().await {
        Ok(r) => r,
        Err(e) => {
            tracing::warn!(error = %e, url = %params.url, "image proxy fetch failed");
            return StatusCode::BAD_GATEWAY.into_response();
        }
    };

    if !resp.status().is_success() {
        return StatusCode::NOT_FOUND.into_response();
    }

    let content_type = resp
        .headers()
        .get(reqwest::header::CONTENT_TYPE)
        .and_then(|v| v.to_str().ok())
        .unwrap_or("image/jpeg")
        .to_string();

    let bytes = match resp.bytes().await {
        Ok(b) => b,
        Err(e) => {
            tracing::warn!(error = %e, "image proxy read failed");
            return StatusCode::BAD_GATEWAY.into_response();
        }
    };

    (
        [
            (axum::http::header::CONTENT_TYPE, content_type),
            (
                axum::http::header::CACHE_CONTROL,
                "public, max-age=86400".to_string(),
            ),
        ],
        bytes,
    )
        .into_response()
}

async fn health() -> &'static str {
    "ok"
}
