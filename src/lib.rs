use std::{
    fs::{self, File},
    io::BufReader,
    path::PathBuf,
};

use axum::{
    Extension, debug_handler,
    extract::{Query, Request},
    response::IntoResponse,
    routing::{Router, get},
};
use data_encoding::HEXLOWER;
use image::{DynamicImage, Rgba, codecs::gif::Repeat};
use rusttype::{Font, Scale};
use serde::Deserialize;
use sha2::{Digest, Sha256};
use text_on_image::{FontBundle, TextJustify, VerticalAnchor, WrapBehavior};
use tower::ServiceExt;
use tower_http::{cors::CorsLayer, services::ServeFile};

#[derive(Clone, Debug)]
pub struct EnvVars {
    pub data_path: PathBuf,
    pub font_path: PathBuf,
}

pub async fn api_route(env_vars: EnvVars) -> anyhow::Result<Router> {
    Ok(Router::new()
        .route("/", get(get_image))
        .layer(Extension(env_vars))
        .layer(CorsLayer::permissive()))
}

#[derive(Deserialize)]
pub struct Form {
    text: Option<String>,
}

#[debug_handler]
async fn get_image(
    vars: Extension<EnvVars>,
    Query(query): Query<Form>,
    request: Request,
) -> Result<impl IntoResponse, String> {
    let text = query.text.unwrap_or_else(String::new);
    let sha256 = HEXLOWER.encode(&Sha256::digest(&text));

    let mut cached_path = vars.data_path.clone();
    cached_path.push("cache");
    cached_path.push(format!("{sha256}.gif"));

    if !fs::exists(&cached_path).map_err(|e| e.to_string())? {
        let mut original_path = vars.data_path.clone();
        original_path.push("original.gif");

        let file_in = BufReader::new(File::open(&original_path).map_err(|e| e.to_string())?);
        let decoder = image::codecs::gif::GifDecoder::new(file_in).unwrap();
        let frames = image::AnimationDecoder::into_frames(decoder);
        let mut frames = frames.collect_frames().expect("error decoding gif");

        if !text.is_empty() {
            let font = std::fs::read(&vars.font_path).unwrap();
            let font = Font::try_from_vec(font).unwrap();

            let scale = 40.0;

            for frame in &mut frames {
                let text_start_x = (frame.buffer().width() / 2) as i32;
                let text_start_y = 20;

                let mut dynamic = DynamicImage::ImageRgba8(frame.buffer().clone());
                text_on_image::text_on_image(
                    &mut dynamic,
                    &text,
                    &FontBundle::new(&font, Scale::uniform(scale), Rgba([255, 255, 255, 255])),
                    text_start_x,
                    text_start_y,
                    TextJustify::Center,
                    VerticalAnchor::Top,
                    WrapBehavior::Wrap(frame.buffer().width() - 20),
                );

                *frame.buffer_mut() = dynamic.into_rgba8();
            }
        }

        let file_out = File::create(&cached_path).map_err(|e| e.to_string())?;
        let mut encoder = image::codecs::gif::GifEncoder::new(file_out);
        encoder
            .set_repeat(Repeat::Infinite)
            .map_err(|e| e.to_string())?;
        encoder
            .encode_frames(frames.into_iter())
            .map_err(|e| e.to_string())?;
    }

    Ok(ServeFile::new(cached_path).oneshot(request).await)
}
