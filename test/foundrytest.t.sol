// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.12;

import "forge-std/Test.sol";
import "../contracts/LiquidInfrastructureERC20.sol";
import "../contracts/LiquidInfrastructureNFT.sol";

import "../contracts/TestERC20A.sol";

import "../contracts/TestERC20B.sol";

import "../contracts/TestERC20C.sol";

import "../contracts/TestERC721A.sol";

contract LiquidInfrastructureERC20Test is Test {
    LiquidInfrastructureERC20 public liquidInfrastructureERC20;
    LiquidInfrastructureNFT public liquidInfrastructureNFT;

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

        // mockDistributableTokenB = new TestERC20B();
        // mockDistributableTokenC = new TestERC20C();

        distributableERC20s[0] = address(mockDistributableTokenA);

        liquidInfrastructureERC20 =
            new LiquidInfrastructureERC20("daniel Token", "DNT", managedNFTs, approvedHolders, 500, distributableERC20s);

        liquidInfrastructureERC20.transferOwnership(owner);

        liquidInfrastructureNFT = new LiquidInfrastructureNFT("account1");
        // liquidInfrastructureNFT = new LiquidInfrastructureNFT("account2");
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
        address pelz = makeAddr("nonOwner");
        vm.startPrank(pelz);

        vm.expectRevert("Ownable: caller is not the owner");
        liquidInfrastructureERC20.approveHolder(holder1);
        assertFalse(liquidInfrastructureERC20.isApprovedHolder(holder3));

        //  disapprove holder2 using a non-owner account
        vm.expectRevert("Ownable: caller is not the owner");
        liquidInfrastructureERC20.disapproveHolder(holder3);
        assertFalse(liquidInfrastructureERC20.isApprovedHolder(holder3));
    }

    function testGrantHolder1FailToTransfer() public {
        uint256 mintAmount = 1000;

        liquidInfrastructureERC20.mintAndDistribute(holder1, mintAmount);

        assertEq(liquidInfrastructureERC20.balanceOf(holder1), 1000);

        vm.startPrank(holder3);
        vm.expectRevert("receiver not approved to hold the token");
        liquidInfrastructureERC20.transfer(holder3, mintAmount);

        assertEq(liquidInfrastructureERC20.balanceOf(holder1), 1000);
        assertEq(liquidInfrastructureERC20.balanceOf(holder3), 0);
    }

    function testSuccessfullyApproveHolder2() public {
        uint256 mintAmount = 1000;

        liquidInfrastructureERC20.approveHolder(holder3);

        liquidInfrastructureERC20.mintAndDistribute(holder3, mintAmount);
        assertTrue(liquidInfrastructureERC20.isApprovedHolder(holder3));

        liquidInfrastructureERC20.approveHolder(holder4);

        // liquidInfrastructureERC20.transfer(holder4, 100);

        assertEq(liquidInfrastructureERC20.balanceOf(holder3), 1000);
        assertEq(liquidInfrastructureERC20.balanceOf(holder4), 0);
    }

    function testNftManagement() public {
        LiquidInfrastructureNFT nft1 = new LiquidInfrastructureNFT("account1");
        LiquidInfrastructureNFT nft2 = new LiquidInfrastructureNFT("account2");

        // Test transferring NFT to ERC20
        transferNftToErc20AndManage(liquidInfrastructureERC20, nft1, owner);

        liquidInfrastructureERC20.releaseManagedNFT(address(nft1), owner);
        assertEq(nft1.ownerOf(nft1.AccountId()), owner);

        address badSigner = address(3);
        vm.startPrank(badSigner);

        vm.expectRevert("Ownable: caller is not the owner");
        liquidInfrastructureERC20.addManagedNFT(address(nft2));
        vm.stopPrank();
    }

    function transferNftToErc20AndManage(
        LiquidInfrastructureERC20 infraERC20,
        LiquidInfrastructureNFT nftToManage,
        address nftOwner
    ) public {
        nftToManage.transferFrom(nftOwner, address(infraERC20), nftToManage.AccountId());
        assertEq(nftToManage.ownerOf(nftToManage.AccountId()), address(infraERC20));

        infraERC20.addManagedNFT(address(nftToManage));
    }

    function testBasicDistributionTests() public {
        vm.startPrank(owner);
        LiquidInfrastructureNFT nft1 = new LiquidInfrastructureNFT("NFT1");

        IERC20 erc20a = mockDistributableTokenA;

        // Register one NFT
        transferNftToErc20AndManage(liquidInfrastructureERC20, nft1, owner);

        nft1 = LiquidInfrastructureNFT(address(nft1));

        // Allocate some rewards to the NFT
        uint256 rewardAmount1 = 100;
        erc20a.transfer(address(nft1), rewardAmount1);
        assertEq(erc20a.balanceOf(address(nft1)), rewardAmount1);

        liquidInfrastructureERC20.withdrawFromAllManagedNFTs();
        liquidInfrastructureERC20.distributeToAllHolders();
    }
}
