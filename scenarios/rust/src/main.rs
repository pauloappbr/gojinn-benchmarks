use std::io::{self, Read, Write};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

// --- Gojinn Contract Structures ---

#[derive(Deserialize)]
struct GojinnRequest {
    body: String,
}

#[derive(Serialize)]
struct GojinnResponse {
    status: u16,
    headers: HashMap<String, String>,
    body: String,
}

// --- Business Structures ---

#[derive(Deserialize)]
struct Order {
    id: String,
    value: f64,
}

#[derive(Serialize)]
struct Output {
    order_id: String,
    total_final: f64,
    engine: String,
}

fn main() {
    // 1. Read Stdin (Gojinn Envelope)
    let mut buffer = String::new();
    io::stdin().read_to_string(&mut buffer).unwrap();

    // 2. Parse Request
    // Unwrap is safe here because Gojinn guarantees valid JSON envelope
    let req: GojinnRequest = serde_json::from_str(&buffer).unwrap_or(GojinnRequest {
        body: "{}".to_string(),
    });

    // 3. Parse Body
    let order: Order = serde_json::from_str(&req.body).unwrap_or(Order {
        id: "error".to_string(),
        value: 0.0,
    });

    // 4. Business Logic (Tax Calc)
    let tax = order.value * 0.15;
    let total = order.value + tax;

    // 5. Prepare Response Body
    let out = Output {
        order_id: order.id,
        total_final: total,
        engine: "gojinn-rust".to_string(),
    };
    let body_str = serde_json::to_string(&out).unwrap();

    // 6. Construct Response Headers
    let mut headers = HashMap::new();
    headers.insert("Content-Type".to_string(), "application/json".to_string());

    let resp = GojinnResponse {
        status: 200,
        headers: headers,
        body: body_str,
    };

    // 7. Write Stdout (Gojinn Envelope)
    let resp_str = serde_json::to_string(&resp).unwrap();
    io::stdout().write_all(resp_str.as_bytes()).unwrap();
}