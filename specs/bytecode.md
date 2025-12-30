# Register & Opcode Plan (Phase 2 Update)

## Register Map (Phase 2)
- R0 - R9 : User Variables (mapped sequentially by compiler)
- R10     : Arithmetic Result Register (Implicit)
- R11-R12 : Scratch Registers

## Opcode List
| Opcode | Mnemonic | Args | Action |
|--------|----------|------|--------|
| 0x01   | HALT     | -    | Stop execution |
| 0x02   | LOADI    | D, V | R[D] = Immediate(V) |
| 0x03   | ADD      | D, S1, S2 | R[D] = R[S1] + R[S2] |
| 0x04   | SUB      | D, S1, S2 | R[D] = R[S1] - R[S2] |
| 0x05   | SYSCALL  | -    | Syscall (R0=RAX, R1=RDI...) |
| 0x09   | MUL      | D, S1, S2 | R[D] = R[S1] * R[S2] |
| 0x0A   | DIV      | D, S1, S2 | R[D] = R[S1] / R[S2] |
| 0x0B   | MOV      | D, S1 | R[D] = R[S1] |
| 0xAA   | PRT_CHR  | _, C | Debug: Print Char C |
| 0xAB   | PRT_INT  | S1   | Debug: Print Int R[S1] |
