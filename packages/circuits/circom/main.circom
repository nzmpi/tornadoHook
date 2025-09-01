pragma circom 2.2.2;

include "../../../node_modules/circomlib/circuits/poseidon.circom";

template Hasher() {
    signal input in[2];
    signal input s;
    signal output hash;

    s * (1 - s) === 0;
    var left = (in[1] - in[0]) * s + in[0];
    var right = (in[0] - in[1]) * s + in[1];

    component nodeHasher = Poseidon(2);
    nodeHasher.inputs <== [left, right];
    hash <== nodeHasher.out;
}

template MerkleTreeChecker(levels) {
    signal input leaf;
    signal input root;
    signal input pathElements[levels];
    signal input pathIndices[levels];

    component hashers[levels];
    hashers[0] = Hasher();
    hashers[0].in[0] <== leaf;
    hashers[0].in[1] <== pathElements[0];
    hashers[0].s <== pathIndices[0];

    for (var i = 1; i < levels; i++) {
        hashers[i] = Hasher();
        hashers[i].in[0] <== hashers[i - 1].hash;
        hashers[i].in[1] <== pathElements[i];
        hashers[i].s <== pathIndices[i];
    }

    root === hashers[levels - 1].hash;
}

// commitment = Poseidon(nullifier | secret)
template CommitmentHasher() {
    signal input nullifier;
    signal input secret;
    signal output commitment;
    signal output nullifierHash;

    component commitmentHasher = Poseidon(2);
    component nullifierHasher = Poseidon(1);
    
    commitmentHasher.inputs <== [nullifier, secret];
    nullifierHasher.inputs <== [nullifier];

    commitment <== commitmentHasher.out;
    nullifierHash <== nullifierHasher.out;
}

template Withdraw(levels) {
    signal input root;
    signal input nullifierHash;
    signal input recipient;
    signal input relayer;
    signal input fee;  
    signal input refund;
    signal input nullifier;
    signal input secret;
    signal input pathElements[levels];
    signal input pathIndices[levels];
    signal input recipientSquare;
    signal input relayerSquare;
    signal input feeSquare;
    signal input refundSquare;

    component hasher = CommitmentHasher();
    hasher.nullifier <== nullifier;
    hasher.secret <== secret;
    hasher.nullifierHash === nullifierHash;

    component tree = MerkleTreeChecker(levels);
    tree.leaf <== hasher.commitment;
    tree.root <== root;
    for (var i = 0; i < levels; i++) {
        tree.pathElements[i] <== pathElements[i];
        tree.pathIndices[i] <== pathIndices[i];
    }

    recipientSquare === recipient * recipient;
    relayerSquare === relayer * relayer;
    feeSquare === fee * fee;
    refundSquare === refund * refund;
}

component main {public [root, nullifierHash, recipient, relayer, fee, refund]} = Withdraw(20);