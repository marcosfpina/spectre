use axum::{
    http::StatusCode,
    response::{IntoResponse, Response},
    Json,
};
use serde_json::json;
use spectre_core::SpectreError;

pub struct AppError(pub SpectreError);

/// Map SpectreError to Axum response
impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let status =
            StatusCode::from_u16(self.0.status_code()).unwrap_or(StatusCode::INTERNAL_SERVER_ERROR);

        let body = Json(json!({
            "error": {
                "code": status.as_u16(),
                "message": self.0.to_string(),
                // "details": ... could add details if structured
            }
        }));

        (status, body).into_response()
    }
}

// Allow `?` to work with AppError
impl<E> From<E> for AppError
where
    E: Into<SpectreError>,
{
    fn from(err: E) -> Self {
        Self(err.into())
    }
}
