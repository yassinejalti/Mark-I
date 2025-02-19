import { post } from 'axios';

// configuration
const config = require('./config.json');

const engine = async () => {
    const payload = {
        "name": "getNeoVisionV3",
        "data": {
            "chainIds": [
                1399811149
            ],
            "poolCreationBlockTimestamp": 1739916023,
            "filters": {
                "Top 10 Holders": false,
                "With at least 1 social": false,
                "Search": {
                    "isTextFilter": true,
                    "isLastCategoryItem": true,
                    "textFilterPlaceholder": "keyword1, keyword2... (max 5)"
                },
                "B.Curve %": {
                    "percentage": true,
                    "isLastCategoryItem": true
                },
                "Dev holding %": {
                    "percentage": true
                },
                "Holders": {},
                "Insider wallets supply": {
                    "percentage": true
                },
                "Sniper wallets": {},
                "Bot users": {
                    "isLastCategoryItem": true
                },
                "5 min Price Change": {
                    "percentage": true
                },
                "5 min Volume": {
                    "dollar": true,
                    "isLastCategoryItem": true
                },
                "Liquidity": {
                    "dollar": true
                },
                "Volume": {
                    "dollar": true
                },
                "Market Cap": {
                    "dollar": true
                },
                "Txns": {
                    "isLastCategoryItem": true
                },
                "Buys": {},
                "Sells": {
                    "isLastCategoryItem": true
                },
                "Token Age (mins)": {},
                "pumpFunEnabled": true,
                "moonshotTokenEnabled": true,
                "sunpumpTokenEnabled": false,
                "grafunTokenEnabled": false
            }
        }
    };

    const headers = {
        "method": "POST",
        "path": "/v2/api/getNeoVisionV3",
        "content-type": "application/json",
        "cookie": config.cookie,
        "user-agent": config.userAgent,
    };

    try {
        const response = await post("https://api-neo.bullx.io/v2/api/getNeoVisionV3", payload, { headers });
        console.log(response.data);
    } catch (error) {
        console.error('Error:', error.response ? error.response.data : error.message);
    }
};

engine();