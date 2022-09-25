// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {LibClonesWIA} from "/LibClonesWIA.sol";

abstract contract TestImmutableArgsGas is Test {
    uint256 N = 8;
    bytes mockArg = abi.encodePacked(keccak256("arg"));

    mapping(uint256 => bytes) mockArgs;
    mapping(uint256 => mapping(uint256 => address)) clones;

    function setUp() public {
        mockArgs[0] = mockArg;

        for (uint256 i = 1; i < N; i++) {
            mockArgs[i] = abi.encodePacked(mockArgs[i - 1], mockArgs[i - 1]);
        }

        clones[0][0] = deployMockVoidCloneWIA("");

        for (uint256 j; j < N; j++) {
            clones[0][32 << j] = deployMockVoidCloneWIA(mockArgs[j]);
        }

        for (uint256 i; i < N; i++) {
            for (uint256 j = i; j < N; j++) {
                clones[32 << i][32 << j] = deployMockCloneWIA(0, 32 << i, mockArgs[j]);
            }
        }
    }

    /* ------------- virtual ------------- */

    function deployMockCloneWIA(
        uint256 readOffset,
        uint256 readSize,
        bytes memory immutableArgs
    ) internal virtual returns (address);

    function deployMockVoidCloneWIA(bytes memory immutableArgs) internal virtual returns (address);

    /* ------------- gas overhead ------------- */

    function testGas_overheadFrom0() public {
        (bool success, ) = address(clones[0][0]).call("");
        require(success);
    }

    function testGas_overheadFrom32() public {
        (bool success, ) = address(clones[0][32]).call("");
        require(success);
    }

    function testGas_overheadFrom64() public {
        (bool success, ) = address(clones[0][64]).call("");
        require(success);
    }

    function testGas_overheadFrom128() public {
        (bool success, ) = address(clones[0][128]).call("");
        require(success);
    }

    function testGas_overheadFrom256() public {
        (bool success, ) = address(clones[0][256]).call("");
        require(success);
    }

    function testGas_overheadFrom512() public {
        (bool success, ) = address(clones[0][512]).call("");
        require(success);
    }

    function testGas_overheadFrom1024() public {
        (bool success, ) = address(clones[0][1024]).call("");
        require(success);
    }

    function testGas_overheadFrom2048() public {
        (bool success, ) = address(clones[0][2048]).call("");
        require(success);
    }

    function testGas_overheadFrom4096() public {
        (bool success, ) = address(clones[0][4096]).call("");
        require(success);
    }

    /* ------------- read 32 bytes ------------- */

    function testGas_read32From32() public {
        (bool success, ) = address(clones[32][32]).call("");
        require(success);
    }

    function testGas_read32From64() public {
        (bool success, ) = address(clones[32][64]).call("");
        require(success);
    }

    function testGas_read32From128() public {
        (bool success, ) = address(clones[32][128]).call("");
        require(success);
    }

    function testGas_read32From256() public {
        (bool success, ) = address(clones[32][256]).call("");
        require(success);
    }

    function testGas_read32From512() public {
        (bool success, ) = address(clones[32][512]).call("");
        require(success);
    }

    function testGas_read32From1024() public {
        (bool success, ) = address(clones[32][1024]).call("");
        require(success);
    }

    function testGas_read32From2048() public {
        (bool success, ) = address(clones[32][2048]).call("");
        require(success);
    }

    function testGas_read32From4096() public {
        (bool success, ) = address(clones[32][4096]).call("");
        require(success);
    }

    /* ------------- read 64 bytes ------------- */

    function testGas_read64From64() public {
        (bool success, ) = address(clones[64][64]).call("");
        require(success);
    }

    function testGas_read64From128() public {
        (bool success, ) = address(clones[64][128]).call("");
        require(success);
    }

    function testGas_read64From256() public {
        (bool success, ) = address(clones[64][256]).call("");
        require(success);
    }

    function testGas_read64From512() public {
        (bool success, ) = address(clones[64][512]).call("");
        require(success);
    }

    function testGas_read64From1024() public {
        (bool success, ) = address(clones[64][1024]).call("");
        require(success);
    }

    function testGas_read64From2048() public {
        (bool success, ) = address(clones[64][2048]).call("");
        require(success);
    }

    function testGas_read64From4096() public {
        (bool success, ) = address(clones[64][4096]).call("");
        require(success);
    }

    /* ------------- read 128 bytes ------------- */

    function testGas_read128From128() public {
        (bool success, ) = address(clones[128][128]).call("");
        require(success);
    }

    function testGas_read128From256() public {
        (bool success, ) = address(clones[128][256]).call("");
        require(success);
    }

    function testGas_read128From512() public {
        (bool success, ) = address(clones[128][512]).call("");
        require(success);
    }

    function testGas_read128From1024() public {
        (bool success, ) = address(clones[128][1024]).call("");
        require(success);
    }

    function testGas_read128From2048() public {
        (bool success, ) = address(clones[128][2048]).call("");
        require(success);
    }

    function testGas_read128From4096() public {
        (bool success, ) = address(clones[128][4096]).call("");
        require(success);
    }

    /* ------------- read 256 bytes ------------- */

    function testGas_read256From256() public {
        (bool success, ) = address(clones[256][256]).call("");
        require(success);
    }

    function testGas_read256From512() public {
        (bool success, ) = address(clones[256][512]).call("");
        require(success);
    }

    function testGas_read256From1024() public {
        (bool success, ) = address(clones[256][1024]).call("");
        require(success);
    }

    function testGas_read256From2048() public {
        (bool success, ) = address(clones[256][2048]).call("");
        require(success);
    }

    function testGas_read256From4096() public {
        (bool success, ) = address(clones[256][4096]).call("");
        require(success);
    }

    /* ------------- read 512 bytes ------------- */

    function testGas_read512From512() public {
        (bool success, ) = address(clones[512][512]).call("");
        require(success);
    }

    function testGas_read512From1024() public {
        (bool success, ) = address(clones[512][1024]).call("");
        require(success);
    }

    function testGas_read512From2048() public {
        (bool success, ) = address(clones[512][2048]).call("");
        require(success);
    }

    function testGas_read512From4096() public {
        (bool success, ) = address(clones[512][4096]).call("");
        require(success);
    }

    /* ------------- read 1024 bytes ------------- */

    function testGas_read1024From1024() public {
        (bool success, ) = address(clones[1024][1024]).call("");
        require(success);
    }

    function testGas_read1024From2048() public {
        (bool success, ) = address(clones[1024][2048]).call("");
        require(success);
    }

    function testGas_read1024From4096() public {
        (bool success, ) = address(clones[1024][4096]).call("");
        require(success);
    }

    /* ------------- read 2048 bytes ------------- */

    function testGas_read2048From2048() public {
        (bool success, ) = address(clones[2048][2048]).call("");
        require(success);
    }

    function testGas_read2048From4096() public {
        (bool success, ) = address(clones[2048][4096]).call("");
        require(success);
    }

    /* ------------- read 4096 bytes ------------- */

    function testGas_read4096From4096() public {
        (bool success, ) = address(clones[4096][4096]).call("");
        require(success);
    }
}
