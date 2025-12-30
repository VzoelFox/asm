# Morph Bytecode Specification

## Header
Signature: V Z O E L F O XS (16 bytes)
Hex: 56 20 5A 20 4F 20 45 20 4C 20 46 20 4F 20 58 53

## Registers
R0 - R15 (64-bit unsigned integers)

## Instructions (Fixed 4 Bytes)
Format: [OP:8] [DEST:8] [SRC1:8] [SRC2/IMM:8]

## Opcode List

| Opcode | Mnemonic | Args | Description |
|--------|----------|------|-------------|
| 0x01   | HALT     | -    | Stop execution (Exit 0) |
| 0x02   | LOADI    | R, V | Load Immediate: R_DEST = V (V is 8-bit, need shifting for larger) |
| 0x03   | ADD      | A, B | Add: R_DEST = R_SRC1 + R_SRC2 |
| 0x04   | SUB      | A, B | Sub: R_DEST = R_SRC1 - R_SRC2 |
| 0x05   | SYS      | -    | Syscall. Uses R0=RAX, R1=RDI, R2=RSI, R3=RDX, R4=R10, R5=R8, R6=R9 |
| 0x06   | LOADM    | R, M | Load Memory: R_DEST = [R_SRC1] (Not implemented yet) |
| 0x07   | STOREM   | R, M | Store Memory: [R_DEST] = R_SRC1 (Not implemented yet) |

## Implementation Details
- VM loads the entire file into memory.
- IP (Instruction Pointer) starts after the header.
