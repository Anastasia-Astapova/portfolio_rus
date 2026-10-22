-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
-- Расчёт общего количества пользователей, количество платящих пользователей и доли платящих пользователей
SELECT 
	COUNT(id) AS total_users,
	SUM(payer) AS total_paying_users,
	ROUND(SUM(payer)/COUNT(id)::NUMERIC, 4) AS paying_users_share
FROM fantasy.users;

-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
-- Расчёт общего количества пользователей, количества платящих пользователей и доли платящих пользователей в разрезе расы
SELECT 
	race, 
	COUNT(id) AS total_by_race, 
	SUM(payer) AS paying_by_race,
	ROUND(SUM(payer)/COUNT(DISTINCT id)::NUMERIC, 4) AS paying_by_race_share
FROM fantasy.race AS r
LEFT JOIN fantasy.users AS u USING(race_id)
GROUP BY race
ORDER BY paying_by_race_share DESC;

-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
-- Расчёт общего кол-ва покупок, их суммарной, максимальной и минимальной стоимости, 
-- а также среднего значения, медианы и стандартного отклонения стоимости покупки.
SELECT 
	COUNT(transaction_id) AS total_events, 
	SUM(amount) AS total_sum, 
	MIN(amount) AS min_amnt,
	MAX(amount) AS max_amnt, 
	AVG(amount)::NUMERIC(5,2) AS avg_amount,
	PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY amount) AS median_amnt,
	STDDEV(amount)::NUMERIC(6,2) AS std_dev
FROM fantasy.events; 

-- 2.2: Аномальные нулевые покупки:
-- Поиск покупок с нулевой стоимостью, определение их количества и доли от общего количества покупок
SELECT
    COUNT(*) FILTER (WHERE amount = 0) AS zero_value_total,
    COUNT(*) AS events_total,
    ROUND(COUNT(*) FILTER (WHERE amount = 0)::numeric 
        / COUNT(*), 4) AS zero_value_share
FROM fantasy.events;

-- 2.3: Популярные эпические предметы:
-- Расчёт статистики продаж в разрезе эпических предметов (общее и относительное количество покупок + доля игроков, купивших предмет хотя бы раз)
SELECT 
	game_items, 
	COUNT(transaction_id) AS sales_by_item, 
	COUNT(DISTINCT id) AS buyers_items, 
	ROUND(COUNT(*)::numeric / SUM(COUNT(*)) OVER(), 6) AS sales_share, 
	ROUND(COUNT(DISTINCT id)::numeric / (SELECT COUNT(DISTINCT id) 
		FROM fantasy.events WHERE amount != 0), 4) AS buyers_share 
FROM fantasy.items 
LEFT JOIN fantasy.events USING(item_code)
-- Исключаю аномальные покупки с нулевой стоимостью
WHERE amount != 0 
GROUP BY item_code 
ORDER BY sales_by_item DESC;

-- Часть 2. Решение ad hoc-задачи
-- Задача: Определение зависимости активности игроков от расы персонажа:
WITH 
--В первом CTE считаю платящих игроков (paying) и общее количество игроков (total) в рзрезе рас
players_and_payers_by_race AS (
	SELECT 
		race_id, 
		COUNT(u.id) AS total_by_race,
		SUM(payer) AS paying_by_race
	FROM fantasy.users AS u
	GROUP BY race_id
),
--Во втором CTE считаю платящих игроков, совершивших покупки, в разрезе рас
paying_buyers AS (
	SELECT 
		race_id, 
		COUNT(DISTINCT id) AS paying_buyers_by_race
	FROM fantasy.events
	JOIN fantasy.users USING(id)
	WHERE payer = 1 AND amount !=0
	GROUP BY race_id
), 
--В третьем CTE считаю количество игроков, совершивших покупки (buyers), и общее количество покупок (total_events) в разрезе рас
buyers_by_race AS (
	SELECT 
		race_id, 
		COUNT(DISTINCT e.id) AS total_buyers, 
		COUNT(transaction_id) AS total_events, 
		--Считаю среднее количество покупок на 1 buyer
		ROUND(COUNT(transaction_id)::numeric/COUNT(DISTINCT e.id), 4) AS avg_events_per_buyer,
		--Считаю среднюю стоимость 1 покупки на 1 buyer
		AVG(amount)::NUMERIC(5,2) AS avg_sale_per_buyer, 
		--Считаю среднюю суммарную стоимость всех покупок на 1 buyer
		ROUND(SUM(amount)::NUMERIC/COUNT(DISTINCT id), 2) AS avg_sum_per_buyer
	FROM fantasy.events AS e
	LEFT JOIN fantasy.users AS u USING(id)
	WHERE amount !=0
	GROUP BY race_id
)
-- В основном запросе вывожу статистики (долю покупателей, платящих игроков, среднюю сумму покупки, среднее количество покупок) в разрезе рас
	SELECT 
		race, 
		total_by_race, 
		total_buyers, 
		--Считаю долю buyers к общему количеству игроков
		ROUND(total_buyers::NUMERIC/total_by_race, 4) AS buyers_share, 
		--Считаю долю paying к buyers
		ROUND(paying_buyers_by_race::NUMERIC/total_buyers, 4) AS paying_share,
		avg_events_per_buyer, 
		avg_sale_per_buyer, 
		avg_sum_per_buyer
	FROM players_and_payers_by_race
	LEFT JOIN buyers_by_race USING(race_id)
	LEFT JOIN paying_buyers USING(race_id)
	JOIN fantasy.race AS r USING(race_id)
	--Сортирую по доле buyers
	ORDER BY buyers_share DESC;