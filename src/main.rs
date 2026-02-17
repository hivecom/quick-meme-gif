use anyhow::Context;
use tracing::*;

use quick_meme_gif::{EnvVars, api_route};

use std::{net::SocketAddr, path::PathBuf};

#[tokio::main]
async fn main() {
    dotenv::dotenv().ok();

    let app_name = concat!(env!("CARGO_PKG_NAME"), "-", env!("CARGO_PKG_VERSION")).to_string();
    tracing_subscriber::fmt::init();

    info!("Running {}", app_name);

    if let Err(e) = run().await {
        let err = e
            .chain()
            .skip(1)
            .fold(e.to_string(), |acc, cause| format!("{}: {}\n", acc, cause));
        error!("{}", err);
        std::process::exit(1);
    }
}

async fn run() -> anyhow::Result<()> {
    let data_path = PathBuf::from(std::env::var("DATA_PATH").context("DATA_PATH not set")?);
    let font_path = PathBuf::from(std::env::var("FONT_PATH").context("FONT_PATH not set")?);
    let env_vars = EnvVars {
        data_path,
        font_path,
    };

    let bind_addr: SocketAddr = std::env::var("BIND_ADDRESS")
        .context("BIND_ADDRESS not set")?
        .parse()
        .context("BIND_ADDRESS could not be parsed")?;

    info!("Listening on {}", bind_addr);
    let listener = tokio::net::TcpListener::bind(&bind_addr).await.unwrap();
    axum::serve(listener, api_route(env_vars).await?)
        .await
        .unwrap();

    Ok(())
}
