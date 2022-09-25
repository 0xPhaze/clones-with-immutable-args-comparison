# Clones With Immutable Args Comparisons

Comparing three methods:
1. Append immutable args to calldata for every call
2. Read immutable args from contract code via `extcodecopy`
3. Read immutable args via `codecopy` by calling back into `address()` via `call`

Results from 3. are left out in the graph, because it performed similarly, but worse than 2.

![results](https://user-images.githubusercontent.com/103113487/192160413-6617580f-8348-46a3-9aee-7554934628fb.png)

```
forge snapshot --mt testGas
```
