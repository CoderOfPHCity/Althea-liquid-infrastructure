// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.12;

import "forge-std/Test.sol";
import "../contracts/LiquidInfrastructureERC20.sol";

import "../contracts/TestERC20A.sol";

import "../contracts/TestERC20B.sol";

import "../contracts/TestERC20C.sol";

import "../contracts/TestERC721A.sol";

contract LiquidInfrastructureERC20Test is Test {
    LiquidInfrastructureERC20 public liquidInfrastructureERC20;
    TestERC20A public mockDistributableTokenA;
    TestERC20B public mockDistributableTokenB;
    TestERC20C public mockDistributableTokenC;

    address public owner;
    address public holder1;
    address public holder2;

    address holder3 = makeAddr("holder3");
    address holder4 = makeAddr("holder4");
    address holder5 = makeAddr("holder5");

    function setUp() public {
        owner = address(this);
        holder1 = address(1);
        holder2 = address(2);

        address[] memory managedNFTs = new address[](0);
        address[] memory approvedHolders = new address[](2);
        approvedHolders[0] = holder1;
        approvedHolders[1] = holder2;
        address[] memory distributableERC20s = new address[](1);

        mockDistributableTokenA = new TestERC20A();
        mockDistributableTokenB = new TestERC20B();
        mockDistributableTokenC = new TestERC20C();

        distributableERC20s[0] = address(mockDistributableTokenA);

        liquidInfrastructureERC20 = new LiquidInfrastructureERC20(
            "daniel Token", "DNT", managedNFTs, approvedHolders, 500, distributableERC20s
        );

        liquidInfrastructureERC20.transferOwnership(owner);
    }

    function testMint() public {
        vm.startPrank(holder3);
        uint256 mintAmount = 1000 * 10 ** 18;
        vm.expectRevert("Ownable: caller is not the owner");
        liquidInfrastructureERC20.mint(holder1, mintAmount);
    }

    function testApproveHolder() public {
        vm.startPrank(owner);
        liquidInfrastructureERC20.approveHolder(owner);
        assertTrue(liquidInfrastructureERC20.isApprovedHolder(owner));

        // Approve holder1 again to see revert
        vm.expectRevert("holder already approved");
        liquidInfrastructureERC20.approveHolder(owner);
    }

    function testMintToUnapprovedHolders() public {
        uint256 mintAmount = 1000 * 10 ** 18;
        uint256 initialSupply = liquidInfrastructureERC20.totalSupply();

        // unapproved holder3
        vm.expectRevert("receiver not approved to hold the token");
        liquidInfrastructureERC20.mint(holder3, mintAmount);
        assertEq(liquidInfrastructureERC20.balanceOf(holder3), 0);

        // mint and distribute to unapproved holder3
        vm.expectRevert("receiver not approved to hold the token");
        liquidInfrastructureERC20.mintAndDistribute(holder3, mintAmount);
        assertEq(liquidInfrastructureERC20.totalSupply(), initialSupply);
        assertEq(liquidInfrastructureERC20.balanceOf(holder3), 0);
    }

    function testApproveDisapproveWithWrongAccount() public {
        address nonOwner = makeAddr("nonOwner");
        vm.startPrank(nonOwner);

        //  approve holder1 using a non-owner account
        vm.expectRevert("Ownable: caller is not the owner");
        liquidInfrastructureERC20.approveHolder(holder1);
        assertFalse(liquidInfrastructureERC20.isApprovedHolder(holder3));

        //  disapprove holder2 using a non-owner account
        vm.expectRevert("Ownable: caller is not the owner");
        liquidInfrastructureERC20.disapproveHolder(holder3);
        assertFalse(liquidInfrastructureERC20.isApprovedHolder(holder3));
    }
}
