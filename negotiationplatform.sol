pragma solidity ^0.4.24;

import "./ownable.sol";

    contract NegotiationPlatform is Ownable
    {
        struct Option
        {
            string asset;
            string optionType;
            uint256 expirationDate;
            uint256 strike;
        }
        
        struct Position
        {
            Option option;
            uint256 quantity;
        }
        
        mapping (address => uint256) public balances;
        mapping (uint256 => mapping(address => uint256)) optionToOwner;
        
        Option[] public options;
        
        modifier ownerOf(uint _optionId)
        {
            require(optionToOwner[_optionId][msg.sender]>0);
            _;
        }
        function registerOption(string asset,string optionType, uint256 expirationDate,uint256 strike) onlyOwner public
        {
            require(keccak256(abi.encodePacked(asset))==keccak256("DOL") &&(keccak256(abi.encodePacked(optionType)) == keccak256("call") 
                    ||keccak256(abi.encodePacked(optionType)) == keccak256("put")) &&
                    expirationDate >= now && strike >= 0 && strike <= 2**52);
            options.push(Option(asset,optionType,expirationDate,strike));
        }
        function consultAvailableOptions(uint pos) public returns (string,string,uint,uint)
        {
            Option storage option = options[pos];
            return (option.asset,option.optionType,option.expirationDate,option.strike);
        }
        function buyOptions(uint id, uint numberOfOptions, uint optionPrice)
        {
            require(balances[msg.sender] >= numberOfOptions*optionPrice);
            balances[msg.sender] -= numberOfOptions*optionPrice;
            optionToOwner[id][msg.sender] += numberOfOptions;
        }
        function sellOptions(uint id,uint numberOfOptions, uint optionPrice) public ownerOf(id)
        {
            require(numberOfOptions <= optionToOwner[id][msg.sender]);
            balances[msg.sender] += numberOfOptions*optionPrice;
            optionToOwner[id][msg.sender] -= numberOfOptions;
        }
        function getPosition() returns (Position[])
        {
            Position[] memory pos = new Position[](options.length);
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
            require(optionToOwner[id][msg.sender]>= quantity);
            if(keccak256(abi.encodePacked(options[id].optionType))==keccak256("call"))
            {
                require(balances[msg.sender] >= ptaxTax);
                balances[msg.sender] -= ptaxTax*quantity;
                optionToOwner[id][msg.sender]-= quantity;
            }
            else if(keccak256(abi.encodePacked(options[id].optionType))==keccak256("put"))
            {
                balances[msg.sender] += ptaxTax*quantity;
                optionToOwner[id][msg.sender]-= quantity;
            }
        }
    }