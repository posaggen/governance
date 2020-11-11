const {Conflux} = require('js-conflux-sdk');
const cfx = new Conflux({
  url: 'http://test.confluxrpc.org',
  //url: 'http://main.confluxrpc.org',
});
const BigNumber = require('bignumber.js');
const fs = require('fs');
const program = require('commander');

let gov_contract = JSON.parse(
  fs.readFileSync(__dirname + '/../build/contracts/Governance.json'),
);

let staking_contract = JSON.parse(
  fs.readFileSync(__dirname + '/../build/contracts/Staking.json'),
);

let staking = cfx.Contract({
  abi: staking_contract.abi,
  address: '0x0888000000000000000000000000000000000002',
});

let owner;
let owner_addr;
let price = '1';
let gov_addr = '0x8d29d9c6e31434a93bb8d004f70d965250f4cad4';
let gov;
if (gov_addr !== '') {
  gov = cfx.Contract({
    abi: gov_contract.abi,
    address: gov_addr,
  });
}

async function deploy() {
  let nonce = Number(await cfx.getNextNonce(owner_addr));
  let tmp = cfx.Contract({
    abi: gov_contract.abi,
    bytecode: gov_contract.bytecode,
  });
  console.log(`deploying gov..`);
  let receipt = await tmp
    .constructor()
    .sendTransaction({
      from: owner,
      gas: 10000000,
      nonce: nonce,
      gasPrice: price,
    })
    .executed();
  if (receipt.outcomeStatus !== 0) throw new Error('deploy failed!');
  let fc_addr = receipt.contractCreated;
  console.log(`gov_addr: ${fc_addr}`);
  ++nonce;
  console.log(`success.`);
}

async function stake() {
  let nonce = Number(await cfx.getNextNonce(owner_addr));
  console.log(`stake..`);
  let receipt = await staking
    .deposit('1000000000000000000')
    .sendTransaction({
      from: owner,
      nonce: nonce,
      gasPrice: price,
    })
    .executed();
  if (receipt.outcomeStatus !== 0) throw new Error('deposit failed!');
  ++nonce;
  console.log('lock..');
  receipt = await staking
    .voteLock('1000000000000000000', '100000000000000')
    .sendTransaction({
      from: owner,
      nonce: nonce,
      gasPrice: price,
    })
    .executed();
  if (receipt.outcomeStatus !== 0) throw new Error('lock failed!');
  ++nonce;
  console.log(`success.`);
}

async function test() {
  let nonce = Number(await cfx.getNextNonce(owner_addr));
  let block_number = Number(await gov.getBlockNumber().call());
  let p = [];
  for (let i = 0; i < 25; ++i) {
    let title = `proposal test #${i}`;
    let discussion = `proposal test #${i}'s discussion`;
    let options = [];
    let n = (i % 3) + 2;
    for (let j = 0; j < n; ++j) {
      options.push(`proposal test #${i}'s option #${j}`);
    }
    let deadline = Number(block_number + 600);
    if (i % 3 === 0) {
      deadline = Number(block_number + 1000000);
    }
    p.push(
      gov
        .submitProposalByWhitelist(
          title,
          discussion,
          deadline,
          options,
          owner.address,
        )
        .sendTransaction({
          from: owner,
          nonce: nonce,
          gasPrice: price,
          gas: 1000000,
          storageLimit: 10000,
        })
        .executed(),
    );
    ++nonce;
    p.push(
      gov
        .vote(i, i % n)
        .sendTransaction({
          from: owner,
          nonce: nonce,
          gasPrice: price,
          gas: 1000000,
          storageLimit: 10000,
        })
        .executed(),
    );
    ++nonce;
  }
  await Promise.all(p);
}

async function vote() {
  let nonce = Number(await cfx.getNextNonce(owner_addr));
  let receipt = await gov
    .vote(0, 1)
    .sendTransaction({
      from: owner,
      nonce: nonce,
      gasPrice: price,
    })
    .executed();
  if (receipt.outcomeStatus !== 0) throw new Error('vote failed!');
  ++nonce;
}

async function printBlockNumber() {
  console.log(String(await gov.getBlockNumber().call()));
}

function print(p) {
  console.log(p[0]);
  console.log(p[1]);
  console.log(String(p[2]));
  console.log(p[3]);
  console.log(p[4].map((x) => String(x)));
  console.log(p[5]);
  console.log("");
}

async function getProposals(offset, cnt) {
  console.log(String(await gov.proposalCount().call()));
  console.log(String(await gov.getBlockNumber().call()));
  let p = await gov.getProposalList(offset, cnt).call();
  console.log(p.length);
  for (let i = 0; i < p.length; ++i) {
    print(p[i]);
  }
}

async function getVoteForProposal(id) {
  console.log(await gov.getVoteForProposal(id, owner.address).call());
}

program
  .option('-g, --gov', 'deploy gov')
  .option('-s, --stake', 'stake')
  .option('-p, --privatekey [type]', 'private key of owner')
  .option('-t, --test', 'test')
  .option('-v, --vote', 'vote')
  .parse(process.argv);

if (program.privatekey !== undefined) {
  let key = program.privatekey;
  if (!key.startsWith('0x')) key = `0x${key}`;
  owner = cfx.Account(key);
  owner_addr = owner.address;
} else {
  console.log('error: private key is empty!');
  process.exit(1);
}

if (program.gov !== undefined) {
  deploy();
} else if (program.stake !== undefined) {
  stake();
} else if (program.test !== undefined) {
  test();
} else if (program.vote !== undefined) {
  vote();
}

//printBlockNumber();
getProposals(20, 10);
//getVoteForProposal(0);
