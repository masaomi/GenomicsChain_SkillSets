//! gc_zk_verify — verify one RISC Zero receipt and read its journal under a
//! GenomicsChain journal convention (design v0.1.12 §6.1; v0.1.16 §6.2–§6.3).
//!
//! Usage: gc_zk_verify <image_id_hex> [--journal <convention>]
//!        (receipt bytes on stdin)
//!
//! stdin      the receipt as `bincode::serialize(&Receipt)`, exactly the bytes
//!            whose SHA-256 the bundle declares
//! argv[1]    the guest image ID, 64 hex: the 32 bytes of the image digest
//!            (eight u32 words, little-endian), as the RISC Zero host prints it
//! --journal  `gc-zk-journal-0.1` (the default when the flag is absent) or
//!            `gc-zk-journal-0.2`. Any other value: error
//!            `journal_convention_unknown`, exit 2, stdin not read.
//! stdout     one JSON object, always, exit 0 — unless the arguments themselves
//!            are unusable (exit 2). A receipt that fails is an answer, not an
//!            error of this program.
//!
//! Without `--journal` (or with `--journal gc-zk-journal-0.1`) the program
//! behaves as 0.1.0 did: the same output fields with the same values, except
//! `version`. `journal_convention` names the convention actually applied (in
//! 0.1.0 it was a constant); it is null only when the requested convention is
//! unknown.
//!
//! The output carries digests, commitments and codes only — never journal
//! payload bytes. The anchor that calls this must not log or record the
//! values (§6).
//!
//! ## `gc-zk-journal-0.1` (option 1; code path unchanged from 0.1.0)
//!
//! The guest commits, through risc0's serde, the pair `([u8; 32], Vec<u8>)` =
//! (SHA-256 of the step's input file, the step's output bytes). This is what
//! the size-factor demo's checker guests commit (KairosChain_2026
//! log/zk_demo_sizefactor_20260929). The program reports the first digest and
//! the SHA-256 of the second; the anchor compares them with the bundle's
//! recorded input and output digests. The journal therefore contains the
//! output itself: anyone holding the receipt can read it (design §2, L1).
//!
//! ## `gc-zk-journal-0.2` (option 2, design §6.2)
//!
//! The guest commits `(u32, [u8; 32], [u8; 32], [u8; 32])` = (tag
//! 0x475A4B32 "GZK2", key_id, C(step input), C(step output)) under the
//! `gc-commitment-0.1` rule (§5): key_id = SHA-256("gc-commitment-0.1/key-id"
//! ‖ key), C(f) = HMAC-SHA256(key, f). risc0 serde writes one u32 word per
//! byte and no length word for fixed arrays, so the journal is 97 words =
//! 388 bytes exactly. Checks, in this order:
//!
//! 1. `Receipt::verify(image_id)` (shared with 0.1). First, because nothing
//!    about a receipt that does not verify is worth reporting: its journal and
//!    its kind are whatever the submitter wrote.
//! 2. The inner receipt is `InnerReceipt::Succinct` (allow-list; Composite,
//!    Groth16 and Fake are refused with `receipt_not_succinct`). After
//!    verification, so that a forged receipt reports `verification_failed`
//!    whatever its kind, and `verified` stays as computed. A Fake receipt only
//!    reaches this step when RISC0_DEV_MODE is set in the caller's
//!    environment; this check is what refuses it then.
//! 3. The journal is exactly 388 bytes. Before decoding, because risc0's
//!    deserializer does not check that it consumed the whole journal: a
//!    longer journal whose prefix decodes would otherwise pass.
//! 4. Decode, and the first word equals the tag. The tag separates a 0.2
//!    journal from a 0.1 journal of the same length (a 0.1 journal with a
//!    64-byte output is also 388 bytes, but its first word is one byte, ≤ 255).
//!
//! Failures of 3 and 4 both report `journal_not_convention`. For 0.2 the
//! program never computes a SHA-256 of a journal value (design S1):
//! `journal_input_sha256` and `journal_output_sha256` are null, and four
//! fields are added — `receipt_kind` (`succinct`, `composite`, `groth16`,
//! `fake`; set once the receipt verified), `journal_key_id`,
//! `journal_input_commitment`, `journal_output_commitment` (64 lowercase hex
//! each, set only when `journal_ok`). For 0.2 the four are always present,
//! null until known.
//!
//! For 0.1 those four fields are **absent** (not null), so that the 0.1
//! output keeps exactly 0.1.0's field set.

use risc0_zkvm::{sha::Digest, InnerReceipt, Receipt};
use serde::Serialize;
use sha2::{Digest as _, Sha256};
use std::io::Read;

const TOOL_VERSION: &str = env!("CARGO_PKG_VERSION");
const RISC0_ZKVM: &str = "3.0.6"; // pinned with `=` in Cargo.toml; kept in step by the crate test
const JOURNAL_V01: &str = "gc-zk-journal-0.1";
const JOURNAL_V02: &str = "gc-zk-journal-0.2";
const V02_TAG: u32 = 0x475A_4B32; // ASCII "GZK2", design §6.2
const V02_JOURNAL_BYTES: usize = 388; // 97 risc0-serde words
const MAX_RECEIPT_BYTES: usize = 512 * 1024; // design §6.1: a succinct receipt is ~224 KB
const USAGE: &str = "usage: gc_zk_verify <image_id_hex> [--journal gc-zk-journal-0.1|gc-zk-journal-0.2]  (receipt bytes on stdin)";

#[derive(Clone, Copy, PartialEq)]
enum Convention {
    V01,
    V02,
}

#[derive(Serialize, Default)]
struct V02Fields {
    receipt_kind: Option<&'static str>,
    journal_key_id: Option<String>,
    journal_input_commitment: Option<String>,
    journal_output_commitment: Option<String>,
}

#[derive(Serialize)]
struct Outcome {
    tool: &'static str,
    version: &'static str,
    risc0_zkvm: &'static str,
    journal_convention: Option<&'static str>,
    receipt_sha256: Option<String>,
    receipt_bytes: usize,
    verified: bool,
    journal_ok: bool,
    journal_input_sha256: Option<String>,
    journal_output_sha256: Option<String>,
    error: Option<&'static str>,
    #[serde(flatten, skip_serializing_if = "Option::is_none")]
    v02: Option<V02Fields>,
}

fn outcome() -> Outcome {
    Outcome {
        tool: "gc_zk_verify",
        version: TOOL_VERSION,
        risc0_zkvm: RISC0_ZKVM,
        journal_convention: Some(JOURNAL_V01),
        receipt_sha256: None,
        receipt_bytes: 0,
        verified: false,
        journal_ok: false,
        journal_input_sha256: None,
        journal_output_sha256: None,
        error: None,
        v02: None,
    }
}

fn emit(o: &Outcome) {
    println!("{}", serde_json::to_string(o).expect("outcome serialises"));
}

fn usage_exit() -> ! {
    eprintln!("{USAGE}");
    std::process::exit(2);
}

fn parse_image_id(hex_id: &str) -> Option<Digest> {
    let bytes = hex::decode(hex_id).ok()?;
    let arr: [u8; 32] = bytes.try_into().ok()?;
    Some(Digest::from(arr))
}

fn kind(r: &Receipt) -> &'static str {
    #[allow(unreachable_patterns)]
    match &r.inner {
        InnerReceipt::Succinct(_) => "succinct",
        InnerReceipt::Composite(_) => "composite",
        InnerReceipt::Groth16(_) => "groth16",
        InnerReceipt::Fake(_) => "fake",
        _ => "other",
    }
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    // Accepted shapes: [id] and [id, --journal, convention].
    let requested: Option<&str> = match args.len() {
        2 => None,
        4 if args[2] == "--journal" => Some(args[3].as_str()),
        _ => usage_exit(),
    };
    if args[1] == "-h" || args[1] == "--help" || args[1].starts_with("--") {
        usage_exit();
    }
    let mut o = outcome();
    let Some(image_id) = parse_image_id(args[1].trim()) else {
        o.error = Some("image_id_invalid");
        emit(&o);
        std::process::exit(2);
    };
    let convention = match requested {
        None | Some(JOURNAL_V01) => Convention::V01,
        Some(JOURNAL_V02) => Convention::V02,
        Some(_) => {
            o.journal_convention = None;
            o.error = Some("journal_convention_unknown");
            emit(&o);
            std::process::exit(2);
        }
    };
    if convention == Convention::V02 {
        o.journal_convention = Some(JOURNAL_V02);
        o.v02 = Some(V02Fields::default());
    }

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

    match convention {
        Convention::V01 => read_v01(&receipt, &mut o),
        Convention::V02 => read_v02(&receipt, &mut o),
    }
    emit(&o);
}

/// gc-zk-journal-0.1: the 0.1.0 code, unchanged.
fn read_v01(receipt: &Receipt, o: &mut Outcome) {
    match receipt.journal.decode::<([u8; 32], Vec<u8>)>() {
        Ok((input_digest, output)) => {
            o.journal_ok = true;
            o.journal_input_sha256 = Some(hex::encode(input_digest));
            o.journal_output_sha256 = Some(hex::encode(Sha256::digest(&output)));
        }
        Err(_) => o.error = Some("journal_not_convention"),
    }
}

/// gc-zk-journal-0.2: succinct, then length, then decode and tag (module doc).
fn read_v02(receipt: &Receipt, o: &mut Outcome) {
    let k = kind(receipt);
    let f = o.v02.as_mut().expect("v02 fields set for 0.2");
    f.receipt_kind = Some(k);
    if k != "succinct" {
        o.error = Some("receipt_not_succinct");
        return;
    }
    match decode_v02(&receipt.journal.bytes) {
        Some((key_id, c_in, c_out)) => {
            o.journal_ok = true;
            f.journal_key_id = Some(hex::encode(key_id));
            f.journal_input_commitment = Some(hex::encode(c_in));
            f.journal_output_commitment = Some(hex::encode(c_out));
        }
        None => o.error = Some("journal_not_convention"),
    }
}

/// Length exactly 388, then decode, then the tag. None for anything else.
fn decode_v02(journal: &[u8]) -> Option<([u8; 32], [u8; 32], [u8; 32])> {
    if journal.len() != V02_JOURNAL_BYTES {
        return None;
    }
    let (tag, key_id, c_in, c_out): (u32, [u8; 32], [u8; 32], [u8; 32]) =
        risc0_zkvm::serde::from_slice(journal).ok()?;
    (tag == V02_TAG).then_some((key_id, c_in, c_out))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn journal(tag: u32, fill: u8) -> Vec<u8> {
        let words = risc0_zkvm::serde::to_vec(&(tag, [fill; 32], [fill; 32], [fill; 32])).unwrap();
        words.iter().flat_map(|w| w.to_le_bytes()).collect()
    }

    #[test]
    fn a_well_formed_journal_is_388_bytes_and_decodes() {
        let j = journal(V02_TAG, 7);
        assert_eq!(j.len(), 388);
        assert_eq!(&j[..4], &0x475A_4B32u32.to_le_bytes());
        assert_eq!(decode_v02(&j), Some(([7; 32], [7; 32], [7; 32])));
    }

    #[test]
    fn wrong_tag_is_refused() {
        assert_eq!(decode_v02(&journal(V02_TAG ^ 1, 7)), None);
        assert_eq!(decode_v02(&journal(0x2a, 7)), None); // a one-byte word, as a 0.1 journal starts
    }

    #[test]
    fn length_other_than_388_is_refused() {
        let j = journal(V02_TAG, 7);
        let mut longer = j.clone();
        longer.extend_from_slice(&[0, 0, 0, 0]); // prefix still decodes: only the length check refuses it
        assert_eq!(decode_v02(&longer), None);
        assert_eq!(decode_v02(&j[..384]), None);
        assert_eq!(decode_v02(&j[..387]), None);
        assert_eq!(decode_v02(&[]), None);
    }
}
