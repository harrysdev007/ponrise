# PONRISE

Funded token launch interface on Robinhood Chain, integrating Pons V2. Independent project; not affiliated with Pons or Robinhood.

## Local development

Node 22+. Run `npm ci`, then `npm run dev -- --port 5183`. Build with `npm run build`; compile contracts with `npm run compile`; run `npm test`.

## Implemented

- Privy browser-wallet connection restricted to Robinhood Chain (4663). The creation form is mounted only after wallet connection and switching to the correct network.
- Identity → Economics wizard, project socials, permanent image URLs, optional signed image upload through server-side Pinata.
- Native ETH, approved stock-token/ETF, stablecoin and crypto quote assets. Pair candidates are sourced from Pons's public token list and filtered by live factory approval/economics. Economics and decimals are rechecked before preparing a transaction.
- Economics pin, random CREATE2 salt, 10-minute request deadline, slippage protection and exact funding. No arbitrary custom starting valuation: protocol configurations define opening economics.
- Atomic Pons launch-and-buy, native or exact-approved ERC-20 funding, refund forwarding, 30–730 day vesting of the opening-purchased tokens. No team premint is removed from Pons's curve supply.
- Optional Pons buybacks and up to 32 opening-tax exemption addresses, disclosed in the wizard.
- Per-quote revenue splitter: 50% holder pool, 30% trader pool, 10% original creator, 10% treasury, applied only to actual net creator revenue received from Pons escrow. Protocol deductions and optional buybacks happen first.
- Separate quote-asset reward pools, immutable funded Merkle epochs, wallet-bound proofs and claims. Eligibility is manually reviewed and selected by the immutable operator; no automatic dividend or wash-trading detection is claimed.
- Launch passports, purchase vesting claims, creator credits, protocol escrow collection, reward funding, buyback management and release of vested buyback tokens.
- Pons token inspection and pre-graduation buy/sell flows, quote decimals, current opening tax and exact-amount approvals. Graduated Uniswap V4 pool routing is not implemented.

## What remains before production

Custom contracts are compiled and locally tested but are not deployed or audited. Local mock tests are not a mainnet audit or a completed end-to-end Pons mainnet launch. No mainnet transactions have been submitted by this project.

Use Platform setup to deploy the coordinator from a wallet after reviewing the contracts, immutable treasury/operator settings and funding policy. Publish the downloaded configuration as `public/deployment.json`. Until then the coordinator registry and rewards are empty and funded launch submission is unavailable. Pons gates/configs can change; all writes simulate and check current settings.

The coordinator is recorded as the initiating account by Pons. The original creator is recorded in our launch passport and is the beneficiary of purchased tokens and creator income. Pons creator fees go to the per-launch splitter. Pons itself retains its protocol controls, fee policies and takeover mechanisms.

Buyback token releases belong to the original creator and are separate from quote-asset revenue distributions. Pons curve/pool fees must be swept before escrow collection; internal swaps may require the Pons operator. A zero escrow balance does not imply zero unswept fees.

The native opening minimum and duplicate ticker bond are configured at deployment. ERC-20 opening minimum is 1% of that asset's current graduation threshold. Duplicate ticker protection applies only to this coordinator; its bond is refundable after seven days. Token names/tickers are not globally unique.

## Image storage

Copy `.env.example` to `.env` and set server-only `PINATA_JWT` to enable uploads. Never use a `VITE_` prefix. Without it, permanent HTTPS/IPFS image URLs work, and upload requests return an explicit configuration error. Uploads require an expiring wallet signature bound to the image digest, enforce format/size limits and have an in-memory per-wallet rate cap. For public high-traffic hosting replace rate/replay storage with durable shared storage. Configure the public Privy App ID/origin in the Privy dashboard for the final domain.

Vercel can serve `api/upload.mjs`; `vercel.json` preserves SPA routes. The Vite dev server provides the same upload route locally. Other static hosts need a separately hosted upload function or image-URL-only use.

## Reward allocation files

`node scripts/build-rewards.mjs allocations.json output-directory`

Input example: `{ "chainId": 4663, "contract": "0xREWARD_POOL", "epoch": 0, "decimals": 6, "allocations": [{ "account": "0xWALLET", "amount": "1.5" }] }`.

Use the actual reward pool's immutable asset and decimals. Upload the reviewed allocation and rules to IPFS, fund the pool, then publish the generated root and budget from the operator wallet. Native ETH uses 18 decimals. Published epochs cannot be cancelled or swept.

## Protocol references

- Pons V2: https://docs.ponsfamily.com/v2
- Reference creation flow and pair metadata: https://ponsfamily.com/launchpad/create
- Robinhood Chain: https://docs.robinhood.com/chain/connecting/
- Factory: 0x7eD598BcEf8bd9Edd8C97A195C6d13f40801EC7e
- Launch-and-buy router: 0xe33E9E479dF8802cb0866d5d05258bEc4cF62948
- Fee escrow: 0xd3AFEB2a57f70eF218Aa82451c51B2fb0416Ac9e
- Buyback vault: 0x42df2a798f82289E177311362e8f5ccC45c1219c

PONRISE logo and header are in `brand/`. Ethereum icon source: https://ethereum.org/assets/ (official diamond glyph), rendered in white for contrast. X: https://x.com/ponrise_rh. Intended domain: ponrise.fun.
