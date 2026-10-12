//! The verifier against the one real receipt in the prov fixtures: it must
//! pass as given, fail with one byte changed, fail under another image ID,
//! and report the journal digests the bundle will be compared with.
use std::io::Write;
use std::process::{Command, Stdio};

const FIXTURE: &str = concat!(env!("CARGO_MANIFEST_DIR"), "/../test/fixtures/zk_sizefactor_s1");

fn run(image_id: &str, bytes: &[u8]) -> serde_json::Value {
    let mut child = Command::new(env!("CARGO_BIN_EXE_gc_zk_verify"))
        .arg(image_id)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .spawn()
        .expect("spawn gc_zk_verify");
    child.stdin.take().unwrap().write_all(bytes).unwrap();
    let out = child.wait_with_output().unwrap();
    serde_json::from_slice(&out.stdout).expect("one JSON object")
}

fn fixture() -> (String, Vec<u8>) {
    let id = std::fs::read_to_string(format!("{FIXTURE}/image_id.txt")).unwrap();
    let bytes = std::fs::read(format!("{FIXTURE}/receipt.succinct.bin")).unwrap();
    (id.trim().to_string(), bytes)
}

#[test]
fn real_receipt_verifies_and_reads_the_journal() {
    let (id, bytes) = fixture();
    let o = run(&id, &bytes);
    assert_eq!(o["verified"], true);
    assert_eq!(o["journal_ok"], true);
    assert_eq!(o["receipt_bytes"], 223_746);
    assert_eq!(o["journal_input_sha256"], "5cb5cfc3a976faa8b8db6a8799ebc3372097833845e38d99e9247c14a86aede3");
    assert_eq!(o["journal_output_sha256"], "7d8c053239d53b373ae09674c2bd3f1456038c414e54534762ba7592ec9b4515");
    assert_eq!(o["risc0_zkvm"], "3.0.6");
}

#[test]
fn one_changed_byte_fails() {
    let (id, mut bytes) = fixture();
    bytes[5000] ^= 1;
    let o = run(&id, &bytes);
    assert_eq!(o["verified"], false);
    assert!(o["journal_input_sha256"].is_null());
}

#[test]
fn another_image_id_fails() {
    let (_, bytes) = fixture();
    let o = run(&"0".repeat(64), &bytes);
    assert_eq!(o["verified"], false);
    assert_eq!(o["error"], "verification_failed");
}

#[test]
fn garbage_is_not_decodable() {
    let (id, _) = fixture();
    let o = run(&id, b"not a receipt");
    assert_eq!(o["error"], "receipt_not_decodable");
}
