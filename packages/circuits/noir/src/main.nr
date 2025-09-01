use poseidon::poseidon::bn254::{hash_1, hash_2};

global LEVELS: u32 = 20;

fn hasher(input: [Field; 2], s: Field) -> Field {
    assert(s * (s - 1) == 0);

    let left: Field = (input[1] - input[0]) * s + input[0];
    let right: Field = (input[0] - input[1]) * s + input[1];
    hash_2([left, right])
}

fn merkleTreeChecker(leaf: Field, root: Field, pathElements: [Field; LEVELS], pathIndices: [Field; LEVELS]) {
    let mut hash: Field = leaf;
    for i in 0..LEVELS {
        hash = hasher([hash, pathElements[i]], pathIndices[i]);
    }

    assert(root == hash);
}

// returns [commitment, nullifierHash]
fn commitmentHasher(nullifier: Field, secret: Field) -> [Field; 2] {
    [hash_2([nullifier, secret]), hash_1([nullifier])]
}

fn main(
    root: pub Field,
    nullifierHash: pub Field,
    recipient: pub Field,
    relayer: pub Field,
    fee: pub Field,
    refund: pub Field,
    nullifier: Field,
    secret: Field,
    pathElements: [Field; LEVELS],
    pathIndices: [Field; LEVELS],
    recipientSquare: Field,
    relayerSquare: Field,
    feeSquare: Field,
    refundSquare: Field
) {
    let hashes: [Field; 2] = commitmentHasher(nullifier, secret);
    assert(nullifierHash == hashes[1]);

    merkleTreeChecker(hashes[0], root, pathElements, pathIndices);

    assert(recipientSquare == recipient * recipient);
    assert(relayerSquare == relayer * relayer);
    assert(feeSquare == fee * fee);
    assert(refundSquare == refund * refund);
}

#[test]
fn test_main() {
    let root: Field = 0x295e353dd85505e4baa325b7cbcede2aeec5b139d7a5f5abac6c05ddcd90b941;
    let nullifier: Field = 0x289abe422e90fc3e926b44f8d0b3d683807af528507cc888913e151fdc7092f9;
    let nullifierHash: Field = 0x1763a0f3c1376f8d25af6f77286ae9fbd9e993f5ecf365450cfbc7bfde457aa5;
    let recipient: Field = 0xFaB1e0F009A77a60dc551c2e768DFb3fadc40827;
    let relayer: Field = 0;
    let fee: Field = 0;
    let refund: Field = 0;
    let secret: Field = 0x104debb905460ce8540b46a82d986a9da9e9cfcb1ac2e06a16814a1d26ef1c10;
    let pathElements: [Field; LEVELS] = [
        0x2fe54c60d3acabf3343a35b6eba15db4821b340f76e741e2249685ed4899af6c,
        0x256a6135777eee2fd26f54b8b7037a25439d5235caee224154186d2b8a52e31d,
        0x1151949895e82ab19924de92c40a3d6f7bcb60d92b00504b8199613683f0c200,
        0x20121ee811489ff8d61f09fb89e313f14959a0f28bb428a20dba6b0b068b3bdb,
        0x0a89ca6ffa14cc462cfedb842c30ed221a50a3d6bf022a6a57dc82ab24c157c9,
        0x24ca05c2b5cd42e890d6be94c68d0689f4f21c9cec9c0f13fe41d566dfb54959,
        0x1ccb97c932565a92c60156bdba2d08f3bf1377464e025cee765679e604a7315c,
        0x19156fbd7d1a8bf5cba8909367de1b624534ebab4f0f79e003bccdd1b182bdb4,
        0x261af8c1f0912e465744641409f622d466c3920ac6e5ff37e36604cb11dfff80,
        0x0058459724ff6ca5a1652fcbc3e82b93895cf08e975b19beab3f54c217d1c007,
        0x1f04ef20dee48d39984d8eabe768a70eafa6310ad20849d4573c3c40c2ad1e30,
        0x1bea3dec5dab51567ce7e200a30f7ba6d4276aeaa53e2686f962a46c66d511e5,
        0x0ee0f941e2da4b9e31c3ca97a40d8fa9ce68d97c084177071b3cb46cd3372f0f,
        0x1ca9503e8935884501bbaf20be14eb4c46b89772c97b96e3b2ebf3a36a948bbd,
        0x133a80e30697cd55d8f7d4b0965b7be24057ba5dc3da898ee2187232446cb108,
        0x13e6d8fc88839ed76e182c2a779af5b2c0da9dd18c90427a644f7e148a6253b6,
        0x1eb16b057a477f4bc8f572ea6bee39561098f78f15bfb3699dcbb7bd8db61854,
        0x0da2cb16a1ceaabf1c16b838f7a9e3f2a3a3088d9e0a6debaa748114620696ea,
        0x24a3b3d822420b14b5d8cb6c28a574f01e98ea9e940551d2ebd75cee12649f9d,
        0x198622acbd783d1b0d9064105b1fc8e4d8889de95c4c519b3f635809fe6afc05
    ];
    let pathIndices: [Field; LEVELS] = [
        0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0
    ];
    let recipientSquare: Field = 0x2a0cd81fe95ea12e6dbb85efa7268e9a73b31f1947063f2af0cb3ae4621bc4e6;
    let relayerSquare: Field = 0;
    let feeSquare: Field = 0;
    let refundSquare: Field = 0;
    main(
        root,
        nullifierHash,
        recipient,
        relayer,
        fee,
        refund,
        nullifier,
        secret,
        pathElements,
        pathIndices,
        recipientSquare,
        relayerSquare,
        feeSquare,
        refundSquare
    );
}
