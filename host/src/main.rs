// TODO: Update the name of the method loaded by the prover. E.g., if the method
// is `multiply`, replace `METHOD_NAME_ELF` with `MULTIPLY_ELF` and replace
// `METHOD_NAME_ID` with `MULTIPLY_ID`
use risc0_zkvm::{
    serde::{from_slice, to_vec},
    Executor, ExecutorEnv,
};

// const BYTES: &[u8] = include_bytes!("../../target/multiply");
const BYTES: &[u8] = include_bytes!("../../guest/zig-out/bin/factors");

fn main() {
    env_logger::init();

    // First, we construct an executor environment
    let env = ExecutorEnv::builder()
        .add_input(&to_vec(&17u64).unwrap())
        .add_input(&to_vec(&23u64).unwrap())
        .build()
        .unwrap();

    // Next, we make an executor, loading the (renamed) ELF binary.
    let mut exec = Executor::from_elf(env, BYTES).unwrap();

    // Run the executor to produce a session.
    let session = exec.run().unwrap();

    // Prove the session to produce a receipt.
    let receipt = session.prove().unwrap();

    // Extract journal of receipt (i.e. output c, where c = a * b)
    let c: u64 = from_slice(&receipt.journal).expect(
        "Journal output should deserialize into the same types (& order) that it was written",
    );

    assert_eq!(c, 17 * 23);

    // TODO: Implement code for transmitting or serializing the receipt for
    // other parties to verify here

    // let image_id = risc0_binfmt::compute_image_id(BYTES).unwrap();
    // // Optional: Verify receipt to confirm that recipients will also be able to
    // // verify your receipt
    // receipt.verify(image_id).unwrap();
}
