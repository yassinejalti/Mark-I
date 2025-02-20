-- main token data table

CREATE TABLE token_data (
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
    liquidity_growth DOUBLE DEFAULT 0,
    volume_to_fdv_ratio DOUBLE DEFAULT 0,
    buy_sell_ratio DOUBLE DEFAULT 0,
    fdv_growth DOUBLE DEFAULT 0,
    price_momentum DOUBLE DEFAULT 0,
    composite_score DOUBLE DEFAULT 0,
    created_timestamp BIGINT NOT NULL,
    FOREIGN KEY (token_id) REFERENCES token_data(id)
) AUTO_INCREMENT = 1000;

-- Delete junk tokens procedure

DELIMITER //

CREATE PROCEDURE removeIgnored()
BEGIN
    DECLARE one_hour_ago BIGINT;
    DECLARE five_min_ago BIGINT;
    DECLARE forty_eight_hours_ago BIGINT;

    SET time_zone = '+01:00';
    SET one_hour_ago = UNIX_TIMESTAMP() - (60 * 60);
    SET five_min_ago = UNIX_TIMESTAMP() - 300;
    SET forty_eight_hours_ago = UNIX_TIMESTAMP() - (48 * 60 * 60);

    CREATE TEMPORARY TABLE IF NOT EXISTS tokens_to_delete (
        id INT PRIMARY KEY
    );

    INSERT INTO tokens_to_delete (id)
    SELECT id FROM token_data 
    WHERE 
        (fdv < 10000 AND created_timestamp <= one_hour_ago)
        OR (internal_update_timestamp IS NULL AND created_timestamp <= five_min_ago)
        OR ((cur_liq_usd / fdv) < 0.03)
        OR created_timestamp <= forty_eight_hours_ago;

    DELETE FROM snapshot 
    WHERE token_id IN (SELECT id FROM tokens_to_delete);

    DELETE FROM token_data 
    WHERE id IN (SELECT id FROM tokens_to_delete);

    DROP TEMPORARY TABLE IF EXISTS tokens_to_delete;
END //

DELIMITER ;

-- Calculate and classify composite scores

DELIMITER //

CREATE PROCEDURE UpdateTokenCompositeScores()
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE tokenId VARCHAR(255);
    DECLARE snapshotCount INT;
    DECLARE latestSnapshotTimestamp BIGINT;
    DECLARE cur CURSOR FOR SELECT id FROM token_data;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    SET time_zone = '+01:00';
    OPEN cur;

    read_loop: LOOP
        FETCH cur INTO tokenId;
        IF done THEN
            LEAVE read_loop;
        END IF;

        SELECT COUNT(*)
        INTO snapshotCount
        FROM snapshot
        WHERE token_id = tokenId;

        SELECT MAX(created_timestamp)
        INTO latestSnapshotTimestamp
        FROM snapshot
        WHERE token_id = tokenId;

        IF snapshotCount >= 10 AND (UNIX_TIMESTAMP() - latestSnapshotTimestamp) < 60 THEN
            SELECT 
                SUM(ws.composite_score * ws.weight) / SUM(ws.weight) AS weighted_avg_composite_score,
                gc.cumulative_composite_growth
            INTO @weighted_avg, @cumulative_growth
            FROM (
                SELECT
                    token_id,
                    composite_score,
                    EXP(-0.1 * (UNIX_TIMESTAMP() - created_timestamp) / 3600) AS weight
                FROM snapshot
                WHERE token_id = tokenId
            ) ws
            JOIN (
                SELECT
                    token_id,
                    SUM((composite_score - prev_composite_score) / NULLIF(prev_composite_score, 0) * 100) AS cumulative_composite_growth
                FROM (
                    SELECT 
                        token_id, 
                        composite_score, 
                        created_timestamp,
                        LAG(composite_score) OVER (PARTITION BY token_id ORDER BY created_timestamp) AS prev_composite_score
                    FROM snapshot
                    WHERE token_id = tokenId
                ) ordered_snapshots
                GROUP BY token_id
            ) gc ON ws.token_id = gc.token_id
            GROUP BY ws.token_id;

            UPDATE token_data
            SET weighted_avg_composite_score = IFNULL(@weighted_avg, 0.1),
                cumulative_composite_growth = IFNULL(@cumulative_growth, 0)
            WHERE id = tokenId;
        END IF;

    END LOOP;

    CLOSE cur;
END //

DELIMITER ;

-- classify tokens from 1 to 4

DELIMITER //

CREATE PROCEDURE classifyTokens()
BEGIN
    UPDATE token_data
    SET priority_level = (
        SELECT 
            CASE 
                WHEN (score_class * 3 + growth_class * 0.5 + market_cap_class * 2) >= 12 THEN 1
                WHEN (score_class * 3 + growth_class * 0.5 + market_cap_class * 2) BETWEEN 9 AND 11 THEN 2
                WHEN (score_class * 3 + growth_class * 0.5 + market_cap_class * 2) BETWEEN 6 AND 8 THEN 3
                ELSE 4
            END
        FROM (
            SELECT 
                id,
                weighted_avg_composite_score,
                cumulative_composite_growth,
                fdv AS market_cap,

                CASE 
                    WHEN weighted_avg_composite_score >= 0.7 THEN 3
                    WHEN weighted_avg_composite_score >= 0.5 AND weighted_avg_composite_score < 0.7 THEN 2
                    ELSE 1
                END AS score_class,

                CASE 
                    WHEN cumulative_composite_growth >= 100 THEN 1
                    WHEN cumulative_composite_growth >= 20 AND cumulative_composite_growth < 100 THEN 0
                    ELSE 0
                END AS growth_class,

                CASE 
                    WHEN fdv >= 20000 THEN 3
                    WHEN fdv >= 10000 AND fdv < 20000 THEN 2
                    ELSE 1
                END AS market_cap_class
            FROM token_data
            WHERE weighted_avg_composite_score IS NOT NULL
              AND cumulative_composite_growth IS NOT NULL
        ) AS classification
        WHERE token_data.id = classification.id
    )
    WHERE weighted_avg_composite_score IS NOT NULL
      AND cumulative_composite_growth IS NOT NULL
      AND priority_level != 5;
END //

DELIMITER ;

-- The procedure to insert or update token with advanced functionality

DELIMITER //

CREATE PROCEDURE InsertOrUpdateTokenData(
    IN p_id VARCHAR(255),
    IN p_type VARCHAR(255),
    IN p_volume DOUBLE,
    IN p_buys_count INT,
    IN p_sells_count INT,
    IN p_address VARCHAR(255),
    IN p_tokenAddress VARCHAR(255),
    IN p_fdv DOUBLE,
    IN p_price_usd DOUBLE,
    IN p_name VARCHAR(255),
    IN p_symbol VARCHAR(255),
    IN p_created_timestamp BIGINT,
    IN p_open_timestamp BIGINT,
    IN p_init_liq_usd DOUBLE,
    IN p_init_liq_quote DOUBLE,
    IN p_init_liq_token DOUBLE,
    IN p_init_liq_timestamp BIGINT,
    IN p_cur_liq_quote DOUBLE,
    IN p_cur_liq_usd DOUBLE,
    IN p_mint_authority BOOLEAN,
    IN p_freeze_authority BOOLEAN,
    IN p_lp_burned_perc DOUBLE,
    IN p_top_holders_perc DOUBLE,
    IN p_twitter VARCHAR(255),
    IN p_website VARCHAR(255),
    IN p_telegram VARCHAR(255),
    IN p_medium VARCHAR(255),
    IN p_reddit VARCHAR(255),
    IN p_dex_i INT,
    IN p_ignored BOOLEAN,
    IN p_fromPump BOOLEAN,
    IN p_fromMoonshot BOOLEAN,
    IN p_fromMemeDex VARCHAR(255),
    IN p_imgUrl VARCHAR(255)
)
BEGIN
    DECLARE v_liquidity_growth DOUBLE;
    DECLARE v_volume_to_fdv_ratio DOUBLE;
    DECLARE v_buy_sell_ratio DOUBLE;
    DECLARE v_fdv_growth DOUBLE;
    DECLARE v_price_momentum DOUBLE;
    DECLARE v_composite_score DOUBLE;

    procedure_block: BEGIN
        IF 
            p_init_liq_usd IS NULL
            OR p_init_liq_quote IS NULL
            OR p_init_liq_token IS NULL
            OR p_init_liq_timestamp IS NULL
            OR p_ignored = 1 
            OR p_mint_authority = 1 
            OR p_freeze_authority = 1 
            OR p_lp_burned_perc < 97
            OR (p_dex_i != 6 AND RIGHT(p_tokenAddress, 4) = 'pump')
            OR (p_dex_i = 6 AND p_init_liq_quote < 60.0)
        THEN
            LEAVE procedure_block;
        END IF;

        INSERT INTO token_data (
            id, type, volume, buys_count, sells_count, address, tokenAddress, fdv, price_usd, name, symbol, 
            created_timestamp, open_timestamp, init_liq_usd, init_liq_quote, init_liq_token, init_liq_timestamp, 
            cur_liq_quote, cur_liq_usd, mint_authority, freeze_authority, lp_burned_perc, top_holders_perc, 
            twitter, website, telegram, medium, reddit, dex_i, ignored, fromPump, fromMoonshot, fromMemeDex, imgUrl
        ) VALUES (
            p_id, p_type, p_volume, p_buys_count, p_sells_count, p_address, p_tokenAddress, p_fdv, p_price_usd, 
            p_name, p_symbol, p_created_timestamp, p_open_timestamp, p_init_liq_usd, p_init_liq_quote, 
            p_init_liq_token, p_init_liq_timestamp, p_cur_liq_quote, p_cur_liq_usd, p_mint_authority, 
            p_freeze_authority, p_lp_burned_perc, p_top_holders_perc, p_twitter, p_website, p_telegram, 
            p_medium, p_reddit, p_dex_i, p_ignored, p_fromPump, p_fromMoonshot, p_fromMemeDex, p_imgUrl
        )
        ON DUPLICATE KEY UPDATE
            type = VALUES(type),
            volume = VALUES(volume),
            buys_count = VALUES(buys_count),
            sells_count = VALUES(sells_count),
            address = VALUES(address),
            tokenAddress = VALUES(tokenAddress),
            fdv = VALUES(fdv),
            price_usd = VALUES(price_usd),
            name = VALUES(name),
            symbol = VALUES(symbol),
            created_timestamp = VALUES(created_timestamp),
            open_timestamp = VALUES(open_timestamp),
            init_liq_usd = VALUES(init_liq_usd),
            init_liq_quote = VALUES(init_liq_quote),
            init_liq_token = VALUES(init_liq_token),
            init_liq_timestamp = VALUES(init_liq_timestamp),
            cur_liq_quote = VALUES(cur_liq_quote),
            cur_liq_usd = VALUES(cur_liq_usd),
            mint_authority = VALUES(mint_authority),
            freeze_authority = VALUES(freeze_authority),
            lp_burned_perc = VALUES(lp_burned_perc),
            top_holders_perc = VALUES(top_holders_perc),
            twitter = VALUES(twitter),
            website = VALUES(website),
            telegram = VALUES(telegram),
            medium = VALUES(medium),
            reddit = VALUES(reddit),
            dex_i = VALUES(dex_i),
            ignored = VALUES(ignored),
            fromPump = VALUES(fromPump),
            fromMoonshot = VALUES(fromMoonshot),
            fromMemeDex = VALUES(fromMemeDex),
            imgUrl = VALUES(imgUrl);

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

    CALL removeIgnored();
    CALL UpdateTokenCompositeScores();
END //

DELIMITER ;

-- The important update triggers

DELIMITER //

CREATE TRIGGER before_token_data_update
BEFORE UPDATE ON token_data
FOR EACH ROW
BEGIN
    SET time_zone = '+01:00';
    SET NEW.internal_update_timestamp = UNIX_TIMESTAMP();
END; //

DELIMITER ;

-- Adjust common words priority

DELIMITER //

CREATE PROCEDURE AdjustCommonWordsPriority()
BEGIN
    CREATE TEMPORARY TABLE IF NOT EXISTS WordFrequency AS (
        SELECT 
            LOWER(SUBSTRING_INDEX(SUBSTRING_INDEX(name, ' ', n.n), ' ', -1)) AS word,
            COUNT(*) AS frequency
        FROM 
            token_data
        JOIN 
            (SELECT 1 AS n UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5) n
        ON 
            LENGTH(name) - LENGTH(REPLACE(name, ' ', '')) >= n.n - 1
        WHERE 
            LENGTH(SUBSTRING_INDEX(SUBSTRING_INDEX(name, ' ', n.n), ' ', -1)) >= 3
            AND LOWER(SUBSTRING_INDEX(SUBSTRING_INDEX(name, ' ', n.n), ' ', -1)) NOT IN (
                'a', 'an', 'the',
                'for', 'and', 'nor', 'but', 'or', 'yet', 'so',
                'although', 'because', 'even though', 'since', 'unless', 'whereas', 
                'whether', 'while', 'though', 'as long as', 'as much as', 'provided that', 
                'in order that', 'so that', 'once', 'now that', 'lest',
                'either', 'neither', 'both', 'not only', 'but also', 'whether or', 'such as', 
                'rather than', 'just as', 'as well as', 'no sooner', 'than', 'scarcely when',
                'at', 'by', 'for', 'in', 'of', 'on', 'to', 'with', 'as', 'about', 
                'after', 'before', 'during', 'until', 'above', 'below', 'from', 'within', 
                'without', 'between', 'among', 'against', 'through', 'throughout', 
                'into', 'onto', 'upon', 'towards', 'beside', 'beyond', 'underneath', 
                'despite', 'except', 'inside', 'outside', 'per', 'via', 'concerning',
                'again', 'further', 'once', 'here', 'there', 'where', 'why', 'how', 
                'also', 'besides', 'consequently', 'finally', 'furthermore', 'hence', 
                'however', 'indeed', 'instead', 'likewise', 'meanwhile', 'moreover', 
                'nevertheless', 'nonetheless', 'otherwise', 'subsequently', 'therefore', 
                'thus', 'accordingly', 'comparatively', 'conversely', 'correspondingly', 
                'similarly', 'notwithstanding',
                'that', 'which', 'who', 'whom', 'whose', 
                'all', 'any', 'both', 'each', 'few', 'more', 'most', 'other', 'some', 
                'such', 'either', 'neither', 'this', 'that', 'these', 'those', 'another',
                'am', 'is', 'are', 'was', 'were', 'be', 'being', 'been', 'do', 'does', 
                'did', 'have', 'has', 'had', 'may', 'might', 'must', 'shall', 'should', 
                'can', 'could', 'will', 'would',
                'no', 'nor', 'not', 'neither', 'nothing', 'none', 'nobody', 'nowhere',
                'as a result', 'as far as', 'as soon as', 'as well as', 'even so', 
                'in addition', 'in contrast', 'in fact', 'in other words', 'in particular', 
                'in the meantime', 'in the same way', 'on the contrary', 'on the other hand', 
                'to put it another way', 'to sum up', 'to illustrate', 'for example', 
                'for instance', 'to clarify', 'in conclusion', 'in summary', 'to conclude'
            )
            AND priority_level IN (1, 2)
        GROUP BY 
            word
        HAVING 
            frequency > 1
    );

    CREATE TEMPORARY TABLE IF NOT EXISTS CommonWordMapping AS (
        SELECT 
            td.id
        FROM 
            token_data td
        JOIN 
            WordFrequency wf
        ON 
            LOWER(td.name) LIKE CONCAT('%', wf.word, '%')
        WHERE 
            td.priority_level IN (1, 2)
    );

    UPDATE token_data
    SET priority_level = 0.5
    WHERE id IN (SELECT id FROM CommonWordMapping);

    DROP TEMPORARY TABLE IF EXISTS WordFrequency;
    DROP TEMPORARY TABLE IF EXISTS CommonWordMapping;
END //

DELIMITER ;

-- FINISHED