//! checker_v02 — the claude_01 size-factor check with the gc-zk-journal-0.2
//! journal (GenomicsChain design v0.1.16 §6.2). TEST-ONLY.
//!
//! Private inputs, in order (each written by the host as a Vec<u8>):
//!   key     exactly 32 bytes (gc-commitment-0.1 §5; refused otherwise, because
//!           HMAC zero-pads short keys and two lengths would act as one key)
//!   input   the KMAT count matrix (the step's input file)
//!   claim   the SFQ3 size-factor claim (the step's output file)
//!
//! The check between "Parse KMAT header" and the end of the per-sample loop is
//! copied verbatim from claude_01. Only the reads and the commit differ:
//! the journal is exactly (0x475A4B32u32, key_id, C(input), C(claim)) with
//!   key_id = SHA-256("gc-commitment-0.1/key-id" ‖ key)
//!   C(f)   = HMAC-SHA256(key, f)
//! so neither the claim nor an unsalted digest of any file leaves the guest.
use hmac::{Hmac, Mac};
use risc0_zkvm::guest::env;
use sha2::{Digest, Sha256};

const TAG: u32 = 0x475A_4B32; // "GZK2"
const KEY_ID_PREFIX: &[u8] = b"gc-commitment-0.1/key-id";

fn commitment(key: &[u8], data: &[u8]) -> [u8; 32] {
    let mut mac = Hmac::<Sha256>::new_from_slice(key).expect("HMAC takes any key length");
    mac.update(data);
    mac.finalize().into_bytes().into()
}

fn main() {
    let key: Vec<u8> = env::read();
    if key.len() != 32 {
        panic!("commitment key must be exactly 32 bytes");
    }
    let input: Vec<u8> = env::read();
    let claim: Vec<u8> = env::read();

    // Parse KMAT header
    if input.len() < 12 || &input[0..4] != b"KMAT" {
        panic!("malformed KMAT");
    }
    let g = u32::from_le_bytes(input[4..8].try_into().unwrap()) as usize;
    let n = u32::from_le_bytes(input[8..12].try_into().unwrap()) as usize;
    if g == 0 || n == 0 || input.len() != 12 + g * n * 8 {
        panic!("invalid KMAT");
    }

    // Parse SFQ3 header
    if claim.len() < 8 || &claim[0..4] != b"SFQ3" {
        panic!("malformed SFQ3");
    }
    let m = u32::from_le_bytes(claim[4..8].try_into().unwrap()) as usize;
    if m != n || claim.len() != 8 + n * 8 {
        panic!("invalid SFQ3");
    }

    // Read claimed size factors
    let mut s_claimed = Vec::with_capacity(n);
    for j in 0..n {
        let off = 8 + j * 8;
        let v = u64::from_le_bytes(claim[off..off + 8].try_into().unwrap());
        if v == 0 {
            panic!("zero size factor");
        }
        s_claimed.push(v);
    }

    // Identify usable genes and precompute their log-counts
    let mut usable_logs: Vec<Vec<f64>> = Vec::new();
    for i in 0..g {
        let base = 12 + i * n * 8;
        let row: Vec<u64> = (0..n)
            .map(|j| u64::from_le_bytes(input[base + j * 8..base + j * 8 + 8].try_into().unwrap()))
            .collect();
        if row.iter().all(|&v| v > 0) {
            usable_logs.push(row.iter().map(|&v| (v as f64).ln()).collect());
        }
    }
    if usable_logs.is_empty() {
        panic!("no usable genes");
    }

    // Log geometric mean per usable gene
    let n_f = n as f64;
    let geo_means: Vec<f64> = usable_logs
        .iter()
        .map(|row| row.iter().sum::<f64>() / n_f)
        .collect();

    // Check each sample's size factor
    let num_usable = usable_logs.len();
    let scale = (1u64 << 32) as f64;

    for j in 0..n {
        let mut ratios: Vec<f64> = (0..num_usable)
            .map(|idx| usable_logs[idx][j] - geo_means[idx])
            .collect();
        ratios.sort_unstable_by(|a, b| a.partial_cmp(b).unwrap());

        let median = if num_usable % 2 == 1 {
            ratios[num_usable / 2]
        } else {
            (ratios[num_usable / 2 - 1] + ratios[num_usable / 2]) * 0.5
        };

        let s_true = median.exp();
        let s_claim = s_claimed[j] as f64 / scale;
        let rel_err = (s_claim / s_true - 1.0).abs();
        if rel_err > 1e-6 {
            panic!("tolerance exceeded");
        }
    }

    // Commit the gc-zk-journal-0.2 tuple: tag, key name, salted fingerprints.
    let mut h = Sha256::new();
    h.update(KEY_ID_PREFIX);
    h.update(&key);
    let key_id: [u8; 32] = h.finalize().into();
    let c_in = commitment(&key, &input);
    let c_out = commitment(&key, &claim);
    env::commit(&(TAG, key_id, c_in, c_out));
}
