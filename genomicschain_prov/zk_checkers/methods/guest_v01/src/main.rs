use risc0_zkvm::guest::env;
use sha2::{Digest, Sha256};

fn main() {
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

    // Commit SHA-256 of full KMAT and the unchanged claim
    let digest: [u8; 32] = Sha256::digest(&input).into();
    env::commit(&(digest, claim));
}
