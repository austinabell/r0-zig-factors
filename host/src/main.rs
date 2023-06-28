// TODO: Update the name of the method loaded by the prover. E.g., if the method
// is `multiply`, replace `METHOD_NAME_ELF` with `MULTIPLY_ELF` and replace
// `METHOD_NAME_ID` with `MULTIPLY_ID`
use risc0_zkvm::{
    // serde::{from_slice, to_vec},
    Executor, ExecutorEnv,
};

const BYTES: &[u8] = include_bytes!("../../guest/zig-out/bin/factors");

fn main() {
    // First, we construct an executor environment
    let env = ExecutorEnv::builder()
        .add_input(&[0u8; 31])
        .add_input(&[0u8; 33])
        .build();

    // Next, we make an executor, loading the (renamed) ELF binary.
    let mut exec = Executor::from_elf(env, BYTES).unwrap();

    // Run the executor to produce a session.
    let session = exec.run().unwrap();

    // Prove the session to produce a receipt.
    let _receipt = session.prove().unwrap();

    // TODO: Implement code for transmitting or serializing the receipt for
    // other parties to verify here

    // Optional: Verify receipt to confirm that recipients will also be able to
    // verify your receipt
    // receipt.verify(METHOD_NAME_ID).unwrap();
}
