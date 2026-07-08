# Computer Architecture Homework

Verilog로 작성한 컴퓨터 구조 과제 모음입니다. `HW01`부터 `HW06`까지 ALU, Register File, 단일 사이클 CPU, 멀티 사이클 CPU, 파이프라인 CPU, 분기 예측 CPU 순서로 기능을 확장했습니다.

## Directory Overview

| 폴더 | 주제 | 주요 변경사항 |
| --- | --- | --- |
| `HW01` | ALU 구현 및 검증 | 기본 산술/논리/시프트 연산을 수행하는 32-bit ALU 구현, `.mem` 테스트 벡터 기반 검증 |
| `HW02` | Register File + ALU 통합 | Register File을 추가하고 ALU와 연결한 `TOP` 모듈 구성, 읽기/쓰기 제어 및 write-back 데이터 검증 |
| `HW03` | Single-cycle CPU | 명령어 fetch/decode/execute/memory/write-back을 한 사이클 안에서 처리하는 CPU 구현 |
| `HW04` | Multi-cycle CPU | FSM 기반 제어 흐름 도입, `IR`, `MDR`, `A`, `B`, `ALUOut` 등 내부 레지스터를 사용해 명령어를 여러 사이클로 분할 처리 |
| `HW05` | Pipelined CPU | IF/ID, ID/EX, EX/MEM, MEM/WB 파이프라인 레지스터 추가, hazard detection과 flush 처리 구현 |
| `HW06` | Branch Prediction CPU | 파이프라인 CPU에 forwarding과 branch predictor 추가, BTB/PHT 기반 예측 및 misprediction flush 처리 |

## Homework Details

### HW01 - ALU

- `ALU.v`: 32-bit ALU 구현
- `GLOBAL.v`: ALU operation code 정의
- `ALU_tb.v`: 10,000개 테스트 벡터 기반 ALU 검증
- 지원 연산: `ADDU`, `SUBU`, `AND`, `OR`, `XOR`, `NOR`, `SLL`, `SRL`, `SRA`, `SLT`, `SLTU`, `EQ`, `NEQ`, `LUI`

### HW02 - Register File and ALU

- `RF.v`: 32개 32-bit 레지스터를 가지는 Register File 구현
- `TOP.v`: Register File과 ALU를 연결한 통합 모듈
- `TOP_tb.v`: register read/write와 ALU 결과를 `.mem` 파일 기준으로 검증
- `initial_reg.mem`을 통해 초기 register 상태를 로드

### HW03 - Single-cycle CPU

- `CPU.v`: 단일 사이클 MIPS-like CPU 구현
- `CTRL.v`: opcode/funct 기반 control signal 생성
- `MEM.v`: instruction/data memory 통합 관리
- `RF.v`, `ALU.v`: CPU datapath 구성 요소로 사용
- R-type, immediate, load/store, branch, jump, `jal`, `jr` 계열 명령어를 제어 신호로 처리

### HW04 - Multi-cycle CPU

- 단일 사이클 구조를 멀티 사이클 구조로 변경
- `CTRL.v`에서 FSM state 기반 control signal 생성
- `CPU.v`에 `IR`, `MDR`, `A`, `B`, `ALUOut` 등 사이클 간 값을 저장하는 내부 레지스터 추가
- `IorD`, `IRWrite`, `PCWrite`, `PCWriteCond`, `ALUSrcA`, `ALUSrcB`, `PCSource` 등을 사용해 단계별 datapath 제어

### HW05 - Pipelined CPU

- 5-stage pipeline 구조 구현: IF, ID, EX, MEM, WB
- `IFID`, `IDEX`, `EXMEM`, `MEMWB` 파이프라인 레지스터 추가
- `HAZARD.v`: load-use hazard 등 파이프라인 stall 조건 처리
- branch/jump 결과에 따라 pipeline flush 수행
- `halt` 조건을 MEM/WB 단계 기준으로 처리해 파이프라인에 남은 명령어가 정리되도록 구성

### HW06 - Branch Prediction and Forwarding

- `BP.v`: Branch Predictor 추가
- BTB 64-entry, PHT 256-entry 기반 예측 구조 사용
- jump는 BTB target을 사용하고 branch는 PHT의 2-bit saturating counter로 taken/not-taken 예측
- EX/MEM, MEM/WB 단계의 결과를 EX 단계로 전달하는 forwarding logic 추가
- 실제 next PC와 예측 PC가 다르면 misprediction으로 판단하고 flush 수행

## File Structure

```text
.
├── HW01
│   ├── ALU.v
│   ├── ALU_tb.v
│   └── *.mem
├── HW02
│   ├── ALU.v
│   ├── RF.v
│   ├── TOP.v
│   ├── TOP_tb.v
│   └── *.mem
├── HW03
│   ├── CPU.v
│   ├── CTRL.v
│   ├── ALU.v
│   ├── RF.v
│   ├── MEM.v
│   └── CPU_tb.v
├── HW04
│   └── multi-cycle CPU modules
├── HW05
│   └── pipelined CPU modules with hazard detection
└── HW06
    └── pipelined CPU modules with branch prediction
```

## How to Run

Icarus Verilog 기준 예시입니다.

```bash
cd HW01
iverilog -o sim ALU_tb.v ALU.v
vvp sim
```

```bash
cd HW02
iverilog -o sim TOP_tb.v TOP.v RF.v ALU.v
vvp sim
```

CPU 과제는 테스트벤치가 `reference_mem.mem`, `reference_reg.mem`을 읽도록 되어 있으므로 해당 파일이 있는 상태에서 실행합니다.

```bash
cd HW06
iverilog -o sim CPU_tb.v CPU.v CTRL.v ALU.v RF.v MEM.v HAZARD.v BP.v
vvp sim
```

## Notes

- 공통 상수와 opcode/funct 정의는 각 폴더의 `GLOBAL.v`에 정리되어 있습니다.
- `b.out`, `a.out` 등은 시뮬레이션/컴파일 과정에서 생성된 출력 파일입니다.
- 각 homework 폴더는 독립적으로 컴파일할 수 있도록 필요한 Verilog 파일을 포함합니다.
