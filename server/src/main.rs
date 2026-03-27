use warp::Filter;

/// @returns Server instance configured for static file serving
#[tokio::main]
async fn main() {
    let static_files = warp::fs::dir("../web");

    let cors = warp::cors()
        .allow_any_origin()
        .allow_headers(vec!["content-type"])
        .allow_methods(vec!["GET", "POST", "DELETE"]);

    let routes = static_files.with(cors);

    println!("Server starting on http://localhost:3030");
    warp::serve(routes)
        .run(([127, 0, 0, 1], 3030))
        .await;
}