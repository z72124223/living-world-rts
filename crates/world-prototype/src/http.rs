//! Bounded, one-request-per-connection HTTP/1.1 adapter. No remote bind or CORS surface.
use std::{
    io::{Read, Write},
    net::TcpStream,
    time::{Duration, Instant},
};

pub const MAX_BODY: usize = 64 * 1024;
const MAX_HEADERS: usize = 8 * 1024;
pub struct Request {
    pub method: String,
    pub path: String,
    pub body: Vec<u8>,
}

pub fn read_request(stream: &mut TcpStream, port: u16) -> Result<Request, (u16, String)> {
    // Windows can inherit the listener's nonblocking mode. Only the accept loop
    // is nonblocking; these bounded worker reads must wait for the client bytes.
    stream
        .set_nonblocking(false)
        .map_err(|e| (400, e.to_string()))?;
    stream
        .set_read_timeout(Some(Duration::from_secs(2)))
        .map_err(|e| (400, e.to_string()))?;
    let deadline = Instant::now() + Duration::from_secs(3);
    let mut buffer = vec![];
    let header_end = loop {
        if let Some(index) = buffer.windows(4).position(|v| v == b"\r\n\r\n") {
            break index + 4;
        }
        if buffer.len() >= MAX_HEADERS {
            return Err((431, "headers too large".into()));
        }
        if Instant::now() > deadline {
            return Err((408, "request timed out".into()));
        }
        let mut chunk = [0u8; 1024];
        let count = stream
            .read(&mut chunk)
            .map_err(|_| (408, "request read timed out".into()))?;
        if count == 0 {
            return Err((400, "incomplete request".into()));
        }
        buffer.extend_from_slice(&chunk[..count]);
    };
    if header_end > MAX_HEADERS {
        return Err((431, "headers too large".into()));
    }
    let header =
        std::str::from_utf8(&buffer[..header_end]).map_err(|_| (400, "invalid headers".into()))?;
    let mut lines = header.split("\r\n");
    let first = lines
        .next()
        .unwrap_or_default()
        .split_whitespace()
        .collect::<Vec<_>>();
    if first.len() != 3 || first[2] != "HTTP/1.1" {
        return Err((400, "HTTP/1.1 required".into()));
    }
    let method = first[0].to_string();
    let path = first[1].to_string();
    let mut headers = std::collections::BTreeMap::new();
    for line in lines.filter(|v| !v.is_empty()) {
        let (name, value) = line.split_once(':').ok_or((400, "invalid header".into()))?;
        if name.is_empty() || !name.bytes().all(|b| b.is_ascii_alphanumeric() || b == b'-') {
            return Err((400, "invalid header name".into()));
        }
        if headers
            .insert(name.to_ascii_lowercase(), value.trim().to_string())
            .is_some()
        {
            return Err((400, "duplicate header".into()));
        }
    }
    if headers.get("host").map(String::as_str) != Some(format!("127.0.0.1:{port}").as_str()) {
        return Err((403, "loopback Host required".into()));
    }
    if let Some(origin) = headers.get("origin")
        && origin != &format!("http://127.0.0.1:{port}")
    {
        return Err((403, "cross-origin requests are not allowed".into()));
    }
    if let Some(site) = headers.get("sec-fetch-site")
        && !matches!(site.as_str(), "same-origin" | "none")
    {
        return Err((403, "cross-site requests are not allowed".into()));
    }
    if headers.contains_key("transfer-encoding") || headers.contains_key("expect") {
        return Err((400, "streamed or Expect requests are not supported".into()));
    }
    let length = match headers.get("content-length") {
        Some(value) => {
            if value.is_empty() || !value.bytes().all(|b| b.is_ascii_digit()) {
                return Err((400, "invalid content-length".into()));
            }
            value
                .parse::<usize>()
                .map_err(|_| (413, "body too large".into()))?
        }
        None if method == "POST" => return Err((411, "content-length required".into())),
        None => 0,
    };
    if length > MAX_BODY {
        return Err((413, "body too large".into()));
    }
    if method == "POST"
        && headers
            .get("content-type")
            .map(|v| v.split(';').next().unwrap_or("").trim())
            != Some("application/json")
    {
        return Err((415, "application/json required".into()));
    }
    while buffer.len() - header_end < length {
        if Instant::now() > deadline {
            return Err((408, "request timed out".into()));
        }
        let mut chunk = [0u8; 4096];
        let count = stream
            .read(&mut chunk)
            .map_err(|_| (408, "request body timed out".into()))?;
        if count == 0 {
            return Err((400, "incomplete request body".into()));
        }
        buffer.extend_from_slice(&chunk[..count]);
    }
    if buffer.len() - header_end != length {
        return Err((400, "unexpected bytes after body".into()));
    }
    if method == "GET" && length != 0 {
        return Err((400, "GET body is not supported".into()));
    }
    Ok(Request {
        method,
        path,
        body: buffer[header_end..].to_vec(),
    })
}

pub fn respond(stream: &mut TcpStream, status: u16, body: &serde_json::Value) {
    let body = serde_json::to_vec(body)
        .unwrap_or_else(|_| b"{\"ok\":false,\"error\":\"serialization failed\"}".to_vec());
    let reason = match status {
        200 => "OK",
        400 => "Bad Request",
        403 => "Forbidden",
        404 => "Not Found",
        405 => "Method Not Allowed",
        408 => "Request Timeout",
        409 => "Conflict",
        411 => "Length Required",
        413 => "Payload Too Large",
        415 => "Unsupported Media Type",
        422 => "Unprocessable Content",
        431 => "Request Header Fields Too Large",
        503 => "Service Unavailable",
        _ => "Internal Server Error",
    };
    let head = format!(
        "HTTP/1.1 {status} {reason}\r\nContent-Type: application/json; charset=utf-8\r\nContent-Length: {}\r\nConnection: close\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\n\r\n",
        body.len()
    );
    let _ = stream.set_write_timeout(Some(Duration::from_secs(2)));
    let _ = stream
        .write_all(head.as_bytes())
        .and_then(|_| stream.write_all(&body));
}
