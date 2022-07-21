# Proxies With Immutable Args

This is a library for deploying ERC1967 proxies (usable with UUPSUpgrade)
that contain "immutable args".

## Contracts

```ml
src
├── ERC1967Proxy.sol - "ERC1967 proxy implementation"
├── LibERC1967ProxyWithImmutableArgs.sol - "Library for deploying ERC1967 proxy implementation with immutable args"
├── UUPSUpgrade.sol - "Minimal UUPS upgradeable contract"
└── utils
    ├── proxyCreationCode.sol - "Contains helper functions for proxy bytecode creation"
    └── utils.sol - "low-level utils"
```

## Installation

Install with [Foundry](https://github.com/foundry-rs/foundry)
```sh
forge install 0xPhaze/proxies-with-immutable-args
```

## Deploying a proxy with immutable args

### Implementation

The implementation contract, needs inherit from [UUPSUpgrade](./src/UUPSUpgrade.sol).
The `_authorizeUpgrade` function must be overriden (and protected).

```solidity
import {OwnableUDS} from "UDS/auth/OwnableUDS.sol";
import {InitializableUDS} from "UDS/auth/InitializableUDS.sol";

import {UUPSUpgrade} from "/UUPSUpgrade.sol";

contract Logic is UUPSUpgrade, InitializableUDS, OwnableUDS {
    function init() public initializer {
        __Ownable_init();
    }

    function _authorizeUpgrade() internal override onlyOwner {}
}
```

The example uses [OwnableUDS](https://github.com/0xPhaze/UDS/blob/master/src/auth/OwnableUDS.sol) and [InitializableUDS](https://github.com/0xPhaze/UDS/blob/master/src/auth/InitializableUDS.sol).
These can be installed via
```sh
forge install 0xPhaze/UDS
```
For more info on upgradeable proxies, have a look at [UDS](https://github.com/0xPhaze/UDS).

### Proxy

To deploy a proxy, call `LibERC1967ProxyWithImmutableArgs.deployProxyWithImmutableArgs`. This can be done directly through [Solidity Scripting](https://book.getfoundry.sh/tutorials/solidity-scripting) using Foundry,
a `ProxyFactory` contract, or by simply sending the creation code from some account
as a transaction.
The returned address can be casted to the appropriate contract type of the implementation.

```solidity
import {LibERC1967ProxyWithImmutableArgs} from "/LibERC1967ProxyWithImmutableArgs.sol";

contract ProxyFactory {
    function deployProxy(
        address implementation, 
        bytes memory initCalldata, 
        bytes memory immutableArgs
    ) public returns (address) {
        return LibERC1967ProxyWithImmutableArgs.deployProxyWithImmutableArgs(
            implementation,
            initCalldata,
            immutableArgs
        )
    }
}
```

### Packing and Reading Args

`immutableArgs` can contain tightly packed arguments.

```solidity
address addr = address(0x1337);
uint40 timestamp = 12345;
bytes memory immutableArgs = abi.encodePacked(addr, timestamp);
```

`LibERC1967ProxyWithImmutableArgs` contains helper functions for reading out immutable args.
The offset argument is the bytes position in the tightly packed bytes array.

```solidity
contract Logic is UUPSUpgrade {
    ...

    function testReadArgs() public {
        address addr = LibERC1967ProxyWithImmutableArgs.getArgAddress(0);
        uint40 timestamp = LibERC1967ProxyWithImmutableArgs.getArgUint40(20);

        ...
    }
}
```

Currently there is no validation for whether this extra calldata is actually present
when trying to read immutable args from calldata. 
Attempting to read these from a proxy that doesn't append any, would lead to errors
or incorrect data being returned!


## ERC1967 Specs

During upgrade & initialization (see [ERC1967Proxy](./src/ERC1967Proxy.sol)):
- implementation code length is checked
- implementation uuid is verified
- `Upgraded` event is emitted
- implementation address is stored in storage slot keccak256("eip1967.proxy.implementation") - 1 as per ERC1967
- a delegatecall is performed on the implementation contract upon proxy initialization if `initCalldata.length != 0`
- call is reverted if not successful and reason is bubbled up

## Immutable Args Specs

For any delegatecall (initialization or proxy call), the "immutable args" are appended to
the calldata, along with 2 extra bytes that signal the length of the immutable data. 
This extra calldata generally (unless they explicitly read calldata) does not interfere with the usual control flow of 
contracts and can be seen as optional calldata/arguments. 

There is no validation for whether this extra calldata is actually present.

## WIP (Work in Progress)

This work is mostly for fun and for better understanding the EVM.
The goal is to create multiple different versions and test their deployment costs 
and extra calldata costs for delegatecalls. 
A different version could, for example only read immutable args
through extcodecopy, instead of appending these to calldata.

Further todos:
- expand test cases
- clean up code
- go play some golf

## Disclaimer

These contracts are a work in progress and should not be used in production. Use at your own risk.
The test cases are meant to pin down proper specification.
Deploying very large immutable args has not been extensively tested 
(though the fuzzer didn't complain so far) and might increase gas costs to every when interacting with the proxy in general.

## Acknowledgements
- [ClonesWithImmutableArgs](https://github.com/wighawag/clones-with-immutable-args)
- [Foundry](https://github.com/foundry-rs/foundry)