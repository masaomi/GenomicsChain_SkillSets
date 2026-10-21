//! gc_zk_verify 0.2.0: the `--journal` argument, the gc-zk-journal-0.2 path
//! against real receipts (test/fixtures/zk_sizefactor_s1_v02, made by the
//! test-only host in zk_checkers), and the two conventions refusing each
//! other's receipts (design v0.1.16 §6.2, §10 T4; review r2 N5).
use risc0_zkvm::{FakeReceipt, InnerReceipt, Receipt};
use std::io::Write;
use std::process::{Command, Stdio};

const V01: &str = concat!(env!("CARGO_MANIFEST_DIR"), "/../test/fixtures/zk_sizefactor_s1");
const V02: &str = concat!(env!("CARGO_MANIFEST_DIR"), "/../test/fixtures/zk_sizefactor_s1_v02");

struct Run {
    code: i32,
    json: serde_json::Value,
}

fn run_env(args: &[&str], bytes: &[u8], dev_mode: bool) -> Run {
    let mut cmd = Command::new(env!("CARGO_BIN_EXE_gc_zk_verify"));
    cmd.args(args).stdin(Stdio::piped()).stdout(Stdio::piped()).stderr(Stdio::null());
    if dev_mode {
        cmd.env("RISC0_DEV_MODE", "1");
    } else {
        cmd.env_remove("RISC0_DEV_MODE");
    }
    let mut child = cmd.spawn().expect("spawn gc_zk_verify");
    // The program may exit before reading stdin (argument errors); ignore EPIPE.
    let _ = child.stdin.take().unwrap().write_all(bytes);
    let out = child.wait_with_output().unwrap();
    let json = serde_json::from_slice(&out.stdout).unwrap_or(serde_json::Value::Null);
    Run { code: out.status.code().unwrap_or(-1), json }
}

fn run(args: &[&str], bytes: &[u8]) -> Run {
    run_env(args, bytes, false)
}

fn read(dir: &str, name: &str) -> Vec<u8> {
    std::fs::read(format!("{dir}/{name}")).unwrap_or_else(|e| panic!("{dir}/{name}: {e}"))
}

fn text(dir: &str, name: &str) -> String {
    String::from_utf8(read(dir, name)).unwrap().trim().to_string()
}

fn expected(name: &str) -> serde_json::Value {
    serde_json::from_slice(&read(V02, name)).unwrap()
}

const J01: &str = "gc-zk-journal-0.1";
const J02: &str = "gc-zk-journal-0.2";

#[test]
fn unknown_convention_exits_2_without_reading_the_receipt() {
    let id = text(V01, "image_id.txt");
    for bad in ["gc-zk-journal-0.3", "0.2", ""] {
        let r = run(&[&id, "--journal", bad], &read(V01, "receipt.succinct.bin"));
        assert_eq!(r.code, 2, "{bad:?}");
        assert_eq!(r.json["error"], "journal_convention_unknown");
        assert!(r.json["journal_convention"].is_null());
        assert_eq!(r.json["receipt_bytes"], 0);
    }
}

#[test]
fn bad_argument_shapes_exit_2() {
    let id = text(V01, "image_id.txt");
    for args in [
        vec![],
        vec![id.as_str(), "--journal"],
        vec![id.as_str(), "--journal", J02, "extra"],
        vec![id.as_str(), "--other", J02],
        vec!["--journal", J02, id.as_str()],
        vec!["--help"],
    ] {
        assert_eq!(run(&args, b"").code, 2, "{args:?}");
    }
}

#[test]
fn explicit_0_1_is_the_same_as_no_flag_and_keeps_the_0_1_0_field_set() {
    let id = text(V01, "image_id.txt");
    let bytes = read(V01, "receipt.succinct.bin");
    let absent = run(&[&id], &bytes);
    let explicit = run(&[&id, "--journal", J01], &bytes);
    assert_eq!(absent.code, 0);
    assert_eq!(absent.json, explicit.json);
    let mut keys: Vec<&String> = absent.json.as_object().unwrap().keys().collect();
    keys.sort();
    assert_eq!(
        keys,
        [
            "error", "journal_convention", "journal_input_sha256", "journal_ok", "journal_output_sha256",
            "receipt_bytes", "receipt_sha256", "risc0_zkvm", "tool", "verified", "version"
        ]
    );
    assert_eq!(absent.json["journal_convention"], J01);
}

#[test]
fn real_0_2_receipt_verifies_and_matches_the_ruby_computed_values() {
    let id = text(V02, "image_id_v02.txt");
    for (receipt, exp) in [
        ("receipt_v02.bin", "expected_journal_v02.json"),
        ("receipt_v02_key_b.bin", "expected_journal_v02_key_b.json"),
        ("receipt_v02_altered_output.bin", "expected_journal_v02_altered_output.json"),
    ] {
        let r = run(&[&id, "--journal", J02], &read(V02, receipt));
        let e = expected(exp);
        assert_eq!(r.code, 0);
        assert_eq!(r.json["verified"], true, "{receipt}");
        assert_eq!(r.json["journal_ok"], true, "{receipt}");
        assert!(r.json["error"].is_null());
        assert_eq!(r.json["journal_convention"], J02);
        assert_eq!(r.json["receipt_kind"], "succinct");
        for k in ["journal_key_id", "journal_input_commitment", "journal_output_commitment"] {
            assert_eq!(r.json[k], e[k], "{receipt} {k}");
        }
        // S1: no SHA-256 of a journal value under 0.2.
        assert!(r.json["journal_input_sha256"].is_null());
        assert!(r.json["journal_output_sha256"].is_null());
    }
}

#[test]
fn key_and_output_changes_move_the_values_they_should() {
    let a = expected("expected_journal_v02.json");
    let b = expected("expected_journal_v02_key_b.json");
    let alt = expected("expected_journal_v02_altered_output.json");
    for k in ["journal_key_id", "journal_input_commitment", "journal_output_commitment"] {
        assert_ne!(a[k], b[k], "another key changes {k}");
    }
    assert_eq!(a["journal_key_id"], alt["journal_key_id"]);
    assert_eq!(a["journal_input_commitment"], alt["journal_input_commitment"]);
    assert_ne!(a["journal_output_commitment"], alt["journal_output_commitment"]);
}

#[test]
fn reading_a_real_0_1_receipt_as_0_2_fails() {
    let r = run(&[&text(V01, "image_id.txt"), "--journal", J02], &read(V01, "receipt.succinct.bin"));
    assert_eq!(r.code, 0);
    assert_eq!(r.json["verified"], true);
    assert_eq!(r.json["journal_ok"], false);
    assert_eq!(r.json["error"], "journal_not_convention"); // 260 bytes: the length check
    assert!(r.json["journal_key_id"].is_null());
}

#[test]
fn a_388_byte_0_1_journal_read_as_0_2_fails_on_the_tag() {
    // 64-byte claim: (32 + 1 + 64) words = 388 bytes, the 0.2 length. Only the tag separates it.
    let bytes = read(V02, "receipt_v01_64byte_output.bin");
    let receipt: Receipt = bincode::deserialize(&bytes).unwrap();
    assert_eq!(receipt.journal.bytes.len(), 388);
    let id = text(V02, "image_id_v01.txt");
    let r = run(&[&id, "--journal", J02], &bytes);
    assert_eq!(r.json["verified"], true);
    assert_eq!(r.json["journal_ok"], false);
    assert_eq!(r.json["error"], "journal_not_convention");
    // ...and it is a perfectly good 0.1 receipt.
    let r1 = run(&[&id], &bytes);
    assert_eq!(r1.json["journal_ok"], true);
}

#[test]
fn reading_a_real_0_2_receipt_as_0_1_fails() {
    let id = text(V02, "image_id_v02.txt");
    let bytes = read(V02, "receipt_v02.bin");
    for args in [vec![id.as_str()], vec![id.as_str(), "--journal", J01]] {
        let r = run(&args, &bytes);
        assert_eq!(r.json["verified"], true);
        assert_eq!(r.json["journal_ok"], false);
        assert_eq!(r.json["error"], "journal_not_convention");
        assert!(r.json["journal_input_sha256"].is_null());
        assert!(r.json.get("journal_key_id").is_none(), "0.1 output has no 0.2 fields");
    }
}

#[test]
fn a_real_0_2_receipt_under_its_0_1_image_id_or_another_fails_verification() {
    let bytes = read(V02, "receipt_v02.bin");
    // the 0.1 image id, and an arbitrary one, so the name claims what is checked
    // (round-1 implementation review, zk-binding cosmetic)
    let other = "ab".repeat(32);
    for id in [text(V02, "image_id_v01.txt"), other] {
        let r = run(&[&id, "--journal", J02], &bytes);
        assert_eq!(r.json["verified"], false, "{id}");
        assert_eq!(r.json["error"], "verification_failed", "{id}");
        assert!(r.json["receipt_kind"].is_null(), "kind is not reported for an unverified receipt");
    }
}

#[test]
fn composite_receipt_is_refused_for_0_2() {
    let bytes = read(V02, "receipt_v02_composite.bin");
    let receipt: Receipt = bincode::deserialize(&bytes).unwrap();
    assert!(matches!(receipt.inner, InnerReceipt::Composite(_)));
    let r = run(&[&text(V02, "image_id_v02.txt"), "--journal", J02], &bytes);
    assert_eq!(r.code, 0);
    assert_eq!(r.json["verified"], true, "it is a valid receipt");
    assert_eq!(r.json["journal_ok"], false);
    assert_eq!(r.json["error"], "receipt_not_succinct");
    assert_eq!(r.json["receipt_kind"], "composite");
    assert!(r.json["journal_output_commitment"].is_null());
}

fn fake_of_real_0_2() -> Vec<u8> {
    let real: Receipt = bincode::deserialize(&read(V02, "receipt_v02.bin")).unwrap();
    let claim = real.claim().unwrap();
    let fake = Receipt::new(InnerReceipt::Fake(FakeReceipt::new(claim)), real.journal.bytes.clone());
    bincode::serialize(&fake).unwrap()
}

#[test]
fn fake_receipt_fails_verification_outside_dev_mode() {
    let r = run(&[&text(V02, "image_id_v02.txt"), "--journal", J02], &fake_of_real_0_2());
    assert_eq!(r.json["verified"], false);
    assert_eq!(r.json["error"], "verification_failed");
}

#[test]
fn fake_receipt_is_refused_for_0_2_even_in_dev_mode() {
    // RISC0_DEV_MODE in the caller's environment makes Receipt::verify pass a
    // fake receipt; the succinct allow-list is what still refuses it.
    let r = run_env(&[&text(V02, "image_id_v02.txt"), "--journal", J02], &fake_of_real_0_2(), true);
    assert_eq!(r.json["verified"], true, "dev mode passes verify — the hazard this test pins");
    assert_eq!(r.json["journal_ok"], false);
    assert_eq!(r.json["error"], "receipt_not_succinct");
    assert_eq!(r.json["receipt_kind"], "fake");
}

#[test]
fn crate_version_and_pinned_risc0_are_in_step() {
    let r = run(&[&text(V01, "image_id.txt")], &read(V01, "receipt.succinct.bin"));
    assert_eq!(env!("CARGO_PKG_VERSION"), "0.2.0");
    assert_eq!(r.json["version"], env!("CARGO_PKG_VERSION"));
    let manifest = std::fs::read_to_string(concat!(env!("CARGO_MANIFEST_DIR"), "/Cargo.toml")).unwrap();
    let pinned = format!("risc0-zkvm = {{ version = \"={}\"", r.json["risc0_zkvm"].as_str().unwrap());
    assert!(manifest.contains(&pinned), "Cargo.toml pins {pinned}");
    let lock = std::fs::read_to_string(concat!(env!("CARGO_MANIFEST_DIR"), "/Cargo.lock")).unwrap();
    assert!(lock.contains("name = \"gc_zk_verify\"\nversion = \"0.2.0\""));
    assert!(lock.contains("name = \"risc0-zkvm\"\nversion = \"3.0.6\""));
}
