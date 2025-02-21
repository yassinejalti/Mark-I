-- main tokens table

CREATE TABLE tokens (
    id VARCHAR(255) PRIMARY KEY,
    volume DOUBLE, -- Volume in USD (5-minute interval)
    buys_count INT,
    sells_count INT,
    address VARCHAR(255),
    marketCap DOUBLE,
    name VARCHAR(255),
    symbol VARCHAR(255),
    cur_liq_usd DOUBLE,
    lp_burned_perc DOUBLE,
    top_holders_perc DOUBLE,
    twitter VARCHAR(255), -- Twitter link (optional)
    website VARCHAR(255), -- Website link (optional)
    created_timestamp BIGINT,
    weighted_avg_composite_score DOUBLE NULL, -- Weighted average composite score
    cumulative_composite_growth DOUBLE NULL, -- Cumulative composite growth
    priority_level DOUBLE DEFAULT 0,
    internal_update_timestamp BIGINT
);

-- snapshots table code

CREATE TABLE snapshot (
    id INT PRIMARY KEY AUTO_INCREMENT,
    token_id VARCHAR(255),
    composite_score DOUBLE DEFAULT 0,
    created_timestamp BIGINT NOT NULL,
    FOREIGN KEY (token_id) REFERENCES token_data(id)
) AUTO_INCREMENT = 1000;

-- The procedure to insert or update token with advanced functionality

DELIMITER //

CREATE PROCEDURE InsertOrUpdateTokenData(
    IN p_id VARCHAR(255),
    IN p_volume DOUBLE,
    IN p_buys_count INT,
    IN p_sells_count INT,
    IN p_address VARCHAR(255),
    IN p_marketCap DOUBLE,
    IN p_name VARCHAR(255),
    IN p_symbol VARCHAR(255),
    IN p_cur_liq_usd DOUBLE,
    IN p_lp_burned_perc DOUBLE,
    IN p_top_holders_perc DOUBLE,
    IN p_twitter VARCHAR(255),
    IN p_website VARCHAR(255),
    IN p_created_timestamp BIGINT
)
BEGIN
    DECLARE v_liquidity_growth DOUBLE;
    DECLARE v_volume_to_fdv_ratio DOUBLE;
    DECLARE v_buy_sell_ratio DOUBLE;
    DECLARE v_fdv_growth DOUBLE;
    DECLARE v_price_momentum DOUBLE;
    DECLARE v_composite_score DOUBLE;

    procedure_block: BEGIN
        IF p_lp_burned_perc < 97 THEN
            LEAVE procedure_block;
        END IF;

        -- for the new logic check if the operation that is happening is insert or update
        -- if it's insert then:
        -- 

        INSERT INTO tokens (
            id, volume, buys_count, sells_count, address, marketCap, name, symbol, 
            cur_liq_usd, lp_burned_perc, top_holders_perc, twitter, website, created_timestamp
        ) VALUES (
            p_id, p_volume, p_buys_count, p_sells_count, p_address, p_marketCap, p_name, p_symbol, 
            p_cur_liq_usd, p_lp_burned_perc, p_top_holders_perc, p_twitter, p_website, p_created_timestamp
        )
        ON DUPLICATE KEY UPDATE
            volume = VALUES(volume),
            buys_count = VALUES(buys_count),
            sells_count = VALUES(sells_count),
            address = VALUES(address),
            marketCap = VALUES(marketCap),
            name = VALUES(name),
            symbol = VALUES(symbol),
            cur_liq_usd = VALUES(cur_liq_usd),
            lp_burned_perc = VALUES(lp_burned_perc),
            top_holders_perc = VALUES(top_holders_perc),
            twitter = VALUES(twitter),
            website = VALUES(website),
            created_timestamp = VALUES(created_timestamp);

        SET time_zone = '+01:00';
        SET v_liquidity_growth = IF(p_init_liq_usd = 0, 0, p_cur_liq_usd / p_init_liq_usd);
        SET v_volume_to_fdv_ratio = IF(p_fdv = 0, 0, p_volume / p_fdv);
        SET v_buy_sell_ratio = IF(p_sells_count = 0, 0, p_buys_count / p_sells_count);
        SET v_fdv_growth = IF(p_init_liq_usd = 0, 0, p_fdv / p_init_liq_usd);
        SET v_price_momentum = IF(p_init_liq_usd = 0 OR p_init_liq_token = 0, 0, p_price_usd / (p_init_liq_usd / p_init_liq_token));

        SET v_composite_score = (
            (IF(v_liquidity_growth > 2, 1, v_liquidity_growth / 2) * 0.25) + 
            (IF(v_volume_to_fdv_ratio > 0.1, 1, v_volume_to_fdv_ratio / 0.1) * 0.25) + 
            (IF(v_buy_sell_ratio BETWEEN 1.2 AND 3, 1, 0) * 0.15) + 
            (IF(v_fdv_growth > 10, 1, v_fdv_growth / 10) * 0.20) + 
            (IF(v_price_momentum > 1, 1, v_price_momentum) * 0.15)
        );

        INSERT INTO snapshot (
            token_id,
            liquidity_growth,
            volume_to_fdv_ratio,
            buy_sell_ratio,
            fdv_growth,
            price_momentum,
            composite_score,
            created_timestamp
        ) VALUES (
            p_id,
            IFNULL(v_liquidity_growth, 0.1),
            IFNULL(v_volume_to_fdv_ratio, 0.1),
            IFNULL(v_buy_sell_ratio, 1),
            IFNULL(v_fdv_growth, 0.1),
            IFNULL(v_price_momentum, 0.1),
            IFNULL(v_composite_score, 0.1),
            UNIX_TIMESTAMP()
        );
    END procedure_block;

    -- Call additional procedures if needed
    CALL UpdateTokenCompositeScores();
END //

DELIMITER ;