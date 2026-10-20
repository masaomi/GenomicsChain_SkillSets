//! Design v0.1.16 §10 T2 — what the journal of a real receipt contains.
//!
//! The real 0.2 journal must be 388 bytes, start with the tag, and contain the
//! step output neither raw nor in risc0-serde form (one byte per u32 word,
//! little-endian). The unsalted SHA-256 of input and output is searched the
//! same two ways. Positive control: the same search finds the output (and the
//! input digest) in the real 0.1 journal. The test prints which form hit, so
//! the result can be recorded.
use risc0_zkvm::Receipt;

const V01: &str = concat!(env!("CARGO_MANIFEST_DIR"), "/../test/fixtures/zk_sizefactor_s1");
const V02: &str = concat!(env!("CARGO_MANIFEST_DIR"), "/../test/fixtures/zk_sizefactor_s1_v02");

fn journal(path: &str) -> Vec<u8> {
    let r: Receipt = bincode::deserialize(&std::fs::read(path).unwrap()).unwrap();
    r.journal.bytes
}

fn widened(b: &[u8]) -> Vec<u8> {
    b.iter().flat_map(|&x| (x as u32).to_le_bytes()).collect()
}

fn contains(hay: &[u8], needle: &[u8]) -> bool {
    !needle.is_empty() && hay.windows(needle.len()).any(|w| w == needle)
}

/// (raw hit, widened hit)
fn find(hay: &[u8], needle: &[u8]) -> (bool, bool) {
    (contains(hay, needle), contains(hay, &widened(needle)))
}

fn sha(b: &[u8]) -> Vec<u8> {
    use sha2::Digest;
    sha2::Sha256::digest(b).to_vec()
}

#[test]
fn t2_v02_journal_hides_output_and_unsalted_digests_while_v01_shows_them() {
    let output = std::fs::read(format!("{V01}/S1_odd__valid_exact.sfq3")).unwrap();
    let input = std::fs::read(format!("{V01}/S1_odd.kmat")).unwrap();
    let j2 = journal(&format!("{V02}/receipt_v02.bin"));
    let j1 = journal(&format!("{V01}/receipt.succinct.bin"));

    assert_eq!(j2.len(), 388);
    assert_eq!(&j2[..4], &0x475A_4B32u32.to_le_bytes());

    let probes = [("output bytes", output.clone()), ("sha256(output)", sha(&output)), ("sha256(input)", sha(&input)), ("input bytes", input.clone())];
    for (name, needle) in &probes {
        let (raw2, wide2) = find(&j2, needle);
        let (raw1, wide1) = find(&j1, needle);
        println!("T2 {name:15} 0.2 journal raw={raw2} widened={wide2} | 0.1 journal raw={raw1} widened={wide1}");
        assert!(!raw2 && !wide2, "0.2 journal contains {name}");
    }
    // Positive control: the same search finds the output and the input digest in 0.1.
    let (r, w) = find(&j1, &output);
    assert!(r || w, "control: output not found in the 0.1 journal");
    let (r, w) = find(&j1, &sha(&input));
    assert!(r || w, "control: input digest not found in the 0.1 journal");
}
