// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Simple responder that emits an alert. No constructor args.
contract EigenAVSRewardRateResponder {
    /// @param reporter the caller (Drosera executor) - useful to see which agent executed the response
    /// @param currentRate current reward emission rate
    /// @param avgRate moving average rate baseline
    /// @param driftBps computed drift in basis points
    event RewardDriftAlert(address indexed reporter, uint256 currentRate, uint256 avgRate, uint256 driftBps);

    /// Called by Drosera when shouldRespond() returns true.
    /// The Drosera relay should call with the encoded current values and the computed/observed drift BPS.
    /// We emit an event so off-chain monitoring can pick it up.
    function respondWithRewardDrift(uint256 currentRate, uint256 avgRate, uint256 driftBps) external {
        emit RewardDriftAlert(msg.sender, currentRate, avgRate, driftBps);
    }
}
