# NFT Mints [![Github Actions][gha-badge]][gha] [![Foundry][foundry-badge]][foundry] [![codecov](https://codecov.io/github/PartyDAO/nft-mints/graph/badge.svg?token=4N8NBEBM91)](https://codecov.io/github/PartyDAO/nft-mints)

[gha]: https://github.com/PartyDAO/nft-mints/actions
[gha-badge]: https://github.com/PartyDAO/nft-mints/actions/workflows/ci.yml/badge.svg
[foundry]: https://getfoundry.sh/
[foundry-badge]: https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg

Create ERC1155 Mints. Creators can call the `createMint` function on the `NFTMint` contract. They pass an array of
editions with attributes and an assigned percent chance. Buyers can `order` mints and specify a number they wish to buy.
A trusted party calls the `fillOrders` which fills pending orders. This is required to ensure safe randomness is
achieved.

After the mint, creators maintain control over the ERC1155 contract and can set the name, image, description, and
royalty info freely.

Important Note: When filling orders, if the safe transfer of the ERC1155 fails, the order is marked as complete--the
buyer does not receive the NFT or a refund. We check if a buyer can receive ERC1155s in the order function but this is
not foolproof.

## Usage

This is a list of the most frequently needed commands.

### Build

Build the contracts:

```sh
$ forge build
```

### Clean

Delete the build artifacts and cache directories:

```sh
$ forge clean
```

### Compile

Compile the contracts:

```sh
$ forge build
```

### Coverage

Get a test coverage report:

```sh
$ forge coverage
```

### Deploy

Deploy to Anvil:

```sh
$ forge script script/Deploy.s.sol --broadcast --fork-url http://localhost:8545
```

For this script to work, you need to have a `MNEMONIC` environment variable set to a valid
[BIP39 mnemonic](https://iancoleman.io/bip39/).

For instructions on how to deploy to a testnet or mainnet, check out the
[Solidity Scripting](https://book.getfoundry.sh/tutorials/solidity-scripting.html) tutorial.

### Format

Format the contracts:

```sh
$ forge fmt
```

### Gas Usage

Get a gas report:

```sh
$ forge test --gas-report
```

### Lint

Lint the contracts:

```sh
$ bun run lint
```

### Test

Run the tests:

```sh
$ forge test
```

Generate test coverage and output result to the terminal:

```sh
$ bun run test:coverage
```

Generate test coverage with lcov report (you'll have to open the `./coverage/index.html` file in your browser, to do so
simply copy paste the path):

```sh
$ bun run test:coverage:report
```

## Related Efforts

- [abigger87/femplate](https://github.com/abigger87/femplate)
- [cleanunicorn/ethereum-smartcontract-template](https://github.com/cleanunicorn/ethereum-smartcontract-template)
- [foundry-rs/forge-template](https://github.com/foundry-rs/forge-template)
- [FrankieIsLost/forge-template](https://github.com/FrankieIsLost/forge-template)

## License

This project is licensed under MIT.
