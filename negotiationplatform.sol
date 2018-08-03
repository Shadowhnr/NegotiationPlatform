pragma solidity ^0.4.20;
import "./ownable.sol";

    contract NegotiationPlatform is Ownable
    {
        struct Option
        {
            string asset;
            string type;
            uint256 expirationDate;
            uint256 strike;
        }
        
        struct Position
        {
            Option option;
            uint256 quantity;
        }
        
        mapping (address => uint256) public balances;
        mapping (uint256 => mapping(address => uint256) ownerToCount) optionToOwner;
        
        Option[] public options;
        
        modifier ownerOf(uint _optionId)
        {
            require(optionToOwner[_optionId][msg.sender]>0);
            _;
        }
        function registerOption(string asset,string type, uint256 expirationDate,uint256 strike) onlyOwner public
        {
            require(asset==keccak256("DOL") &&(type == keccak256("call") ||type == keccak256("put")) &&
                    expirationDate >= now && strike >= 0 && strike <= 2**52);
            options.push(Option(asset,type,expirationDate,strike));
        }
        function consultAvailableOptions() public returns (Option[])
        {
            return options;
        }
        function buyOptions(uint id, uint numberOfOptions, uint optionPrice)
        {
            require(balances[msg.sender] >= numberOfOptions*optionPrice);
            balances[msg.sender] -= numberOfOptions*optionPrice;
            optionToOwner[id][msg.sender] += numberOfOptions;
        }
        function sellOptions(uint id,uint numberOfOptions, uint optionPrice) public ownerOf(id)
        {
            require(numberOfOptions <= optionToOwner[_optionId][msg.sender]);
            balances[msg.sender] += numberOfOptions*optionPrice;
            optionToOwner[id][msg.sender] -= numberOfOptions;
        }
        function getPosition() returns (position[])
        {
            position[] memory pos = new position[](options.length);
            uint counter = 0;
            for(uint i=0; i<options.length;i++)
            {
                if(optionToOwner[i][msg.sender]>0)
                {
                    pos[counter] = Position(options[i],optionToOwner[i][msg.sender]);
                    counter++;
                }
            }
            return pos;
        }
        function getBalance() public returns (uint)
        {
            return balances[msg.sender];
        }
        function exertOption(uint id, uint quantity,uint ptaxTax) public ownerOf(id)
        {
            require(optionToOwner[id][msg.sender]>= quantity)
            if(options[id].type==keccak256("call"))
            {
                require(balances[msg.sender] >= ptaxTax);
                balances[msg.sender] -= ptaxTax*quantity;
                optionToOwner[id][msg.sender]-= quantity;
            }
            else if(options[id].type==keccak256("put"))
            {
                balances[msg.sender] += ptaxTax*quantity;
                optionToOwner[id][msg.sender]-= quantity;
            }
        }
    }

