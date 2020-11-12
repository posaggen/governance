pragma solidity 0.5.11;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/roles/WhitelistedRole.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "./AdminControl.sol";
import "./SponsorWhitelistControl.sol";
import "./Staking.sol";

contract Governance is WhitelistedRole {
    using SafeMath for uint256;

    struct Proposal {
        string title;
        string discussion;
        uint256 deadline;
        string[] options;
        uint256[] optionVotes;
        mapping(address => uint256) votedOption;
        mapping(address => uint256) votedPower;
        address proposer;
    }

    struct ProposalAbstract {
        string title;
        string discussion;
        uint256 deadline;
        string[] options;
        uint256[] optionVotes;
        string status;
        address proposer;
        uint256 proposalId;
    }

    // proposal
    address public nextProposer;
    uint256 public proposalCnt;
    Proposal[] public proposals;

    // internal contracts
    SponsorWhitelistControl public constant SPONSOR = SponsorWhitelistControl(
        address(0x0888000000000000000000000000000000000001)
    );

    Staking public constant STAKING = Staking(
        address(0x0888000000000000000000000000000000000002)
    );

    AdminControl public constant adminControl = AdminControl(
        address(0x0888000000000000000000000000000000000000)
    );

    event Proposed(
        uint256 indexed proposalId,
        address indexed proposer,
        string title
    );
    event Voted(
        uint256 indexed proposalId,
        address indexed voter,
        uint256 indexed votedOption,
        uint256 votedAmount
    );
    event WithdrawVoted(
        uint256 indexed proposalId,
        address indexed voter,
        uint256 indexed withdrawOption,
        uint256 withdrawAmount
    );

    constructor() public {
        // remove contract admin
        adminControl.setAdmin(address(this), address(0));
        require(
            adminControl.getAdmin(address(this)) == address(0),
            "require admin == null"
        );
        // cfx sponsor
        address[] memory users = new address[](1);
        users[0] = address(0);
        SPONSOR.addPrivilege(users);
        // add whitelist
        _addWhitelisted(msg.sender);
    }

    function getBlockNumber() public view returns (uint256) {
        return block.number;
    }

    function summarizeProposal(uint256 idx)
        internal
        view
        returns (ProposalAbstract memory)
    {
        Proposal storage proposal = proposals[idx];
        ProposalAbstract memory res;
        res.title = proposal.title;
        res.discussion = proposal.discussion;
        res.deadline = proposal.deadline;
        res.options = proposal.options;
        res.optionVotes = proposal.optionVotes;
        res.proposer = proposal.proposer;
        res.proposalId = idx;
        if (res.deadline < block.number) {
            res.status = "Closed";
        } else {
            res.status = "Active";
        }
        return res;
    }

    function proposalCount() public view returns (uint256) {
        return proposalCnt;
    }

    function getVoteForProposal(uint256 proposalId, address voter)
        public
        view
        returns (uint256, uint256)
    {
        require(proposalId < proposalCnt, "invalid proposal ID");
        Proposal storage proposal = proposals[proposalId];
        return (proposal.votedOption[voter], proposal.votedPower[voter]);
    }

    function getProposalById(uint256 proposalId)
        public
        view
        returns (ProposalAbstract memory)
    {
        require(proposalId < proposalCnt, "invalid proposal ID");
        return summarizeProposal(proposalId);
    }

    function getProposalList(uint256 offset, uint256 cnt)
        public
        view
        returns (ProposalAbstract[] memory)
    {
        require(offset < proposalCnt, "invalid offset");
        require(cnt <= 100, "cnt is larger than 100");
        uint256 i = proposalCnt - 1 - offset;
        if (cnt > i + 1) cnt = i + 1;
        ProposalAbstract[] memory res = new ProposalAbstract[](cnt);
        for (uint256 k = 0; k < cnt; ++k) {
            res[k] = summarizeProposal(i - k);
        }
        return res;
    }

    function setNextProposer(address proposer) public onlyWhitelisted {
        nextProposer = proposer;
    }

    function vote(uint256 proposalId, uint256 optionId) public {
        require(proposalId < proposalCnt, "invalid proposal ID");
        Proposal storage proposal = proposals[proposalId];
        require(proposal.deadline >= block.number, "the proposal has finished");
        require(optionId < proposal.options.length, "invalid option ID");

        uint256 lastVotedPower = proposal.votedPower[msg.sender];
        if (lastVotedPower > 0) {
            uint256 lastVoted = proposal.votedOption[msg.sender];
            proposal.optionVotes[lastVoted] = proposal.optionVotes[lastVoted]
                .sub(lastVotedPower);
            emit WithdrawVoted(
                proposalId,
                msg.sender,
                lastVoted,
                lastVotedPower
            );
        }

        uint256 votePower = STAKING.getVotePower(msg.sender, proposal.deadline);
        proposal.votedOption[msg.sender] = optionId;
        proposal.votedPower[msg.sender] = votePower;
        proposal.optionVotes[optionId] = proposal.optionVotes[optionId].add(
            votePower
        );
        emit Voted(proposalId, msg.sender, optionId, votePower);
    }

    function _submit(
        string memory title,
        string memory discussion,
        uint256 deadline,
        string[] memory options,
        address proposer
    ) internal {
        require(options.length <= 1000, "too many options");

        Proposal memory proposal;
        proposal.title = title;
        proposal.discussion = discussion;
        proposal.deadline = deadline;
        proposal.options = options;
        proposal.optionVotes = new uint256[](options.length);
        proposal.proposer = proposer;
        proposals.push(proposal);

        emit Proposed(proposalCnt, proposer, title);
        nextProposer = address(0);
        proposalCnt += 1;
    }

    function submitProposal(
        string memory title,
        string memory discussion,
        uint256 deadline,
        string[] memory options
    ) public {
        require(msg.sender == nextProposer, "sender is not the next proposer");
        _submit(title, discussion, deadline, options, msg.sender);
    }

    function submitProposalByWhitelist(
        string memory title,
        string memory discussion,
        uint256 deadline,
        string[] memory options,
        address proposer
    ) public onlyWhitelisted {
        _submit(title, discussion, deadline, options, proposer);
    }
}
