/* Проект «Секреты Темнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Прудникова Диана. 
 * Дата:19.01.2025. 
*/
-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков
-- 1.1. Доля платящих пользователей по всем данным:
-- общее количество зарегистрированных игроков;
-- количество платящих игроков;
-- доля платящих игроков от общего количества пользователей, зарегистрированных в игре.
SELECT COUNT (DISTINCT id) AS total_users,
       SUM(payer) AS total_number_of_payers,
       ROUND (AVG (payer),2) AS percentage_of_paying_users 
FROM  fantasy.users;
-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
-- количество платящих игроков;
-- общее количество зарегистрированных игроков;
-- доля платящих игроков от общего количества пользователей, зарегистрированных в игре.
SELECT race_id,
       race,
       SUM(payer) AS total_number_of_payers,
       COUNT (DISTINCT id) total_users,
       ROUND (SUM(payer)::numeric/COUNT (DISTINCT id),2) AS percentage_of_paying_users_by_race
FROM fantasy.users AS u
LEFT JOIN fantasy.race AS r  USING (race_id)
GROUP BY race_id, race
ORDER BY total_users DESC,total_number_of_payers DESC, percentage_of_paying_users_by_race DESC;      
-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
-- общее количество покупок;
-- суммарная стоимость всех покупок;
-- минимальная и максимальная стоимость покупки;
-- среднее значение, медиана и стандартное отклонение от среднего значения стоимости покупки.
SELECT COUNT (DISTINCT transaction_id) AS number_of_purchases,
      SUM (amount) AS amount_of_purchases,
      MIN (amount) AS min_purchase_price,
      MAX (amount) AS max_purchase_price,
      ROUND(AVG (amount)::numeric,2) AS a_purchase_price,
      PERCENTILE_DISC (0.5) 
      WITHIN GROUP (ORDER BY amount) AS median,
      ROUND (STDDEV (amount)::numeric,2) AS standard_deviation
FROM fantasy.events;       
-- 2.2: Аномальные нулевые покупки:
-- количество аномально нулевых покупок и их доля от общего количества покупок. 
WITH zero_purchases AS (SELECT COUNT (transaction_id) AS number_of_purchases, 
(SELECT COUNT (amount) FROM fantasy.events WHERE amount=0) AS zero_purchases 
FROM fantasy.events)
SELECT zero_purchases,
       ROUND(zero_purchases::numeric/number_of_purchases, 4) AS the_proportion_of_zero_purchases
FROM zero_purchases; 
-- при решении следующих задач исключаем покупки с нулевой стоимостью;
-- в данных по полю amount минимальные значения после 0, в диапазоне от 0,01 до 1 можно допустить, это могут быть
-- обычные предметы и минимальная стоимость делает их доступными для новичков.
-- 2.3: Сравнительный анализ активности платящих и неплатящих игроков:
-- общее количество игроков каждой категории;
-- среднее количество покупок по каждой категории;
-- средняя сумма стоимости покупок на одного игрока в каждой категории;
-- в расчете исключаем покупки с нулевой стоимостью.
SELECT CASE 
	   WHEN payer=1 THEN 'платящие игроки'
       WHEN payer=0 THEN 'неплатящие игроки'
       END AS users,
       COUNT (DISTINCT u.id) AS count_users,
       ROUND ((COUNT (e.transaction_id)::float/COUNT(DISTINCT u.id))::numeric,2) AS avg_number_of_purchases,
       ROUND ((SUM (amount)/COUNT(DISTINCT u.id))::numeric,2) AS avg_purchase_amount
FROM fantasy.users AS u
LEFT JOIN fantasy.events e USING (id) 
WHERE amount>0  
GROUP BY payer
ORDER BY users DESC;
-- 2.4: Популярные эпические предметы:
-- в разрезе эпических предметов: 
-- количество внутриигровых продаж для каждого предмета;
-- количество внутриигровых продаж в относительном значении для каждого предмета;
-- количество уникальных игроков, которые хотя бы раз покупали данный предмет; 
-- доля игроков, которые хотя бы раз покупали данный предмет.
SELECT game_items, 
    COUNT(amount) AS number_of_sales, 
    ROUND ((COUNT(amount)::float/(SELECT COUNT(transaction_id) FROM fantasy.events WHERE amount <> 0))::numeric,4) AS rel_number,
    COUNT (DISTINCT id) AS number_of_users,
    ROUND ((COUNT (DISTINCT id)::float/(SELECT COUNT(DISTINCT id) FROM fantasy.events WHERE amount <> 0))::numeric,4) AS share_of_sales_users 
FROM fantasy.events
RIGHT JOIN fantasy.items USING(item_code)
WHERE amount <> 0
GROUP BY game_items
ORDER BY number_of_sales DESC;
-- Часть 2. Решение ad hoc-задач
-- Задача 1. Зависимость активности игроков от расы персонажа:
-- В разресе расы персонажа:
-- общее количество игроков;
-- количество игроков сделавших покупку,
-- количество платящих игроков сделавших покупку.  
WITH number_of_paying AS (SELECT race_id,
       race,
       COUNT (DISTINCT u.id) AS number_of_users,
       COUNT (DISTINCT e.id) FILTER (WHERE e.amount>0) AS number_of_buyers,
       COUNT (DISTINCT e.id) FILTER (WHERE u.payer=1) AS number_of_paying_buyers
 FROM fantasy.users AS u
 LEFT JOIN fantasy.race AS r USING (race_id)
 LEFT JOIN fantasy.events AS e ON u.id=e.id 
 GROUP BY race_id, race
 ORDER BY number_of_users DESC),
-- среднее количество покупок на одного игрока в разрезе расы;
-- средняя стоимость одной покупки на одного игрока в разрезе расы;
-- средняя суммарная стоимость всех покупок на одного игрока в разрезе расы.
avg_number AS (SELECT u.race_id, 
        r.race,
        COUNT(e.transaction_id)/ COUNT(DISTINCT u.id)::numeric AS avg_num_per_user,
        SUM (e.amount)/COUNT (e.transaction_id) AS avg_amount_per_user,
        SUM(e.amount)/COUNT(DISTINCT u.id) AS avg_total_amount_per_user
 FROM fantasy.users AS u
 LEFT JOIN fantasy.race AS r USING (race_id)
 LEFT JOIN fantasy.events AS e ON u.id=e.id
 WHERE e.amount>0 
 GROUP BY race_id, race)
-- В разрезе расы персонажа:
-- общее количество зарегистрированных игроков;
-- количество игроков, которые совершают внутриигровые покупки, и их доля от общего количества;
-- доля платящих игроков, которые совершили покупку от общего количества игроков, которые совершили покупки;
-- среднее количество покупок на одного игрока;
-- средняя стоимость одной покупки на одного игрока;
-- средняя суммарная стоимость всех покупок на одного игрока. 
 SELECT p.race_id, 
        p.race, 
        p.number_of_users,
        p.number_of_buyers,
        ROUND (p.number_of_buyers::numeric/p.number_of_users, 2) AS share_user_buy_per_total,
        ROUND (p.number_of_paying_buyers::numeric/p.number_of_buyers,2) AS share_payer_from_make_buy,
        ROUND (a.avg_num_per_user,2) AS avg_num_per_user,
        ROUND (a.avg_amount_per_user::numeric,2) AS avg_amount_per_user,
        ROUND (a.avg_total_amount_per_user::numeric,2) AS avg_total_amount_per_user 
 FROM number_of_paying AS p
 LEFT JOIN avg_number AS a USING (race_id)
 ORDER BY number_of_buyers DESC; 
-- Задача 2: Частота покупок
-- для каждой покупки количество дней с предыдущей покупки 
WITH purchase_days AS (SELECT u.id, u.payer,
e.transaction_id,
date::date-LAG (date::date) OVER (PARTITION BY u.id ORDER BY date::date) AS days_since_previous_purchase
FROM fantasy.users AS u
LEFT JOIN fantasy.events AS e ON u.id=e.id
WHERE e.amount>0),
-- для каждого игрока, который совершил 25 и более покупок:
-- общее количество покупок;
-- среднее значение по количеству дней между покупками.
total_avg_purchases AS (SELECT d.id, u.payer,
COUNT (d.transaction_id) AS total_purchases,
AVG (days_since_previous_purchase) AS avg_days_between_purchases,
CASE WHEN u.payer=1 THEN 'платящие игроки'
WHEN u.payer=0 THEN 'неплатящие игроки'
END AS user_category
FROM purchase_days AS d
LEFT JOIN fantasy.users AS u USING (id)
GROUP BY d.id, u.payer
HAVING COUNT (transaction_id)>=25),
-- ранжирование игроков по среднему количеству дней между покупками
user_rank AS (SELECT *,
NTILE(3) OVER (ORDER BY avg_days_between_purchases) AS user_rank
FROM total_avg_purchases)
-- категоризация игроков на три примерно равные группы по частоте покупок.
-- для каждой группы игроков:
-- общее количество игроков;
-- количество платящих игроков, совершивших покупки;
-- доля платящих игроков, совершивших покупки от общего количества игроков, совершивших покупки;
-- среднее количество покупок на одного игрока;
-- среднее количество дней между покупками на одного игрока.
SELECT
CASE WHEN user_rank=1 THEN 'высокая частота' 
     WHEN user_rank=2 THEN 'умеренная частота'
     WHEN user_rank=3 THEN 'низкая частота'
     END user_group,
 COUNT (DISTINCT id) AS number_of_users,
 COUNT (DISTINCT id) FILTER (WHERE payer=1) AS paying_users,
 ROUND ((COUNT (DISTINCT id) FILTER (WHERE payer=1)::float/COUNT (DISTINCT id))::numeric,2) AS paying_share,
 ROUND (AVG (total_purchases),2) AS avg_purchases_per_users,
 ROUND (AVG (avg_days_between_purchases),2) AS avg_days_between_purchases
 FROM user_rank
 GROUP BY user_group
 ORDER BY user_group; 
      

