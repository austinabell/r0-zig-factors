use risc0_zkvm::{default_prover, ExecutorEnv};

// const BYTES: &[u8] = include_bytes!("../../target/multiply");
const BYTES: &[u8] = include_bytes!("../../guest/zig-out/bin/factors");

fn main() {
    env_logger::init();

    let env = ExecutorEnv::builder()
        .write(&17u64)
        .unwrap()
        .write(&23u64)
        .unwrap()
        .build()
        .unwrap();
    let prover = default_prover();
    let receipt = prover.prove_elf(env, BYTES).unwrap();

    // Extract journal of receipt (i.e. output c, where c = a * b)
    let c: u64 = receipt.journal.decode().unwrap();

    assert_eq!(c, 17 * 23);

    // TODO: Implement code for transmitting or serializing the receipt for
    // other parties to verify here

    // let image_id = risc0_binfmt::compute_image_id(BYTES).unwrap();
    // // Optional: Verify receipt to confirm that recipients will also be able to
    // // verify your receipt
    // receipt.verify(image_id).unwrap();
}
