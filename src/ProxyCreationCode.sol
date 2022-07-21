// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC1967Proxy.sol";
import {utils} from "./utils/utils.sol";

error InvalidOffset(uint256 expected, uint256 actual);
error ExceedsMaxArgSize(uint256 size);

/// @notice Verifies that implementation contract conforms to ERC1967
/// @notice This can be part of creationcode, but doesn't have to be
/// @param implementation address containing the implementation logic
function verifyIsProxiableContract(address implementation) view {
    if (implementation.code.length == 0) revert NotAContract();

    bytes32 uuid = ERC1822(implementation).proxiableUUID();

    if (uuid != ERC1967_PROXY_STORAGE_SLOT) revert InvalidUUID();
}

/// @dev Expects `implementation` (imp) to be on top of the stack
/// @dev Must leave a copy of `implementation` (imp) on top of the stack
/// @param pc program counter, used for calculating offsets
function initCallcode(uint256 pc, bytes memory initCalldata) pure returns (bytes memory code) {
    uint256 initCalldataSize = initCalldata.length;

    if (initCalldataSize != 0) {

        code = abi.encodePacked(
            // push initCalldata to stack in 32 bytes chunks and store in memory at pos 0 

            MSTORE(0, initCalldata),                    // MSTORE icd       |                           | [0, ics) = initcalldata

            /// let success := delegatecall(gas(), implementation, 0, initCalldataSize, 0, 0)

            hex"3d"                                     // RETURNDATASIZE   | 00  imp                   | [0, ics) = initcalldata
            hex"3d",                                    // RETURNDATASIZE   | 00  00  imp               | [0, ics) = initcalldata
            PUSHX(initCalldataSize),                    // PUSHX ics        | ics 00  00  imp           | [0, ics) = initcalldata
            hex"3d"                                     // RETURNDATASIZE   | 00  ics 00  00  imp       | [0, ics) = initcalldata
            hex"84"                                     // DUP5             | imp 00  ics 00  00  imp   | [0, ics) = initcalldata
            hex"5a"                                     // GAS              | gas imp 00  ics 00  00  ..| [0, ics) = initcalldata
            hex"f4"                                     // DELEGATECALL     | scs imp                   | ...
        );

        // advance program counter
        pc += code.length;

        code = abi.encodePacked(code,
            /// if iszero(success) { revert(0, returndatasize()) }

            REVERT_ON_FAILURE(pc)                       //                  | imp                       | ...

            // RETURN_REVERT_REASON_ON_FAILURE_TEST(pc)                       //                  | imp                       | ...
        );
    }
}

/// @notice Returns the creation code for an ERC1967 proxy with immutable args (max. 2^16 - 1 bytes)
/// @param implementation address containing the implementation logic
/// @param runtimecode evm bytecode (runtime + concatenated extra data)
/// @return creationcode evm bytecode that deploys ERC1967 proxy runtimecode
function proxyCreationCode(
    address implementation,
    bytes memory runtimecode,
    bytes memory initCalldata
) pure returns (bytes memory creationcode) {
    // program counter
    uint256 pc = 0;

    creationcode = abi.encodePacked(
        /// log2(0, 0, UPGRADED_EVENT_SIG, logic)

        hex"73", implementation,                    // PUSH20 imp       | imp
        hex"80"                                     // DUP1             | imp imp
        hex"7f", UPGRADED_EVENT_SIG,                // PUSH32 ues       | ues imp imp
        hex"3d"                                     // RETURNDATASIZE   | 00  ues imp imp
        hex"3d"                                     // RETURNDATASIZE   | 00  00  ues imp imp
        hex"a2"                                     // LOG2             | imp
    );

    pc = creationcode.length;

    // optional: insert code to call implementation contract with initCalldata during contract creation
    if (initCalldata.length != 0) {
        bytes memory callcode = initCallcode(pc, initCalldata);

        creationcode = abi.encodePacked(creationcode, callcode);

        pc = creationcode.length;
    }


    // runtimeOffset: offset from which to copy the runtime code = pc + size of next block
    uint16 rto = uint16(pc + 45);

    uint256 runtimeSize = runtimecode.length; // runtime code is concatenated with args

    // hardcoded PUSH1 for now
    if (runtimeSize > type(uint16).max) revert ExceedsMaxArgSize(runtimeSize);

    uint16 rts = uint16(runtimeSize);

    creationcode = abi.encodePacked( creationcode,
        /// sstore(ERC1967_PROXY_STORAGE_SLOT, implementation)

        hex"7f", ERC1967_PROXY_STORAGE_SLOT,        // PUSH32 pss       | pss imp
        hex"55"                                     // SSTORE           | 

        /// codecopy(0, rto, rts)

        hex"61", rts,                               // PUSH2 rts        | rts
        hex"80"                                     // DUP1             | rts rts
        hex"61", rto,                               // PUSH1 rto        | rto rts rts
        hex"3d"                                     // RETURNDATASIZE   | 00  rto rts rts
        hex"39"                                     // CODECOPY         | rts                       | [00, rts) = runtimecode + args

        /// return(0, rts)

        hex"3d"                                     // RETURNDATASIZE   | 00  rts
        hex"f3"                                     // RETURN
    ); // prettier-ignore

    pc = creationcode.length;

    // validation for runtime location parameter
    if (pc != rto) revert InvalidOffset(rto, creationcode.length);

    creationcode = abi.encodePacked(
        creationcode,
        runtimecode
    ); // prettier-ignore
}

/// @notice Returns the runtime code for an ERC1967 proxy with immutable args (max. 2^16 - 1 bytes)
/// @param args immutable args byte array
/// @return runtimecode evm bytecode
function proxyRuntimeCode(bytes memory args) pure returns (bytes memory runtimecode) {
    uint16 extraDataSize = uint16(args.length) + 2; // 2 extra bytes for the storing the size of the args

    uint8 argsCodeOffset = 0x48; // length of the runtime code

    uint8 returnJumpLocation = argsCodeOffset - 5;

    // @note: uses codecopy, room to optimize by directly encoding immutableArgs into bytecode
    runtimecode = abi.encodePacked(
        /// calldatacopy(0, 0, calldatasize())

        hex"36"                                     // CALLDATASIZE     | cds                       |
        hex"3d"                                     // RETURNDATASIZE   | 00  cds                   |
        hex"3d"                                     // RETURNDATASIZE   | 00  00  cds               |
        hex"37"                                     // CALLDATACOPY     |                           | [0, cds) = calldata

        /// codecopy(calldatasize(), argsCodeOffset, extraDataSize)

        hex"61", extraDataSize,                     // PUSH2 xds        | xds                       | [0, cds) = calldata
        hex"60", argsCodeOffset,                    // PUSH1 aco        | aco xds                   | [0, cds) = calldata
        hex"36"                                     // CALLDATASIZE     | cds aco xds               | [0, cds) = calldata
        hex"39"                                     // CODECOPY         |                           | [0, cds) = calldata, [cds, cds + xds] = args + byte2(argSize)

        /// tcs := add(calldatasize(), extraDataSize)
        hex"3d"                                     // RETURNDATASIZE   | 00                        | [0, cds) = calldata, [cds, cds + xds] = args + byte2(argSize)
        hex"3d"                                     // RETURNDATASIZE   | 00  00                    | [0, cds) = calldata, [cds, cds + xds] = args + byte2(argSize)
        hex"61", extraDataSize,                     // PUSH2 xds        | xds 00  00                | [0, cds) = calldata
        hex"36"                                     // CALLDATASIZE     | cds xds 00  00            | [0, cds) = calldata, [cds, cds + xds] = args + byte2(argSize)
        hex"01"                                     // ADD              | tcs 00  00                | [0, cds) = calldata, [cds, cds + xds] = args + byte2(argSize)

        /// success := delegatecall(gas(), sload(ERC1967_PROXY_STORAGE_SLOT), 0, tcs, 0, 0)

        hex"3d"                                     // RETURNDATASIZE   | 00  tcs 00  00            | [0, cds) = calldata, [cds, cds + xds] = args + byte2(argSize)
        hex"7f", ERC1967_PROXY_STORAGE_SLOT,        // PUSH32 pss       | pss 00  tcs 00 00         | [0, cds) = calldata, [cds, cds + xds] = args + byte2(argSize)
        hex"54"                                     // SLOAD            | pxa 00  tcs 00  00        | [0, cds) = calldata, [cds, cds + xds] = args + byte2(argSize)
        hex"5a"                                     // GAS              | gas pxa 00  tcs 00  00    | [0, cds) = calldata, [cds, cds + xds] = args + byte2(argSize)
        hex"f4"                                     // DELEGATECALL     | scs                       | ...

        /// returndatacopy(0, 0, returndatasize())

        hex"3d"                                     // RETURNDATASIZE   | rds scs                   | ...
        hex"60" hex"00"                             // PUSH1 00         | 00  rds scs               | ...
        hex"80"                                     // DUP1             | 00  00  rds scs           | ...
        hex"3e"                                     // RETURNDATACOPY   | scs                       | [0, rds) = returndata

        /// if success { jump(rtn) }

        hex"60", returnJumpLocation,                // PUSH1 rtn        | rtn scs                   | [0, rds) = returndata
        hex"57"                                     // JUMPI            |                           | [0, rds) = returndata

        /// revert(0, returndatasize())

        hex"3d"                                     // RETURNDATASIZE   | rds                       | [0, rds) = returndata
        hex"60" hex"00"                             // PUSH1 00         | 00  rds                   | [0, rds) = returndata
        hex"fd"                                     // REVERT           |                           | 

        /// return(0, returndatasize())

        hex"5b"                                     // JUMPDEST         |                           | [0, rds) = returndata
        hex"3d"                                     // RETURNDATASIZE   | rds                       | [0, rds) = returndata
        hex"60" hex"00"                             // PUSH1 00         | 00  rds                   | [0, rds) = returndata
        hex"f3",                                    // RETURN           |                           | ...

        // unreachable code: 
        // append args and args length for later use

        args,
        uint16(args.length)

    ); // prettier-ignore

    // sanity check for for jump locations
    if (runtimecode.length != argsCodeOffset + extraDataSize) revert InvalidOffset(argsCodeOffset, runtimecode.length);
}

// ---------------------------------------------------------------------
// Snippets
// ---------------------------------------------------------------------

/// @notice expects call `success` (scs) bool to be on top of stack
function REVERT_ON_FAILURE(uint256 pc) pure returns (bytes memory code) {
    // upper bound for when end location requires 32 bytes
    uint256 pushNumBytes = utils.getRequiredBytes(pc + 38);
    uint256 end = pc + pushNumBytes + 11;

    code = abi.encodePacked(
        /// if success { jump(end) }

        PUSHX(end, pushNumBytes),                   // PUSH1 end        | end scs 
        hex"57"                                     // JUMPI            |         

        /// returndatacopy(0, 0, returndatasize())

        hex"3d"                                     // RETURNDATASIZE   | rds                       | ...
        hex"60" hex"00"                             // PUSH1 00         | 00  rds                   | ...
        hex"80"                                     // DUP1             | 00  00  rds               | ...
        hex"3e"                                     // RETURNDATACOPY   |                           | [0, rds) = returndata

        /// revert(0, returndatasize())

        hex"3d"                                     // RETURNDATASIZE   | rds    
        hex"60" hex"00"                             // PUSH1 00         | 00  rds
        hex"fd"                                     // REVERT           |        

        hex"5b"                                     // JUMPDEST         | 
    );
}

/// @notice expects call `success` (scs) bool to be on top of stack
/// @notice using this for testing
// apparently you can't revert any returndata 
// messages when using CREATE (returndatasize() is always 0)
// that's why I'm encoding it in the returndata
function RETURN_REVERT_REASON_ON_FAILURE_TEST(uint256 pc) pure returns (bytes memory code) {
    // upper bound for when end location requires 32 bytes
    uint256 pushNumBytes = utils.getRequiredBytes(pc + 38);
    // uint256 end = pc + pushNumBytes + 51;
    uint256 end = pc + pushNumBytes + 19;

    code = abi.encodePacked(
        /// if success { jump(end) }

        PUSHX(end, pushNumBytes),                   // PUSH1 end        | end scs 
        hex"57"                                     // JUMPI            |         

        /// mstore(0, 0)

        hex"60" hex"00"
        hex"80" 
        hex"52"


        /// returndatacopy(1, 0, returndatasize())

        hex"3d"                                     // RETURNDATASIZE   | rds                       | ...
        hex"60" hex"00"                             // PUSH1 00         | 00  rds                   | ...
        hex"60" hex"01"                             // PUSH1 01         | 01  00  rds               | ...
        hex"3e"                                     // RETURNDATACOPY   |                           | [0] = wtf (identifier for reverting call)


        /// return(0, 1 + returndatasize())

        hex"3d"                                     // RETURNDATASIZE   | rds                       | [0, rds + 20) = encoded returndata
        hex"60" hex"01"                             // PUSH1 01         | 01  rds                   | [0, rds + 20) = encoded returndata
        hex"01"                                     // ADD              | eds                       | [0, rds + 20) = encoded returndata
        hex"60" hex"00"                             // PUSH1 00         | 00  eds
        hex"f3"                                     // RETURN           |        

        hex"5b"                                     // JUMPDEST         | 
    );
}


/// @notice Crude mstore that copies bytes to memory offset in chunks of 32
function MSTORE(uint256 offset, bytes memory data) pure returns (bytes memory code) {

    bytes32[] memory bytes32Data = utils.splitToBytes32(data);

    uint256 numChunks = bytes32Data.length;

    for (uint256 i; i < numChunks; i++) {
        code = abi.encodePacked(
            code,
            hex"7f", bytes32Data[i],
            PUSHX(offset + i * 32),
            hex"52"
        ); // prettier-ignore
    }
}

function PUSHX(uint256 value) pure returns (bytes memory code) {
    return PUSHX(value, utils.getRequiredBytes(value));
}

function PUSHX(uint256 value, uint256 numBytes) pure returns (bytes memory code) {
    if (numBytes == 1) code = abi.encodePacked(hex"60", uint8(value));
    else if (numBytes == 2) code = abi.encodePacked(hex"61", uint16(value));
    else if (numBytes == 3) code = abi.encodePacked(hex"62", uint24(value));
    else if (numBytes == 4) code = abi.encodePacked(hex"63", uint32(value));
    else if (numBytes == 5) code = abi.encodePacked(hex"64", uint40(value));
    else if (numBytes == 6) code = abi.encodePacked(hex"65", uint48(value));
    else if (numBytes == 7) code = abi.encodePacked(hex"66", uint56(value));
    else if (numBytes == 8) code = abi.encodePacked(hex"67", uint64(value));
    else if (numBytes == 9) code = abi.encodePacked(hex"68", uint72(value));
    else if (numBytes == 10) code = abi.encodePacked(hex"69", uint80(value));
    else if (numBytes == 11) code = abi.encodePacked(hex"6a", uint88(value));
    else if (numBytes == 12) code = abi.encodePacked(hex"6b", uint96(value));
    else if (numBytes == 13) code = abi.encodePacked(hex"6c", uint104(value));
    else if (numBytes == 14) code = abi.encodePacked(hex"6d", uint112(value));
    else if (numBytes == 15) code = abi.encodePacked(hex"6e", uint120(value));
    else if (numBytes == 16) code = abi.encodePacked(hex"6f", uint128(value));
    else if (numBytes == 17) code = abi.encodePacked(hex"70", uint136(value));
    else if (numBytes == 18) code = abi.encodePacked(hex"71", uint144(value));
    else if (numBytes == 19) code = abi.encodePacked(hex"72", uint152(value));
    else if (numBytes == 20) code = abi.encodePacked(hex"73", uint160(value));
    else if (numBytes == 21) code = abi.encodePacked(hex"74", uint168(value));
    else if (numBytes == 22) code = abi.encodePacked(hex"75", uint176(value));
    else if (numBytes == 23) code = abi.encodePacked(hex"76", uint184(value));
    else if (numBytes == 24) code = abi.encodePacked(hex"77", uint192(value));
    else if (numBytes == 25) code = abi.encodePacked(hex"78", uint200(value));
    else if (numBytes == 26) code = abi.encodePacked(hex"79", uint208(value));
    else if (numBytes == 27) code = abi.encodePacked(hex"7a", uint216(value));
    else if (numBytes == 28) code = abi.encodePacked(hex"7b", uint224(value));
    else if (numBytes == 29) code = abi.encodePacked(hex"7c", uint232(value));
    else if (numBytes == 30) code = abi.encodePacked(hex"7d", uint240(value));
    else if (numBytes == 31) code = abi.encodePacked(hex"7e", uint248(value));
    else if (numBytes == 32) code = abi.encodePacked(hex"7f", uint256(value));
}
