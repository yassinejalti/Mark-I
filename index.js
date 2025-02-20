const axios = require('axios');

// configuration
const config = require('./config/config.json');

const engine = async () => {
    const payload = {
        "name": "getNewPairsV2",
        "data": {
            "chainIds": [1399811149],
            "poolCreationBlockTimestamp": Math.floor(Date.now()/1000),
            "filters": {
                "Mint Auth Disabled": true,
                "Freeze Auth Disabled": true,
                "LP Burned": false,
                "Liquidity": {
                    "dollar": true
                },
                "Volume": {
                    "dollar": true
                },
                "Market Cap": {
                    "dollar": true
                }
            }
        }
    };

    const headers = {
        "method": "POST",
        "content-type": "application/json",
        "cookie": config.cookie,
        "user-agent": config.userAgent,
    };

    // while(true){
        try {
            const response = await axios.post("https://api-neo.bullx.io/v2/api/getNewPairsV2", payload, { headers });
            console.log(response.data.data[response.data.data.length - 1]);
        } catch (error) {
            console.error('Error:', error.response ? error.response.data : error.message);
        }
    // }
};

engine();