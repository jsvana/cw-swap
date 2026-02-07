mod api;
mod db;
mod models;
mod scraper;

use anyhow::Result;
use tower_http::cors::CorsLayer;
use tracing_subscriber::EnvFilter;

#[tokio::main]
async fn main() -> Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(EnvFilter::try_from_default_env().unwrap_or_else(|_| {
            EnvFilter::new("cw_swap_backend=debug,tower_http=debug")
        }))
        .init();

    let database_url =
        std::env::var("DATABASE_URL").unwrap_or_else(|_| "postgres://localhost/cw_swap".to_string());

    let pool = db::connect(&database_url).await?;
    tracing::info!("connected to database");

    db::run_migrations(&pool).await?;
    tracing::info!("database migrations complete");

    // Single HTTP client shared between scraper and image proxy
    let http_client = reqwest::Client::builder()
        .user_agent("CWSwap/1.0 (ham radio classifieds aggregator)")
        .timeout(std::time::Duration::from_secs(30))
        .cookie_store(true)
        .build()
        .expect("failed to build HTTP client");

    // Log in to QRZ if credentials are provided
    let qrz_user = std::env::var("QRZ_USERNAME").ok();
    let qrz_pass = std::env::var("QRZ_PASSWORD").ok();
    let qrz = scraper::QrzScraper::new(http_client.clone());
    if let (Some(user), Some(pass)) = (&qrz_user, &qrz_pass) {
        match qrz.login(&user, &pass).await {
            Ok(()) => {}
            Err(e) => {
                tracing::error!(error = %e, "QRZ login failed");
            }
        }
    } else {
        tracing::warn!("QRZ_USERNAME / QRZ_PASSWORD not set");
    }

    // Optionally run a scrape on startup
    if std::env::var("SCRAPE_ON_START").is_ok() {
        let scraper_pool = pool.clone();
        tokio::spawn(async move {
            tracing::info!("starting initial scrape...");
            match qrz.scrape_full_page(1).await {
                Ok(listings) => {
                    tracing::info!(count = listings.len(), "scraped listings from page 1");
                    for listing in &listings {
                        if let Err(e) = db::upsert_listing(&scraper_pool, listing).await {
                            tracing::error!(error = %e, id = %listing.id, "failed to upsert listing");
                        }
                    }
                }
                Err(e) => tracing::error!(error = %e, "scrape failed"),
            }
        });
    }

    let state = api::AppState {
        pool,
        http_client,
    };

    let app = api::router(state).layer(CorsLayer::permissive());

    let bind_addr = std::env::var("BIND_ADDR").unwrap_or_else(|_| "0.0.0.0:8080".to_string());
    let listener = tokio::net::TcpListener::bind(&bind_addr).await?;
    tracing::info!("listening on {bind_addr}");

    axum::serve(listener, app).await?;

    Ok(())
}
