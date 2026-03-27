use wasm_bindgen::prelude::*;

/// @param message The message to log to console
#[wasm_bindgen]
extern "C" {
    #[wasm_bindgen(js_namespace = console)]
    fn log(s: &str);
}

/// @param text Text to log
macro_rules! console_log {
    ($($t:tt)*) => (log(&format_args!($($t)*).to_string()))
}

/// Initialize the WebAssembly module
/// @returns Promise that resolves when initialization is complete
#[wasm_bindgen(start)]
pub fn main() {
    console_error_panic_hook::set_once();
    console_log!("Nuntius WebAssembly module initialized");
}

/// Basic P2P connection test
/// @returns Success message
#[wasm_bindgen]
pub fn init_p2p() -> String {
    console_log!("Initializing P2P connection with iroh");
    "P2P initialization started".to_string()
}