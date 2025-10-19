# EigenAVSRewardRateTrap
## Overview

**EigenAVSRewardRateDriftTrap** is a Drosera-compatible monitoring trap that detects anomalies in **reward emission rates** for EigenLayer AVSs deployed on the **Hoodi testnet**.  
It measures **drift** and **velocity** in reward rate changes over time and triggers an alert when deviations exceed defined thresholds.

The trap is **stateless** — all rate data is supplied externally via Drosera’s off-chain relayer.  
When a significant deviation is observed, it calls the responder contract `EigenAVSRewardRateResponder`, which emits a structured on-chain alert event for downstream analysis or automation.

---

## Purpose

Reward rate stability is a key health metric for AVSs (Actively Validated Services).  
Sudden changes may signal:
- configuration drift in AVS reward contracts,
- unexpected parameter updates,
- liquidity or reward pool imbalance,
- or malicious manipulation.

By continuously tracking both the **absolute drift** (deviation from the average rate) and **velocity** (rate-of-change), this trap provides early warnings that can be consumed by monitoring systems or automated responses.

---

## Architecture

```

+------------------------------+

| Drosera Relay (off-chain)        |
| -------------------------------- |
| 1. Collect() feeds encoded       |
| samples to Drosera node          |
| 2. shouldRespond() evaluates     |
| threshold conditions             |
| 3. If alert: triggers            |
| respondWithRewardDrift()         |
| +------------------------------+ |

```
           │
           ▼
```

+-----------------------------------+

| EigenAVSRewardRateResponder           |
| ------------------------------------- |
| Emits RewardDriftAlert event:         |
| - reporter (executor)                 |
| - currentRate                         |
| - avgRate                             |
| - driftBps                            |
| +-----------------------------------+ |

````

---

## Contracts

### `EigenAVSRewardRateDriftTrap.sol`

Stateless trap implementing the Drosera `ITrap` interface.

#### Encoded Sample Format
Each sample must be ABI-encoded as:
```solidity
abi.encode(
  uint256 currentRate,          // current emission rate
  uint256 avgRate,              // long-term moving average
  uint256 driftThresholdBps,    // drift threshold in basis points
  uint256 velocityThreshold     // velocity threshold in same units
);
````

#### Core Functions

| Function                               | Type            | Description                                                                                |
| -------------------------------------- | --------------- | ------------------------------------------------------------------------------------------ |
| `collect()`                            | `external view` | Returns encoded rate data. For dryruns, returns simulated test values.                     |
| `shouldRespond(bytes[] calldata data)` | `external pure` | Evaluates rate samples. Returns `(true, payload)` if drift or velocity exceeds thresholds. |

#### Response Encoding

When triggered, the payload sent to the responder is encoded as:

```solidity
abi.encode(currentRate, avgRate, driftBps)
```

---

### `EigenAVSRewardRateResponder.sol`

A minimal responder contract that emits an on-chain alert when the trap signals a threshold breach.

#### Event

```solidity
event RewardDriftAlert(
    address indexed reporter,
    uint256 currentRate,
    uint256 avgRate,
    uint256 driftBps
);
```

#### Function

```solidity
function respondWithRewardDrift(
    uint256 currentRate,
    uint256 avgRate,
    uint256 driftBps
) external;
```

This function is called automatically by the Drosera executor.
It emits a `RewardDriftAlert` event that can be tracked by off-chain systems or subgraphs for notification and analytics.

---

## Detection Logic

| Condition    | Formula                                                            | Trigger                                                                                               |
| ------------ | ------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------- |
| **Drift**    | `abs(currentRate - avgRate) * 10000 / avgRate > driftThresholdBps` | Emits alert if current reward rate diverges from the moving average beyond the allowed BPS threshold. |
| **Velocity** | `abs(currentRate - prevCurrentRate) > velocityThreshold`           | Emits alert if the rate changes too quickly between consecutive samples.                              |

Both checks return a deterministic Boolean result that Drosera uses to decide whether to execute the responder.

---

## drosera.toml Configuration

```toml
ethereum_rpc = "https://ethereum-hoodi-rpc.publicnode.com"
drosera_rpc = "https://relay.hoodi.drosera.io"
eth_chain_id = 560048
drosera_address = "0x91cB447BaFc6e0EA0F4Fe056F5a9b1F14bb06e5D"

[traps]

[traps.reward_rate_drift]
path = "out/EigenAVSRewardRateDriftTrap.sol/EigenAVSRewardRateDriftTrap.json"
response_contract = "0x8d9eD62B65e3c8D7871183DE467fcA51eD0020D9"
response_function = "respondWithRewardDrift(uint256,uint256,uint256)"
cooldown_period_blocks = 30
min_number_of_operators = 1
max_number_of_operators = 2
block_sample_size = 10
private_trap = true
whitelist = ["0x56a2431474C2feAB0F37f612DD6c34B07986B5Ca"]
address = "0xA6fCbC9efc7A63d03546A992F8a7194890e6841F"
```

**Key Parameters:**

| Parameter                | Meaning                                                              |
| ------------------------ | -------------------------------------------------------------------- |
| `cooldown_period_blocks` | Minimum number of blocks between consecutive responses               |
| `block_sample_size`      | Number of recent collect samples Drosera passes to `shouldRespond()` |
| `private_trap`           | Restricts execution to specific whitelisted operators                |
| `whitelist`              | Authorized executors’ addresses                                      |
| `response_function`      | Must match responder’s function signature                            |

---

## Local Testing

### 1. Compile and Build

```bash
forge build
```

### 2. Dryrun (simulate trap behavior)

```bash
drosera dryrun
```

Expected output:

```
Running trap: reward_rate_drift
result: "ok"
```

### 3. Apply to Drosera Relay

```bash
DROSERA_PRIVATE_KEY=<your-private-key> drosera apply
```

Drosera verifies the trap, validates the responder function signature, and deploys the configuration to the Hoodi relay.

---

## Event Example

If a deviation exceeds the configured threshold, Drosera executes the responder and the blockchain logs:

```
RewardDriftAlert(
  reporter: 0x56a2431474C2feAB0F37f612DD6c34B07986B5Ca,
  currentRate: 100,
  avgRate: 80,
  driftBps: 2500
)
```

This indicates a **25% drift** from baseline and can be indexed or visualized in monitoring dashboards.

---

## Summary

| Component                     | Role                                     |
| ----------------------------- | ---------------------------------------- |
| `EigenAVSRewardRateDriftTrap` | Evaluates reward rate anomalies          |
| `EigenAVSRewardRateResponder` | Emits alerts for off-chain handling      |
| `drosera.toml`                | Configuration linking trap and responder |
| Hoodi Relay                   | Executes trap evaluations and responses  |

---
