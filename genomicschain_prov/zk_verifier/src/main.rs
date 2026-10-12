//! gc_zk_verify — verify one RISC Zero receipt and read its journal under the
//! GenomicsChain convention (design v0.1.12 §6.1).
//!
//! Usage: gc_zk_verify <image_id_hex>   (receipt bytes on stdin)
//!
//! stdin   the receipt as `bincode::serialize(&Receipt)`, exactly the bytes
//!         whose SHA-256 the bundle declares
//! argv[1] the guest image ID, 64 hex: the 32 bytes of the image digest
//!         (eight u32 words, little-endian), as the RISC Zero host prints it
//! stdout  one JSON object, always, exit 0 — unless the arguments themselves
//!         are unusable (exit 2). A receipt that fails is an answer, not an
//!         error of this program.
//!
//! The output carries digests and codes only. Journal values never leave this
//! process: the anchor that calls it must not log or record them (§6), so the
//! program does not hand them over in the first place.
//!
//! Journal convention `gc-zk-journal-0.1`: the guest commits, through
//! risc0's serde, the pair `([u8; 32], Vec<u8>)` = (SHA-256 of the step's
//! input file, the step's output bytes). This is what the size-factor demo's
//! checker guests commit (KairosChain_2026 log/zk_demo_sizefactor_20260929).
//! The anchor compares the first with the bundle's recorded input digest and
//! the SHA-256 of the second with the recorded output digest; that link is
//! what turns "some computation was correct" into "this step of this bundle".

use risc0_zkvm::{sha::Digest, Receipt};
use serde::Serialize;
use sha2::{Digest as _, Sha256};
use std::io::Read;

const TOOL_VERSION: &str = env!("CARGO_PKG_VERSION");
const RISC0_ZKVM: &str = "3.0.6"; // pinned with `=` in Cargo.toml; kept in step by the crate test
const JOURNAL_CONVENTION: &str = "gc-zk-journal-0.1";
const MAX_RECEIPT_BYTES: usize = 512 * 1024; // design §6.1: a succinct receipt is ~224 KB

#[derive(Serialize)]
struct Outcome {
    tool: &'static str,
    version: &'static str,
    risc0_zkvm: &'static str,
    journal_convention: &'static str,
    receipt_sha256: Option<String>,
    receipt_bytes: usize,
    verified: bool,
    journal_ok: bool,
    journal_input_sha256: Option<String>,
    journal_output_sha256: Option<String>,
    error: Option<&'static str>,
}

fn outcome() -> Outcome {
    Outcome {
        tool: "gc_zk_verify",
        version: TOOL_VERSION,
        risc0_zkvm: RISC0_ZKVM,
        journal_convention: JOURNAL_CONVENTION,
        receipt_sha256: None,
        receipt_bytes: 0,
        verified: false,
        journal_ok: false,
        journal_input_sha256: None,
        journal_output_sha256: None,
        error: None,
    }
}

fn emit(o: &Outcome) {
    println!("{}", serde_json::to_string(o).expect("outcome serialises"));
}

fn parse_image_id(hex_id: &str) -> Option<Digest> {
    let bytes = hex::decode(hex_id).ok()?;
    let arr: [u8; 32] = bytes.try_into().ok()?;
    Some(Digest::from(arr))
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() != 2 || args[1] == "-h" || args[1] == "--help" {
        eprintln!("usage: gc_zk_verify <image_id_hex>  (receipt bytes on stdin)");
        std::process::exit(2);
    }
    let mut o = outcome();
    let Some(image_id) = parse_image_id(args[1].trim()) else {
        o.error = Some("image_id_invalid");
        emit(&o);
        std::process::exit(2);
    };

    let mut bytes = Vec::new();
    // Read one byte past the cap so an oversized receipt is refused rather
    // than truncated into something that might still decode.
    if std::io::stdin().take((MAX_RECEIPT_BYTES + 1) as u64).read_to_end(&mut bytes).is_err() {
        o.error = Some("stdin_unreadable");
        emit(&o);
        return;
    }
    o.receipt_bytes = bytes.len();
    if bytes.len() > MAX_RECEIPT_BYTES {
        o.error = Some("receipt_too_large");
        emit(&o);
        return;
    }
    o.receipt_sha256 = Some(hex::encode(Sha256::digest(&bytes)));

    let receipt: Receipt = match bincode::deserialize(&bytes) {
        Ok(r) => r,
        Err(_) => {
            o.error = Some("receipt_not_decodable");
            emit(&o);
            return;
        }
    };

    if receipt.verify(image_id).is_err() {
        o.error = Some("verification_failed");
        emit(&o);
        return;
    }
    o.verified = true;

    match receipt.journal.decode::<([u8; 32], Vec<u8>)>() {
        Ok((input_digest, output)) => {
            o.journal_ok = true;
            o.journal_input_sha256 = Some(hex::encode(input_digest));
            o.journal_output_sha256 = Some(hex::encode(Sha256::digest(&output)));
        }
        Err(_) => o.error = Some("journal_not_convention"),
    }
    emit(&o);
}
