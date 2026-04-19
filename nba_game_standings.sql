-- ============================================================
-- NBA Standings Query
-- ------------------------------------------------------------
-- Purpose:
--   Generate team standings for the most recent season using
--   game-level data.
--
-- Description:
--   - Filters to the latest season based on max(game_date)
--   - Removes exact duplicate game records
--   - Transforms each game into one row per team (home/away)
--   - Aggregates team performance metrics:
--       * Total Wins (W) and Losses (L)
--       * Win Percentage (Pct)
--       * Home record (W-L)
--       * Away record (W-L)
--       * Last 10 games record (L10)
--
-- Notes:
--   - Assumes duplicate rows are identical across all columns
--   - Uses ROW_NUMBER() to identify most recent games per team
--   - Uses 1.0 * to ensure decimal division for win percentage
-- ============================================================

WITH latest_season AS (
    -- Identify the most recent season based on the latest game_date in the dataset
    SELECT DISTINCT(season_id)
    FROM game
    WHERE game_date = (SELECT MAX(game_date) FROM game)
),

no_dupe AS (
    -- Remove exact duplicate rows for the selected season
    SELECT DISTINCT *
    FROM game
    WHERE season_id IN (SELECT season_id FROM latest_season)
),

team_games AS (
    -- Normalize the dataset: convert each game into two rows (one per team)

    -- Home team perspective
    SELECT
        team_name_home AS team,
        game_date,
        wl_home AS wl,
        'home' AS location
    FROM no_dupe

    UNION ALL

    -- Away team perspective
    SELECT
        team_name_away AS team,
        game_date,
        wl_away AS wl,
        'away' AS location
    FROM no_dupe
),

ranked_games AS (
    -- Rank each team's games by most recent first (used for L10 calculation)
    SELECT 
		*,
		ROW_NUMBER() OVER (PARTITION BY team ORDER BY game_date DESC) AS rn
    FROM team_games
)

SELECT
    team,
    SUM(CASE WHEN wl = 'W' THEN 1 ELSE 0 END) AS W,
    SUM(CASE WHEN wl = 'L' THEN 1 ELSE 0 END) AS L,
    ROUND(1.0 * SUM(CASE WHEN wl = 'W' THEN 1 ELSE 0 END) / COUNT(*),3) AS Pct,

	CONCAT(
		SUM(CASE WHEN location = 'home' AND wl = 'W' THEN 1 ELSE 0 END),
		'-',
		SUM(CASE WHEN location = 'home' AND wl = 'L' THEN 1 ELSE 0 END)
	) AS Home,

	CONCAT(
		SUM(CASE WHEN location = 'away' AND wl = 'W' THEN 1 ELSE 0 END),
		'-',
		SUM(CASE WHEN location = 'away' AND wl = 'L' THEN 1 ELSE 0 END)
	) AS Away,

	CONCAT(
		SUM(CASE WHEN rn <= 10 AND wl = 'W' THEN 1 ELSE 0 END),
		'-',
		SUM(CASE WHEN rn <= 10 AND wl = 'L' THEN 1 ELSE 0 END)
	) AS L10

FROM ranked_games
GROUP BY team
;