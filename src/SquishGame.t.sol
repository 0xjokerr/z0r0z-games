// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.6;

import {DSTest} from "ds-test/test.sol";

import {MockERC20} from "solmate/test/utils/MockERC20.sol";

import {SquishiGame} from "./SquishiGame.sol";

import "./utils/vm.sol";

contract VaultFactoryTest is DSTest {
    Vm vm = Vm(address(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D));
    SquishiGame game;
    MockERC20 sushi;
    address eoaAddress = address(100);

    function setUp() public {
        sushi = new MockERC20("Sushi Token", "SUSHI", 18);
        sushi.mint(address(this), 10 ether);

        address predictedAddress = address(uint160(uint(keccak256(abi.encodePacked(
            bytes1(0xff),
            address(this),
            bytes32("1"),
            keccak256(abi.encodePacked(
                type(SquishiGame).creationCode,
                abi.encode(sushi)
            ))
        )))));

        sushi.mint(predictedAddress, 29 ether);
        game = new SquishiGame{salt: bytes32("1")}(sushi);
        assertEq(predictedAddress, address(game));
    }

    function testSanity() public {
        assertEq(game.players(), 0);
        // assertEq(address(g), address(game));
    }

    function testPlay() public {
        // Join
        Player p = new Player(game, sushi);
        sushi.mint(address(p), 5 ether);
        p.join();
        assertEq(game.players(), 1);
        assertTrue(game.isAlive(address(p)));

        Player p2 = new Player(game, sushi);
        sushi.mint(address(p2), 5 ether);
        p2.join();
        assertEq(game.players(), 2);
        assertTrue(game.isAlive(address(p2)));

        assertEq(game.pot(), 29 ether);


        // Play

        for(uint i = 0; i < 8; i++) {
            vm.warp(block.timestamp + 2 hours);
            p.hit(address(p2));
        }

        vm.warp(block.timestamp + 2 hours);
        p.heal(address(p2));
        assertEq(game.health(address(p2)), uint256(2));

        vm.warp(block.timestamp + 2 hours);
        p.hit(address(p2));
        assertEq(game.health(address(p2)), uint256(1));

        vm.warp(block.timestamp + 2 hours);
        p.hit(address(p2));
        assertEq(game.health(address(p2)), uint256(0));

        assertTrue(!game.isAlive(address(p2)));

        vm.warp(block.timestamp + 10 days);
        p.claimWinnings();

        assertEq(game.players(), 1);
        assertEq(sushi.balanceOf(address(game)), 4 ether);

        assertEq(game.pot(), 29 ether);

        assertEq(game.potClaimed(), 29 ether); // dafuq

        assertEq(sushi.balanceOf(address(p)), 31 ether);
    }
}

contract Player {
    SquishiGame game;
    MockERC20 sushi;
    constructor(SquishiGame _game, MockERC20 _sushi) {
        game = _game;
        sushi = _sushi;
    }

    function join() public {
        sushi.approve(address(game), 3 ether);
        game.join();
    }

    function hit(address _victim) public {
        game.hit(_victim);
    }

    function heal(address _friend) public {
        game.heal(_friend);
    }

    function claimWinnings() public {
        game.claimWinnings();
    }
}
