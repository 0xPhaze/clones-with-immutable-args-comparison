# Proxies With Immutable Args

This is a library for deploying ERC1967 proxies (usable with UUPSUpgrade.sol)
that contain "immutable args".

## Installation

Install with [Foundry](https://github.com/foundry-rs/foundry)
```sh
forge install 0xPhaze/proxies-with-immutable-args
```

## Deploying a proxy with immutable args

To create and deploy the implementation contract, 
it needs to inherit from {{UUPSUpgrade}}.
The `_authorizeUpgrade` function needs to be protected.
For that I am using {{UDS/auth/OwnableUDS.sol}}, which
can be installed using
```sh
forge install 0xPhaze/UDS
```

```sol
import {UUPSUpgrade} from "/UUPSUpgrade.sol";

import {OwnableUDS} from "UDS/auth/OwnableUDS.sol";
import {InitializableUDS} from "UDS/auth/InitializableUDS.sol";

contract Logic is UUPSUpgrade, InitializableUDS, OwnableUDS {
    function init() public initializer {
        __Ownable_init();
    }

    function _authorizeUpgrade() internal override onlyOwner {}
}
```

To deploy a proxy, call `LibERC1967ProxyWithImmutableArgs.deployProxyWithImmutableArgs`.
This returns an address, which can be casted to the appropriate type.

```sol
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



## Contracts

```ml
src
├── ERC1967Proxy.sol - "ERC1967 proxy implementation"
├── LibERC1967ProxyWithImmutableArgs.sol - "Library for deploying ERC1967 proxy implementation with immutable args"
├── ProxyCreationCode.sol - "Contains helper functions for proxy bytecode creation"
├── UUPSUpgrade.sol - "Minimal UUPS upgradeable contract"
├── reference
│   └── ERC1967ProxyWithImmutableArgs.sol - "Reference implementation for proxies with fixed immutable arg lengths"
└── utils
    └── utils.sol - "low-level utils"
```

## ERC1967 Specs

During upgrade & initialization (see [implementation reference](./src/ERC1967Proxy.sol)):
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

Currently there is no validation to whether this extra calldata is actually present
when trying to read immutable args from calldata. 
Attempting to read these from a proxy that doesn't append any, would lead to errors
or incorrect data being returned!

For a more user-friendly library and to see some examples of how these are meant to be used,
see [UDS](https://github.com/0xPhaze/UDS).

## WIP (Work in Progress)

This work is mostly for fun and for better understanding the EVM.
The goal is to create multiple different versions and test their deployment costs 
and extra calldata costs for delegatecalls. A next version for comparison could, for example only read immutable args
through codecopy, instead of appending these to calldata.

Further todos:
- expand test cases for bytecode created proxy
- clean up code
- go play some golf

## Disclaimer

These contracts are a work in progress and should not be used in production. Use at your own risk.
The test cases are meant to pin down proper specification.
Though some can be extended (for example reaching the limit on extra data).

Using proxies with fixed bytes32 args is relatively safe,
as the code is simple (see [reference implementation](./src/reference/ERC1967ProxyWithImmutableArgs.sol)).

There be dragons, however, for the proxy deployed by [hand-crafted bytecode](./src/ProxyCreationCode.sol).
I would not trust this for any arg code lengths until further testing has been done.


## Acknowledgements
- [ClonesWithImmutableArgs](https://github.com/wighawag/clones-with-immutable-args)
- [Foundry](https://github.com/foundry-rs/foundry)