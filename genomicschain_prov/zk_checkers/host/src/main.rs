//! gc_zk_test_prove — TEST-ONLY proving host for GenomicsChain Tier 2.5
//! v0.1.16 (design §11 step 10). It is not a customer tool and is not part of
//! what GenomicsChain ships (design §8, §13: the general proving tool for
//! customers is undecided). It exists to make the receipts that test
//! gc_zk_verify 0.2.0 and the option-2 anchor path (§10).
//!
//! Usage:
//!   gc_zk_test_prove --journal gc-zk-journal-0.1 --input <file> --output <file> --receipt <out>
//!   gc_zk_test_prove --journal gc-zk-journal-0.2 --key <file> --input <file> --output <file> --receipt <out>
//!   optional: --kind succinct (default) | composite   (composite only to test refusal)
//!
//! --key     exactly 32 raw bytes; any other length is refused here, before
//!           the guest runs (gc-commitment-0.1, design §5). Refused for 0.1,
//!           whose guest takes no key.
//! --input   the step's input file (KMAT); --output the step's output (SFQ3).
//! --receipt written as `bincode::serialize(&Receipt)`, the bytes gc_zk_verify
//!           reads on stdin.
//!
//! stdout: one JSON object — image_id (64 hex, the eight u32 words of the
//! image ID little-endian, the encoding gc_zk_verify takes), journal
//! convention, receipt kind, total/user cycles, segments, prove seconds and
//! receipt bytes. The receipt is verified against the image ID before it is
//! written. The journal is not printed.
use methods::{CHECKER_V01_ELF, CHECKER_V01_ID, CHECKER_V02_ELF, CHECKER_V02_ID};
use risc0_zkvm::{default_prover, ExecutorEnv, InnerReceipt, ProverOpts};
use std::time::Instant;

const USAGE: &str = "usage: gc_zk_test_prove --journal gc-zk-journal-0.1|gc-zk-journal-0.2 [--key <32-byte file>] --input <file> --output <file> --receipt <out> [--kind succinct|composite]";

fn die(msg: &str) -> ! {
    eprintln!("gc_zk_test_prove: {msg}\n{USAGE}");
    std::process::exit(2);
}

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    if args.len() % 2 != 0 {
        die("arguments come in --flag value pairs");
    }
    let (mut journal, mut key, mut input, mut output, mut receipt_path, mut kind) =
        (None, None, None, None, None, "succinct".to_string());
    for pair in args.chunks(2) {
        let v = pair[1].clone();
        match pair[0].as_str() {
            "--journal" => journal = Some(v),
            "--key" => key = Some(v),
            "--input" => input = Some(v),
            "--output" => output = Some(v),
            "--receipt" => receipt_path = Some(v),
            "--kind" => kind = v,
            other => die(&format!("unknown flag {other}")),
        }
    }
    let journal = journal.unwrap_or_else(|| die("--journal is required"));
    let input = std::fs::read(input.unwrap_or_else(|| die("--input is required"))).expect("read input");
    let output = std::fs::read(output.unwrap_or_else(|| die("--output is required"))).expect("read output");
    let receipt_path = receipt_path.unwrap_or_else(|| die("--receipt is required"));
    let opts = match kind.as_str() {
        "succinct" => ProverOpts::succinct(),
        "composite" => ProverOpts::composite(),
        _ => die("--kind must be succinct or composite"),
    };

    let mut b = ExecutorEnv::builder();
    let (elf, id) = match journal.as_str() {
        "gc-zk-journal-0.1" => {
            if key.is_some() {
                die("the 0.1 guest takes no key");
            }
            (CHECKER_V01_ELF, CHECKER_V01_ID)
        }
        "gc-zk-journal-0.2" => {
            let k = std::fs::read(key.unwrap_or_else(|| die("--key is required for 0.2"))).expect("read key");
            if k.len() != 32 {
                die(&format!("key must be exactly 32 bytes, got {}", k.len()));
            }
            b.write(&k).unwrap();
            (CHECKER_V02_ELF, CHECKER_V02_ID)
        }
        _ => die("--journal must be gc-zk-journal-0.1 or gc-zk-journal-0.2"),
    };
    let env = b.write(&input).unwrap().write(&output).unwrap().build().unwrap();

    let t = Instant::now();
    let info = default_prover().prove_with_opts(env, elf, &opts).unwrap_or_else(|e| {
        eprintln!("gc_zk_test_prove: proving failed: {e:#}");
        std::process::exit(1);
    });
    let prove_s = t.elapsed().as_secs_f64();
    let receipt = info.receipt;
    receipt.verify(id).expect("fresh receipt must verify");
    let receipt_kind = match &receipt.inner {
        InnerReceipt::Succinct(_) => "succinct",
        InnerReceipt::Composite(_) => "composite",
        _ => "other",
    };
    let bytes = bincode::serialize(&receipt).expect("receipt serialises");
    std::fs::write(&receipt_path, &bytes).expect("write receipt");
    let image_id: Vec<u8> = id.iter().flat_map(|w| w.to_le_bytes()).collect();
    println!(
        "{}",
        serde_json::json!({
            "tool": "gc_zk_test_prove",
            "image_id": hex::encode(image_id),
            "journal_convention": journal,
            "receipt_kind": receipt_kind,
            "total_cycles": info.stats.total_cycles,
            "user_cycles": info.stats.user_cycles,
            "segments": info.stats.segments,
            "prove_s": prove_s,
            "receipt_bytes": bytes.len(),
            "journal_bytes": receipt.journal.bytes.len(),
        })
    );
}
