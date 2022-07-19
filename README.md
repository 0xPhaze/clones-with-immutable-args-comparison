# Proxies With Immutable Args

This library is for deploying ERC1967 proxies usable with (UUPSUpgrade.sol)
that contain "immutable args".
This means that, before an upgrade is performed,
- implementation code length is checked
- implementation uuid is verified
- `Upgraded` event is emitted
- implementation address is stored in storage slot keccak256("eip1967.proxy.implementation") - 1 as per ERC1967
- a delegatecall is performed on the implementation contract upon proxy initialization if `initCalldata.length != 0`

For any delegatecall (initialization or proxy call), some "immutable args" are appended to
the calldata. This appended calldata does generally not influence the control flow of 
contracts and can be seen as optional calldata. 
Contracts that are not aware of this extra calldata should not be perturbed by this.
The extra immutable data is appended to calls, along with 2 extra bytes that signal
the length of the immutable data.

Currently there is no validation to whether this extra calldata is actually present
and trying to read immutable args in a proxy that doesn't append any, would lead to errors
or incorrect data being read!

For a more user-friendly library and to see some examples of how these are meant to be used,
see [UDS](https://github.com/0xPhaze/UDS).

## WIP (Work in Progress)
This work is mostly for fun and for better understanding the evm.
My goal is to create multiple different versions and test their deployment costs 
and extra calldata cost. A next version for comparison could, for example only read immutable args
through codecopy, instead of appending these to calldata.

Further todos:
- expand test cases for bytecode created proxy
- clean up code
- go play some golf

## Disclaimer

These contracts are a work in progress and should not be used in production. Use at your own risk.
The test cases are meant to nail down any possible scenario to ensure proper functioning.
Though some cases are still lacking (for example reaching the limit on extra data).

Using proxies with fixed bytes32 args is relatively safe,
as the code is simple (see [reference implementation](./reference/ERC1967ProxyWithImmutableArgs)).

There be dragons, however, for the proxy deployed by hand-crafted bytecode.
I would not trust this for any arg code lengths until further testing.


Install with [Foundry](https://github.com/foundry-rs/foundry)
```sh
forge install 0xPhaze/proxies-with-immutable-args
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

## Acknowledgements
- [ClonesWithImmutableArgs](https://github.com/wighawag/clones-with-immutable-args)