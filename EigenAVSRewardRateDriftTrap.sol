// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ITrap} from "drosera-contracts/interfaces/ITrap.sol";

/// @title EigenAVSRewardRateDriftTrap
/// @notice Monitors reward emission rate drift for EigenLayer AVSs on Hoodi testnet.
/// @dev Stateless trap — collect() data must be supplied externally by Drosera relayer.
/// Encoded sample format:
///   abi.encode(uint256 currentRate, uint256 avgRate, uint256 driftThresholdBps, uint256 velocityThreshold)
contract EigenAVSRewardRateDriftTrap is ITrap {

    /// @notice For local dryrun or testing, return dummy-encoded sample data
    /// that satisfies the decoder in shouldRespond().
    /// This prevents "Reverted: None" during drosera dryrun/apply.
    function collect() external view override returns (bytes memory) {
        uint256 currentRate = 100;          // example simulated reward rate
        uint256 avgRate = 80;               // example average baseline
        uint256 driftThresholdBps = 500;    // 5% drift threshold
        uint256 velocityThreshold = 10;     // velocity change threshold
        return abi.encode(currentRate, avgRate, driftThresholdBps, velocityThreshold);
    }

    /// @notice Off-chain Drosera executor calls this with data[] history from prior collect() calls.
    /// @return (shouldRespond, payload) where payload encodes (currentRate, avgRate, driftBps)
    function shouldRespond(bytes[] calldata data) external pure override returns (bool, bytes memory) {
        if (data.length == 0) return (false, bytes(""));

        (
            uint256 currentRate,
            uint256 avgRate,
            uint256 driftThresholdBps,
            uint256 velocityThreshold
        ) = abi.decode(data[0], (uint256, uint256, uint256, uint256));

        if (avgRate == 0) {
            return (false, bytes(""));
        }

        uint256 diff = currentRate > avgRate ? currentRate - avgRate : avgRate - currentRate;
        uint256 driftBps = (diff * 10000) / avgRate;

        // Main drift condition
        if (driftBps > driftThresholdBps) {
            // Encode values expected by the responder
            return (true, abi.encode(currentRate, avgRate, driftBps));
        }

        // Optional velocity condition
        if (data.length >= 2) {
            (uint256 prevCurrentRate, , , ) = abi.decode(data[1], (uint256, uint256, uint256, uint256));
            uint256 velocity = currentRate > prevCurrentRate
                ? currentRate - prevCurrentRate
                : prevCurrentRate - currentRate;

            if (velocity > velocityThreshold) {
                // Reuse velocity as driftBps proxy for responder consistency
                return (true, abi.encode(currentRate, avgRate, velocity));
            }
        }

        return (false, bytes(""));
    }
}
