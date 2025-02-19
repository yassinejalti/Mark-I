-- staging token data table

CREATE TABLE staging_token_data (
    id VARCHAR(255) PRIMARY KEY,
    type VARCHAR(255),
    volume DOUBLE DEFAULT 1,
    buys_count INT DEFAULT 1,
    sells_count INT DEFAULT 1,
    address VARCHAR(255),
    tokenAddress VARCHAR(255),
    fdv DOUBLE DEFAULT 1,
    price_usd DOUBLE DEFAULT 1,
    name VARCHAR(255),
    symbol VARCHAR(255),
    created_timestamp BIGINT,
    open_timestamp BIGINT,
    init_liq_usd DOUBLE DEFAULT 1,
    init_liq_quote DOUBLE DEFAULT 1,
    init_liq_token DOUBLE DEFAULT 1,
    init_liq_timestamp BIGINT,
    cur_liq_quote DOUBLE DEFAULT 1,
    cur_liq_usd DOUBLE DEFAULT 1,
    mint_authority BOOLEAN,
    freeze_authority BOOLEAN,
    lp_burned_perc DOUBLE,
    top_holders_perc DOUBLE,
    twitter VARCHAR(255),
    website VARCHAR(255),
    telegram VARCHAR(255),
    medium VARCHAR(255),
    reddit VARCHAR(255),
    dex_i INT,
    ignored BOOLEAN,
    fromPump BOOLEAN,
    fromMoonshot BOOLEAN,
    fromMemeDex VARCHAR(255),
    imgUrl VARCHAR(255),
    weighted_avg_composite_score DOUBLE,
    cumulative_composite_growth DOUBLE,
    vip_priority_level DOUBLE DEFAULT 0,
    internal_update_timestamp BIGINT
);


-- Migrate and update priority level

DELIMITER //

CREATE PROCEDURE MigrateAndUpdatePriorityLevel()
BEGIN
    INSERT INTO staging_token_data (
        id, type, volume, buys_count, sells_count, address, tokenAddress, fdv, price_usd, name, symbol, 
        created_timestamp, open_timestamp, init_liq_usd, init_liq_quote, init_liq_token, init_liq_timestamp, 
        cur_liq_quote, cur_liq_usd, mint_authority, freeze_authority, lp_burned_perc, top_holders_perc, 
        twitter, website, telegram, medium, reddit, dex_i, ignored, fromPump, fromMoonshot, fromMemeDex, 
        imgUrl, weighted_avg_composite_score, cumulative_composite_growth, vip_priority_level, internal_update_timestamp
    )
    SELECT 
        id, type, volume, buys_count, sells_count, address, tokenAddress, fdv, price_usd, name, symbol, 
        created_timestamp, open_timestamp, init_liq_usd, init_liq_quote, init_liq_token, init_liq_timestamp, 
        cur_liq_quote, cur_liq_usd, mint_authority, freeze_authority, lp_burned_perc, top_holders_perc, 
        twitter, website, telegram, medium, reddit, dex_i, ignored, fromPump, fromMoonshot, fromMemeDex, 
        imgUrl, weighted_avg_composite_score, cumulative_composite_growth, priority_level, internal_update_timestamp
    FROM 
        token_data
    WHERE 
        priority_level IN (0.5, 1, 2)
    ORDER BY 
        priority_level ASC;

    UPDATE 
        token_data
    SET 
        priority_level = 5
    WHERE 
        priority_level IN (0.5, 1, 2);
END //

DELIMITER ;

-- Blacklist table

CREATE TABLE blacklist(
    id INT PRIMARY KEY AUTO_INCREMENT,
    status ENUM('pending', 'confirmed') NOT NULL,
    adress VARCHAR(255) NOT NULL,
    tokenAddress VARCHAR(255) NOT NULL

) AUTO_INCREMENT = 1000;

-- Token delete logs table

CREATE TABLE token_delete_logs(
    adress VARCHAR(255) PRIMARY KEY,
    cus VARCHAR(255) NOT NULL,
    delete_timestamp BIGINT NOT NULL

);

-- Golden tokens table

CREATE TABLE golden_token(
    id INT PRIMARY KEY AUTO_INCREMENT,
    address VARCHAR(255),
    holders INT,
    top10HoldersSupplyPerc DOUBLE,
    insiderWalletsSupplyPerc DOUBLE,
    devHoldingSupplyPerc DOUBLE,
    sniperWalletsCount INT,
    marketCap DOUBLE,
    name VARCHAR(255),
    symbol VARCHAR(255),
    twitter VARCHAR(255) NULL,
    website VARCHAR(255) NULL,
    imgUrl VARCHAR(255),
    priority_level DOUBLE DEFAULT 0,
    migrated_timestamp BIGINT NOT NULL
    
) AUTO_INCREMENT = 1000;

-- Silver tokens table

CREATE TABLE silver_token(
    id INT PRIMARY KEY AUTO_INCREMENT,
    address VARCHAR(255),
    holders INT,
    top10HoldersSupplyPerc DOUBLE,
    insiderWalletsSupplyPerc DOUBLE,
    devHoldingSupplyPerc DOUBLE,
    sniperWalletsCount INT,
    marketCap DOUBLE,
    name VARCHAR(255),
    symbol VARCHAR(255),
    risks TEXT NOT NULL,
    twitter VARCHAR(255) NULL,
    website VARCHAR(255) NULL,
    imgUrl VARCHAR(255),
    priority_level DOUBLE DEFAULT 0,
    migrated_timestamp BIGINT NOT NULL

) AUTO_INCREMENT = 1000;

-- To buy tokens table

-- CREATE TABLE to_buy_token();

-- FINISHED

