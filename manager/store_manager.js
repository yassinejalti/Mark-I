const axios = require('axios');
const config = require('./config/config.json');
// const { FilterBot } = require('./filter_bot');

class StoreManager {
    static tokens = [];
    static lastMinuteTimestamp = null;

    static insertNewTokens(arg) {
        const currentTimestamp = Date.now();

        if (StoreManager.lastMinuteTimestamp) {
            if (currentTimestamp - StoreManager.lastMinuteTimestamp >= 5000) {
                StoreManager.removeDuplicates();
                StoreManager.sendToStore();
                StoreManager.tokens = [];
                StoreManager.lastMinuteTimestamp = currentTimestamp;
            } else {
                StoreManager.initialMapping(arg);
            }
        } else {
            StoreManager.lastMinuteTimestamp = currentTimestamp;
            StoreManager.initialMapping(arg);
        }
    }

    static async sendToStore() {
        try {
            const tokensData = StoreManager.tokens.map(token => {
                return {
                    id: token.id,
                    volume: null, // only volumeUSD5m
                    buys_count: token.buys,
                    sells_count: token.sells,
                    address: token.address,
                    marketCap: token.marketCapUSD,
                    name: token.name,
                    symbol: token.symbol,
                    cur_liq_usd: token.liquidityUSD,
                    lp_burned_perc: token.liquidityPoolBurnPercentage,
                    top_holders_perc: token.top10HoldersSupplyPerc,
                    twitter: token.links.twitter || null,
                    website: token.links.website || null,
                    created_timestamp: token.poolCreationBlockTimestamp
                };
            });

            await axios.post(`${config.API_ADDRESS}/send_to_store.php`, {
                API_KEY: config.API_KEY,
                tokens: tokensData,
            });
        } catch (error) {
            console.error('Error sending data to store:', error);
        } finally {
            // FilterBot.runBot();
        }
    }

    static initialMapping(arr) {
        StoreManager.tokens.push(...arr);
    }

    static removeDuplicates() {
        const uniqueObjects = {};
        for (const obj of StoreManager.tokens.reverse()) {
            uniqueObjects[obj.id] = obj;
        }
        StoreManager.tokens = Object.values(uniqueObjects).reverse();
    }
}

module.exports = { StoreManager };